import type { CommunityMember } from '@prisma/client';
import { prisma } from '../utils/db';

const DAY_MS = 24 * 60 * 60 * 1000;

export type TrackingWindow = { from: Date; to: Date; frozen: boolean };

/**
 * The ONLY place that decides what time range of a member's data an admin may
 * see. Returns null when the admin may see nothing:
 *   - member has not consented (or revoked)
 *   - tracking record was deleted
 * Frozen windows end at the hold / leave date.
 */
export function trackingWindow(m: CommunityMember, days: number, now = new Date()): TrackingWindow | null {
  if (!m.shareReport || !m.consentAt) return null;

  let to = now;
  let frozen = false;
  if (m.status === 'on_hold' && m.heldAt) {
    to = m.heldAt;
    frozen = true;
  } else if (m.status === 'left' && m.leftAt) {
    to = m.leftAt;
    frozen = true;
  } else if (m.status !== 'active') {
    return null;
  }

  const earliest = new Date(to.getTime() - days * DAY_MS);
  const from = earliest > m.consentAt ? earliest : m.consentAt;
  if (from > to) return null;
  return { from, to, frozen };
}

function dayKey(d: Date): string {
  return d.toISOString().slice(0, 10);
}

/** Consecutive logged days (food log or workout) ending on the window's last day. */
function currentStreak(activeDays: Set<string>, end: Date): number {
  let streak = 0;
  const cursor = new Date(Date.UTC(end.getUTCFullYear(), end.getUTCMonth(), end.getUTCDate()));
  // A day that is not over yet should not break the streak.
  if (!activeDays.has(dayKey(cursor))) cursor.setUTCDate(cursor.getUTCDate() - 1);
  while (activeDays.has(dayKey(cursor))) {
    streak += 1;
    cursor.setUTCDate(cursor.getUTCDate() - 1);
  }
  return streak;
}

export async function buildMemberReport(m: CommunityMember, win: TrackingWindow, communityId: string) {
  const { from, to } = win;
  const userId = m.userId;

  const [workouts, foodLogs, weights, profile, challenges] = await Promise.all([
    prisma.workoutLog.findMany({
      where: { userId, startedAt: { gte: from, lte: to } },
      select: { name: true, startedAt: true, durationMin: true, caloriesBurned: true },
      orderBy: { startedAt: 'desc' },
    }),
    prisma.foodLog.findMany({
      where: { userId, loggedAt: { gte: from, lte: to } },
      select: { calories: true, proteinG: true, loggedAt: true },
    }),
    prisma.bodyStat.findMany({
      where: { userId, measuredAt: { gte: from, lte: to }, weightKg: { not: null } },
      select: { weightKg: true, measuredAt: true },
      orderBy: { measuredAt: 'asc' },
    }),
    prisma.userProfile.findUnique({
      where: { userId },
      select: { fitnessGoal: true, tdee: true },
    }),
    prisma.challengeParticipant.findMany({
      where: {
        userId,
        startDate: { lte: to },
        challenge: { communityId },
      },
      include: {
        challenge: { select: { id: true, title: true, kind: true, totalDays: true } },
        _count: { select: { checkins: true } },
      },
      orderBy: { startDate: 'desc' },
    }),
  ]);

  const activeDays = new Set<string>();
  workouts.forEach((w) => activeDays.add(dayKey(w.startedAt)));
  foodLogs.forEach((f) => activeDays.add(dayKey(f.loggedAt)));

  const caloriesByDay = new Map<string, { kcal: number; protein: number }>();
  for (const f of foodLogs) {
    const k = dayKey(f.loggedAt);
    const cur = caloriesByDay.get(k) ?? { kcal: 0, protein: 0 };
    cur.kcal += f.calories;
    cur.protein += f.proteinG;
    caloriesByDay.set(k, cur);
  }
  const loggedDays = caloriesByDay.size;
  const totals = [...caloriesByDay.values()].reduce(
    (acc, d) => ({ kcal: acc.kcal + d.kcal, protein: acc.protein + d.protein }),
    { kcal: 0, protein: 0 },
  );

  const firstW = weights[0]?.weightKg ?? null;
  const lastW = weights[weights.length - 1]?.weightKg ?? null;

  return {
    window: { from, to, frozen: win.frozen },
    goal: profile?.fitnessGoal ?? null,
    calorieTarget: profile?.tdee ?? null,
    workouts: {
      count: workouts.length,
      totalMinutes: workouts.reduce((s, w) => s + (w.durationMin ?? 0), 0),
      caloriesBurned: workouts.reduce((s, w) => s + (w.caloriesBurned ?? 0), 0),
      recent: workouts.slice(0, 5).map((w) => ({
        name: w.name,
        startedAt: w.startedAt,
        durationMin: w.durationMin,
      })),
    },
    nutrition: {
      loggedDays,
      avgCalories: loggedDays ? Math.round(totals.kcal / loggedDays) : null,
      avgProteinG: loggedDays ? Math.round(totals.protein / loggedDays) : null,
    },
    weight: {
      startKg: firstW,
      latestKg: lastW,
      changeKg: firstW != null && lastW != null ? Math.round((lastW - firstW) * 10) / 10 : null,
    },
    streakDays: currentStreak(activeDays, to),
    challenges: challenges.map((p) => ({
      challengeId: p.challenge.id,
      title: p.challenge.title,
      kind: p.challenge.kind,
      totalDays: p.challenge.totalDays,
      completedDays: p._count.checkins,
      startDate: p.startDate,
      status: p.status,
    })),
  };
}
