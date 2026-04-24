import { prisma } from '../utils/db';

export const marketplaceRepository = {
  // ── Coaches ──────────────────────────────────────────────────────────────────

  listCoaches: (spec?: string) =>
    prisma.coachProfile.findMany({
      where: {
        isActive: true,
        ...(spec ? { specializations: { contains: spec } } : {}),
      },
      orderBy: [{ rating: 'desc' }, { reviewCount: 'desc' }],
    }),

  getCoachById: (id: string) =>
    prisma.coachProfile.findFirst({ where: { id, isActive: true } }),

  // ── Session requests ─────────────────────────────────────────────────────────

  createRequest: (userId: string, coachId: string, message: string) =>
    prisma.coachSessionRequest.create({
      data: { userId, coachId, message },
    }),

  /** True when the user already has a pending/accepted request to this coach. */
  hasActiveRequest: async (userId: string, coachId: string): Promise<boolean> => {
    const existing = await prisma.coachSessionRequest.findFirst({
      where: {
        userId,
        coachId,
        status: { in: ['pending', 'accepted'] },
      },
    });
    return existing !== null;
  },

  getUserRequests: (userId: string) =>
    prisma.coachSessionRequest.findMany({
      where: { userId },
      include: { coach: true },
      orderBy: { requestedAt: 'desc' },
    }),
};
