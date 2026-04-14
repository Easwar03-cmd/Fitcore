import { prisma } from '../utils/db';

export const bodyRepository = {
  createBodyStat: (
    userId: string,
    weightKg: number,
    bodyFatPct?: number,
  ) =>
    prisma.bodyStat.create({
      data: {
        userId,
        weightKg,
        bodyFatPct: bodyFatPct ?? null,
      },
    }),

  getBodyStats: (userId: string) =>
    prisma.bodyStat.findMany({
      where: { userId },
      orderBy: { measuredAt: 'desc' },
      take: 30,
    }),
};
