import { prisma } from '../utils/db';

export type CreateFoodLogData = {
  userId: string;
  foodId: string;
  foodName: string;
  mealType: string;
  servingG: number;
  calories: number;
  proteinG: number;
  carbsG: number;
  fatG: number;
  fiberG?: number | null;
};

export const nutritionRepository = {
  createFoodLog: (data: CreateFoodLogData) =>
    prisma.foodLog.create({ data }),

  getFoodLogsByDate: (userId: string, date: Date) => {
    const start = new Date(date);
    start.setHours(0, 0, 0, 0);
    const end = new Date(date);
    end.setHours(23, 59, 59, 999);
    return prisma.foodLog.findMany({
      where: { userId, loggedAt: { gte: start, lte: end } },
      orderBy: { loggedAt: 'asc' },
    });
  },

  // Scoped delete — userId guard prevents deleting other users' logs.
  deleteFoodLog: (id: string, userId: string) =>
    prisma.foodLog.deleteMany({ where: { id, userId } }),
};
