/**
 * weekly_summary.job.ts
 *
 * BullMQ job that fires every Sunday at 18:00 UTC.
 * For each user with an FCM token it computes:
 *   - workouts completed this week (Mon–Sun)
 *   - average daily calories logged this week
 *   - streak days (consecutive days with ≥1 food log or workout)
 * Then sends a single FCM push notification summarising the week.
 */

import { Queue, Worker, type Job } from 'bullmq';
import IORedis from 'ioredis';
import { config } from '../utils/config';
import { sendPush } from '../utils/firebase';
import { prisma } from '../utils/db';

// ─── Redis connection ─────────────────────────────────────────────────────────
// lazyConnect + enableOfflineQueue:false means BullMQ won't spam retries when
// Redis is unavailable. The weekly summary feature is degraded-gracefully:
// if Redis isn't running the API still works, only push scheduling is skipped.

let _connection: IORedis | null = null;

function getConnection(): IORedis {
  if (!_connection) {
    _connection = new IORedis(config.REDIS_URL, {
      maxRetriesPerRequest: null, // required by BullMQ
      enableOfflineQueue: false,
      lazyConnect: true,
      // Return null to disable automatic reconnection — we only connect once
      // explicitly and skip gracefully if Redis isn't available.
      retryStrategy: () => null,
    });
    let _warnedOnce = false;
    _connection.on('error', (err: Error) => {
      if (_warnedOnce) return;
      _warnedOnce = true;
      const code = (err as NodeJS.ErrnoException).code;
      if (code === 'ECONNREFUSED') {
        console.warn('[weekly-summary] Redis unavailable — weekly push notifications disabled. Start Redis to enable.');
      } else {
        console.warn('[weekly-summary] Redis error:', err.message);
      }
    });
  }
  return _connection;
}

// ─── Queue ────────────────────────────────────────────────────────────────────

const QUEUE_NAME = 'weekly-summary';

/**
 * Schedule the repeatable job (idempotent — safe to call on every boot).
 * Fires every Sunday at 18:00 UTC.
 * Returns false and logs a warning if Redis is not available.
 */
export async function scheduleWeeklySummaryJob(): Promise<void> {
  try {
    const conn = getConnection();
    await conn.connect().catch(() => { throw new Error('Redis not reachable'); });
    const queue = new Queue(QUEUE_NAME, { connection: conn });
    await queue.upsertJobScheduler(
      'weekly-summary-cron',
      { pattern: '0 18 * * 0' }, // every Sunday 18:00 UTC
      {
        name: 'weekly-summary',
        opts: { attempts: 3, backoff: { type: 'exponential', delay: 60_000 } },
      },
    );
    console.log('[weekly-summary] Repeatable job scheduled (Sun 18:00 UTC)');
  } catch {
    console.warn('[weekly-summary] Skipping job schedule — Redis not available. Start Redis to enable weekly push notifications.');
  }
}

// ─── Weekly stats helpers ─────────────────────────────────────────────────────

function getWeekBounds(): { weekStart: Date; weekEnd: Date } {
  const now = new Date();
  const dayOfWeek = now.getUTCDay(); // 0 = Sun, 1 = Mon … 6 = Sat
  const daysFromMonday = dayOfWeek === 0 ? 6 : dayOfWeek - 1;

  const weekStart = new Date(now);
  weekStart.setUTCDate(now.getUTCDate() - daysFromMonday);
  weekStart.setUTCHours(0, 0, 0, 0);

  const weekEnd = new Date(now);
  weekEnd.setUTCHours(23, 59, 59, 999);

  return { weekStart, weekEnd };
}

