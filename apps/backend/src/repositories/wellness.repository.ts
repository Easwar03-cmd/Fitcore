import { prisma } from '../utils/db';

export const wellnessRepository = {
  // ── Mood ────────────────────────────────────────────────────────────────────

  logMood: (userId: string, score: number) =>
    prisma.moodLog.create({ data: { userId, score } }),

  getMoodHistory: (userId: string, days: number) => {
    const since = new Date();
    since.setDate(since.getDate() - days);
    return prisma.moodLog.findMany({
      where: { userId, loggedAt: { gte: since } },
      orderBy: { loggedAt: 'asc' },
    });
  },

  getTodayMood: (userId: string) => {
    const now = new Date();
    const midnight = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    return prisma.moodLog.findFirst({
      where: { userId, loggedAt: { gte: midnight } },
      orderBy: { loggedAt: 'desc' },
    });
  },

  // ── Training load ────────────────────────────────────────────────────────────

  /** Sum of caloriesBurned across all workout logs that started yesterday. */
  getYesterdayCalsBurned: async (userId: string): Promise<number> => {
    const now = new Date();
    const todayMidnight = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const yesterdayMidnight = new Date(todayMidnight);
    yesterdayMidnight.setDate(yesterdayMidnight.getDate() - 1);

    const result = await prisma.workoutLog.aggregate({
      where: {
        userId,
        startedAt: { gte: yesterdayMidnight, lt: todayMidnight },
      },
      _sum: { caloriesBurned: true },
    });
    return result._sum.caloriesBurned ?? 0;
  },
};
