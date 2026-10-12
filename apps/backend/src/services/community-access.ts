import type { FastifyReply } from 'fastify';
import type { Community, CommunityMember } from '@prisma/client';
import { prisma } from '../utils/db';

export type MemberWithCommunity = CommunityMember & { community: Community };

export function fail(reply: FastifyReply, status: number, code: string, message: string) {
  return reply.status(status).send({ success: false, error: { code, message } });
}

export function validationError(reply: FastifyReply, details: unknown) {
  return reply.status(400).send({
    success: false,
    error: { code: 'VALIDATION_ERROR', message: 'Invalid request', details },
  });
}

export async function getMembership(
  communityId: string,
  userId: string,
): Promise<MemberWithCommunity | null> {
  return prisma.communityMember.findUnique({
    where: { communityId_userId: { communityId, userId } },
    include: { community: true },
  });
}

/** Active or on-hold members can read and take part in the community. */
export function canParticipate(m: CommunityMember | null): m is MemberWithCommunity {
  return m !== null && (m.status === 'active' || m.status === 'on_hold');
}

export function isAdmin(m: CommunityMember | null): boolean {
  return canParticipate(m as MemberWithCommunity | null) && m!.role === 'admin';
}

/**
 * Loads the caller's membership and replies 404/403 when they may not act.
 * Returns null after sending the error response.
 */
export async function requireMember(
  reply: FastifyReply,
  communityId: string,
  userId: string,
): Promise<MemberWithCommunity | null> {
  const m = await getMembership(communityId, userId);
  if (!m) {
    await fail(reply, 404, 'NOT_FOUND', 'Community not found');
    return null;
  }
  if (!canParticipate(m)) {
    await fail(reply, 403, 'NOT_A_MEMBER', 'You are not a member of this community');
    return null;
  }
  return m;
}

export async function requireAdmin(
  reply: FastifyReply,
  communityId: string,
  userId: string,
): Promise<MemberWithCommunity | null> {
  const m = await requireMember(reply, communityId, userId);
  if (!m) return null;
  if (m.role !== 'admin') {
    await fail(reply, 403, 'FORBIDDEN', 'Only the community admin can do this');
    return null;
  }
  return m;
}