async function getWeeklyStats(userId: string): Promise<{
  workouts: number;
  avgCalories: number;
  streakDays: number;
}> {
  const { weekStart, weekEnd } = getWeekBounds();

  // Count finished workouts this week
  const workouts = await prisma.workoutLog.count({
    where: {
      userId,
      startedAt: { gte: weekStart, lte: weekEnd },
      finishedAt: { not: null },
    },
  });

  // Sum calories across food logs this week, then average by logged days
  const calorieAgg = await prisma.foodLog.groupBy({
    by: ['loggedAt'],
    where: { userId, loggedAt: { gte: weekStart, lte: weekEnd } },
    _sum: { calories: true },
  });

  // Group by calendar day then average
  const dayTotals = new Map<string, number>();
  for (const row of calorieAgg) {
    const day = new Date(row.loggedAt).toISOString().slice(0, 10);
    dayTotals.set(day, (dayTotals.get(day) ?? 0) + (row._sum.calories ?? 0));
  }
  const avgCalories =
    dayTotals.size > 0
      ? Math.round([...dayTotals.values()].reduce((a, b) => a + b, 0) / dayTotals.size)
      : 0;

  // Streak: count consecutive days (backwards from today) where user logged
  // food OR completed a workout (matches CLAUDE.md streak logic without steps).
  let streakDays = 0;
  const today = new Date();
  today.setUTCHours(0, 0, 0, 0);

  for (let i = 0; i < 30; i++) {
    const dayStart = new Date(today);
    dayStart.setUTCDate(today.getUTCDate() - i);
    const dayEnd = new Date(dayStart);
    dayEnd.setUTCHours(23, 59, 59, 999);

    const [foodCount, workoutCount] = await Promise.all([
      prisma.foodLog.count({ where: { userId, loggedAt: { gte: dayStart, lte: dayEnd } } }),
      prisma.workoutLog.count({
        where: { userId, startedAt: { gte: dayStart, lte: dayEnd }, finishedAt: { not: null } },
      }),
    ]);

    if (foodCount > 0 || workoutCount > 0) {
      streakDays++;
    } else {
      break; // streak broken
    }
  }

  return { workouts, avgCalories, streakDays };
}

// ─── Worker ───────────────────────────────────────────────────────────────────

export function startWeeklySummaryWorker(): Worker | null {
  try {
    const conn = getConnection();
    // Check if already connected — if not, skip worker startup silently.
    if (conn.status !== 'ready' && conn.status !== 'connecting') {
      console.warn('[weekly-summary] Worker not started — Redis not connected.');
      return null;
    }
  } catch {
    return null;
  }

  const worker = new Worker(
    QUEUE_NAME,
    async (_job: Job) => {
      console.log('[weekly-summary] Processing weekly summary push...');

      // Fetch all users that have registered an FCM token
      const users = await prisma.user.findMany({
        where: { fcmToken: { not: null } },
        select: { id: true, name: true, fcmToken: true },
      });

      console.log(`[weekly-summary] Sending to ${users.length} users`);
      let sent = 0;

      for (const user of users) {
        if (!user.fcmToken) continue;

        try {
          const { workouts, avgCalories, streakDays } = await getWeeklyStats(user.id);

          const streakEmoji = streakDays >= 7 ? '🔥🔥' : streakDays >= 3 ? '🔥' : '💪';
          const body =
            `This week: ${workouts} workout${workouts !== 1 ? 's' : ''}, ` +
            `${avgCalories > 0 ? `${avgCalories} kcal avg, ` : ''}` +
            `${streakDays} streak day${streakDays !== 1 ? 's' : ''} ${streakEmoji}`;

          const ok = await sendPush(user.fcmToken, 'Your FitCore Week in Review 🏆', body, {
            type: 'weekly_summary',
          });

          if (ok) sent++;
        } catch (err) {
          console.error(`[weekly-summary] Failed for user ${user.id}:`, err);
        }
      }

      console.log(`[weekly-summary] Done — sent to ${sent}/${users.length} users`);
    },
    { connection: getConnection() },
  );

  worker.on('failed', (job, err) => {
    console.error(`[weekly-summary] Job ${job?.id} failed:`, err);
  });

  return worker;
}
