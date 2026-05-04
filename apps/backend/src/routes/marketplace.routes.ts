import type { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';

import { marketplaceRepository } from '../repositories/marketplace.repository';
import { prisma } from '../utils/db';

// ─── Helpers ──────────────────────────────────────────────────────────────────

async function requireCoachTier(
  userId: string,
  reply: Parameters<FastifyPluginAsync>[1]['reply'] extends never
    ? never
    : any,
): Promise<boolean> {
  const sub = await prisma.subscription.findUnique({ where: { userId } });
  const isExpired = sub?.validUntil ? sub.validUntil < new Date() : false;
  if (!sub || sub.tier !== 'coach' || isExpired) {
    reply.status(403).send({
      success: false,
      error: {
        code: 'COACH_TIER_REQUIRED',
        message: 'Coach marketplace requires a Coach subscription.',
      },
    });
    return false;
  }
  return true;
}

// ─── Schemas ──────────────────────────────────────────────────────────────────

const requestSessionSchema = z.object({
  coachId: z.string().min(1),
  message: z.string().min(10).max(1000),
});

// ─── Routes ───────────────────────────────────────────────────────────────────

export const marketplaceRoutes: FastifyPluginAsync = async (fastify) => {
  // GET /api/v1/marketplace/coaches?spec=strength
  fastify.get('/coaches', async (request, reply) => {
    try { await request.jwtVerify(); } catch {
      return reply.status(401).send({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Not authenticated' },
      });
    }

    const userId = request.user.userId;
    const allowed = await requireCoachTier(userId, reply);
    if (!allowed) return;

    const spec = (request.query as Record<string, string>).spec ?? '';
    const coaches = await marketplaceRepository.listCoaches(spec || undefined);
    return reply.send({ success: true, data: coaches });
  });

  // GET /api/v1/marketplace/coaches/:id
  fastify.get<{ Params: { id: string } }>('/coaches/:id', async (request, reply) => {
    try { await request.jwtVerify(); } catch {
      return reply.status(401).send({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Not authenticated' },
      });
    }

    const userId = request.user.userId;
    const allowed = await requireCoachTier(userId, reply);
    if (!allowed) return;

    const coach = await marketplaceRepository.getCoachById(request.params.id);
    if (!coach) {
      return reply.status(404).send({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Coach not found' },
      });
    }
    return reply.send({ success: true, data: coach });
  });

  // POST /api/v1/marketplace/request — send a session request to a coach
  fastify.post('/request', async (request, reply) => {
    try { await request.jwtVerify(); } catch {
      return reply.status(401).send({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Not authenticated' },
      });
    }

    const userId = request.user.userId;
    const allowed = await requireCoachTier(userId, reply);
    if (!allowed) return;

    const parsed = requestSessionSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({
        success: false,
        error: {
          code: 'VALIDATION_ERROR',
          message: 'Invalid request body',
          details: parsed.error.flatten(),
        },
      });
    }

    const { coachId, message } = parsed.data;

    const coach = await marketplaceRepository.getCoachById(coachId);
    if (!coach) {
      return reply.status(404).send({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Coach not found' },
      });
    }

    const alreadyRequested = await marketplaceRepository.hasActiveRequest(userId, coachId);
    if (alreadyRequested) {
      return reply.status(409).send({
        success: false,
        error: {
          code: 'ALREADY_REQUESTED',
          message: 'You already have an active request with this coach.',
        },
      });
    }

    const req = await marketplaceRepository.createRequest(userId, coachId, message);
    return reply.status(201).send({ success: true, data: req });
  });

  // GET /api/v1/marketplace/my-requests — user's own session requests
  fastify.get('/my-requests', async (request, reply) => {
    try { await request.jwtVerify(); } catch {
      return reply.status(401).send({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Not authenticated' },
      });
    }

    const userId = request.user.userId;
    const allowed = await requireCoachTier(userId, reply);
    if (!allowed) return;

    const requests = await marketplaceRepository.getUserRequests(userId);
    return reply.send({ success: true, data: requests });
  });
};
