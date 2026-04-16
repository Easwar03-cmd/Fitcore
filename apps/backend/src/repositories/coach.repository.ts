import type { PrismaClient } from '@prisma/client';
import type { CoachContext, FitnessGoal } from '@zenfit/shared';

function todayRange(): { start: Date; end: Date } {
  const start = new Date();
  start.setHours(0, 0, 0, 0);
  const end = new Date();
  end.setHours(23, 59, 59, 999);
  return { start, end };
}

function weekStart(): Date {
  const d = new Date();
  const day = d.getDay();
  const diff = d.getDate() - day + (day === 0 ? -6 : 1); // ISO Monday
  d.setDate(diff);
  d.setHours(0, 0, 0, 0);
  return d;
}

export async function getCoachContext(
  userId: string,
  prisma: PrismaClient,
): Promise<CoachContext> {
  const { start: todayStart, end: todayEnd } = todayRange();
  const weekStartDate = weekStart();
  const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);

  const [userRow, todayFoodLogs, todayWorkout, weekWorkoutCount, weekFoodLogs, latestStat, oldStat] =
    await Promise.all([
      prisma.user.findUnique({
        where: { id: userId },
        select: {
          name: true,
          profile: {
            select: { fitnessGoal: true, tdee: true },
          },
        },
      }),

      prisma.foodLog.findMany({
        where: { userId, loggedAt: { gte: todayStart, lte: todayEnd } },
        select: { calories: true },
      }),

      prisma.workoutLog.findFirst({
        where: { userId, startedAt: { gte: todayStart, lte: todayEnd } },
        select: { id: true },
      }),

      prisma.workoutLog.count({
        where: { userId, startedAt: { gte: weekStartDate } },
      }),

      prisma.foodLog.findMany({
        where: { userId, loggedAt: { gte: weekStartDate } },
        select: { calories: true, loggedAt: true },
      }),

      prisma.bodyStat.findFirst({
        where: { userId },
        orderBy: { measuredAt: 'desc' },
        select: { weightKg: true },
      }),

      prisma.bodyStat.findFirst({
        where: { userId, measuredAt: { lte: sevenDaysAgo } },
        orderBy: { measuredAt: 'desc' },
        select: { weightKg: true },
      }),
    ]);

  const name = userRow?.name ?? 'User';
  const fitnessGoal = (userRow?.profile?.fitnessGoal ?? 'maintain') as FitnessGoal;
  const tdee = userRow?.profile?.tdee ?? 2000;

  const caloriesLogged = todayFoodLogs.reduce((sum, log) => sum + log.calories, 0);
  const calorieTarget = tdee;

  // Compute average daily calories this week based on days that have at least one log.
  const calsByDay = new Map<string, number>();
  for (const log of weekFoodLogs) {
    const key = log.loggedAt.toISOString().slice(0, 10);
    calsByDay.set(key, (calsByDay.get(key) ?? 0) + log.calories);
  }
  const avgCalories =
    calsByDay.size > 0
      ? Math.round([...calsByDay.values()].reduce((a, b) => a + b, 0) / calsByDay.size)
      : 0;

  const latestWeight = latestStat?.weightKg ?? null;
  const oldWeight = oldStat?.weightKg ?? null;
  const weightChange =
    latestWeight !== null && oldWeight !== null
      ? Math.round((latestWeight - oldWeight) * 10) / 10
      : 0;

  return {
    user: { name, fitnessGoal, tdee },
    today: {
      caloriesLogged: Math.round(caloriesLogged),
      calorieTarget,
      workoutDone: todayWorkout !== null,
      steps: 0, // stepsToday column not yet in schema; sourced from HealthKit/Google Fit on-device
    },
    weekSummary: {
      workoutsCompleted: weekWorkoutCount,
      avgCalories,
      weightChange,
    },
  };
}
