import type { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';

import { wellnessRepository } from '../repositories/wellness.repository';

// ─── Zod schemas ──────────────────────────────────────────────────────────────

const logMoodSchema = z.object({
  score: z.number().int().min(1).max(5),
});

// ─── Routes ───────────────────────────────────────────────────────────────────

export const wellnessRoutes: FastifyPluginAsync = async (fastify) => {
  // POST /api/v1/wellness/mood — log today's mood (score 1-5)
  fastify.post('/mood', async (request, reply) => {
    try { await request.jwtVerify(); } catch {
      return reply.status(401).send({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Not authenticated' },
      });
    }
    const userId = request.user.userId;

    const parsed = logMoodSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({
        success: false,
        error: {
          code: 'VALIDATION_ERROR',
          message: 'score must be an integer 1–5',
          details: parsed.error.flatten(),
        },
      });
    }

    const log = await wellnessRepository.logMood(userId, parsed.data.score);
    return reply.status(201).send({ success: true, data: log });
  });

  // GET /api/v1/wellness/mood?days=14 — mood history + today's mood
  fastify.get('/mood', async (request, reply) => {
    try { await request.jwtVerify(); } catch {
      return reply.status(401).send({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Not authenticated' },
      });
    }
    const userId = request.user.userId;

    const rawDays = Number((request.query as Record<string, string>).days ?? '14');
    const days = isNaN(rawDays) ? 14 : Math.min(Math.max(rawDays, 1), 90);

    const [history, todayMood] = await Promise.all([
      wellnessRepository.getMoodHistory(userId, days),
      wellnessRepository.getTodayMood(userId),
    ]);

    return reply.send({ success: true, data: { history, todayMood } });
  });

  // GET /api/v1/wellness/training-load — yesterday's total calories burned
  fastify.get('/training-load', async (request, reply) => {
    try { await request.jwtVerify(); } catch {
      return reply.status(401).send({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Not authenticated' },
      });
    }
    const userId = request.user.userId;
    const calsBurned = await wellnessRepository.getYesterdayCalsBurned(userId);
    return reply.send({ success: true, data: { calsBurned } });
  });
};
