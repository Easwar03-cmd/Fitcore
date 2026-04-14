import type { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';

import { bodyRepository } from '../repositories/body.repository';

// ─── Zod schemas ──────────────────────────────────────────────────────────────

const createBodyStatSchema = z.object({
  weightKg: z.number().positive().max(500),
  bodyFatPct: z.number().min(1).max(70).optional(),
});

// ─── Routes ───────────────────────────────────────────────────────────────────

export const bodyRoutes: FastifyPluginAsync = async (fastify) => {
  // POST /api/v1/body/stats — log a body weight (+ optional body fat %)
  fastify.post('/stats', async (request, reply) => {
    try { await request.jwtVerify(); } catch {
      return reply.status(401).send({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Not authenticated' },
      });
    }
    const userId = request.user.userId;

    const parsed = createBodyStatSchema.safeParse(request.body);
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

    const stat = await bodyRepository.createBodyStat(
      userId,
      parsed.data.weightKg,
      parsed.data.bodyFatPct,
    );

    return reply.status(201).send({ success: true, data: stat });
  });

  // GET /api/v1/body/stats — last 30 entries for the authenticated user
  fastify.get('/stats', async (request, reply) => {
    try { await request.jwtVerify(); } catch {
      return reply.status(401).send({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Not authenticated' },
      });
    }
    const userId = request.user.userId;
    const stats = await bodyRepository.getBodyStats(userId);
    return reply.send({ success: true, data: stats });
  });
};
