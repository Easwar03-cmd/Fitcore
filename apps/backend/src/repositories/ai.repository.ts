import { prisma } from '../utils/db';

export const aiRepository = {
  getTodayNutrition: async (userId: string) => {
    const start = new Date();
    start.setHours(0, 0, 0, 0);
    const end = new Date();
    end.setHours(23, 59, 59, 999);
    const logs = await prisma.foodLog.findMany({
      where: { userId, loggedAt: { gte: start, lte: end } },
    });
    return logs.reduce(
      (acc, log) => ({
        calories: acc.calories + log.calories,
        proteinG: acc.proteinG + log.proteinG,
        carbsG: acc.carbsG + log.carbsG,
        fatG: acc.fatG + log.fatG,
      }),
      { calories: 0, proteinG: 0, carbsG: 0, fatG: 0 },
    );
  },

  getTodayWorkout: async (userId: string) => {
    const start = new Date();
    start.setHours(0, 0, 0, 0);
    const end = new Date();
    end.setHours(23, 59, 59, 999);
    return prisma.workoutLog.findFirst({
      where: { userId, startedAt: { gte: start, lte: end } },
      select: { name: true, durationMin: true, caloriesBurned: true },
    });
  },

  getWeekWorkoutCount: async (userId: string) => {
    const start = new Date();
    const day = start.getDay();
    const diff = start.getDate() - day + (day === 0 ? -6 : 1); // ISO Monday
    start.setDate(diff);
    start.setHours(0, 0, 0, 0);
    return prisma.workoutLog.count({ where: { userId, startedAt: { gte: start } } });
  },

  getLatestBodyStat: async (userId: string) =>
    prisma.bodyStat.findFirst({
      where: { userId },
      orderBy: { measuredAt: 'desc' },
      select: { weightKg: true },
    }),

  getUserWithProfile: async (userId: string) =>
    prisma.user.findUnique({
      where: { id: userId },
      select: {
        name: true,
        dateOfBirth: true,
        profile: {
          select: { fitnessGoal: true, activityLevel: true, tdee: true, targetWeightKg: true },
        },
        subscription: { select: { tier: true } },
      },
    }),

  getFourWeekWorkoutSummary: async (userId: string) => {
    const start = new Date();
    start.setDate(start.getDate() - 28);
    start.setHours(0, 0, 0, 0);
    return prisma.workoutLog.findMany({
      where: { userId, startedAt: { gte: start } },
      orderBy: { startedAt: 'asc' },
      select: {
        startedAt: true,
        sets: { select: { exerciseName: true } },
      },
    });
  },

  getWeeklyWorkoutSummary: async (userId: string) => {
    const start = new Date();
    start.setDate(start.getDate() - 7);
    start.setHours(0, 0, 0, 0);
    return prisma.workoutLog.findMany({
      where: { userId, startedAt: { gte: start } },
      orderBy: { startedAt: 'desc' },
      select: {
        startedAt: true,
        name: true,
        durationMin: true,
        sets: {
          select: { exerciseName: true, setNumber: true },
        },
      },
    });
  },
};
