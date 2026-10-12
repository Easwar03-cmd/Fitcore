import type { Prisma } from '@prisma/client';

/**
 * Runs inside the account-deletion transaction, before the user row is removed.
 * For every community the user administers:
 *   - hand it to the longest-standing active member, or
 *   - delete it when nobody else is left.
 */
export async function releaseUserCommunities(
  tx: Prisma.TransactionClient,
  userId: string,
): Promise<void> {
  const owned = await tx.community.findMany({
    where: { adminId: userId },
    select: { id: true },
  });

  for (const c of owned) {
    const successor = await tx.communityMember.findFirst({
      where: { communityId: c.id, userId: { not: userId }, status: { in: ['active', 'on_hold'] } },
      orderBy: { joinedAt: 'asc' },
    });
    if (!successor) {
      await tx.community.delete({ where: { id: c.id } });
      continue;
    }
    await tx.community.update({ where: { id: c.id }, data: { adminId: successor.userId } });
    await tx.communityMember.update({
      where: { id: successor.id },
      data: {
        role: 'admin',
        status: 'active',
        shareReport: false,
        consentAt: null,
        heldAt: null,
      },
    });
  }
}
