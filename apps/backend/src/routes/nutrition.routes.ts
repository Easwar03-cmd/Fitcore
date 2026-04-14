import type { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { nutritionRepository } from '../repositories/nutrition.repository';

// ─── Zod schemas ──────────────────────────────────────────────────────────────

const createFoodLogSchema = z.object({
  foodId: z.string().min(1),
  foodName: z.string().min(1).max(200),
  mealType: z.enum(['breakfast', 'lunch', 'dinner', 'snack']),
  servingG: z.number().positive(),
  calories: z.number().min(0),
  proteinG: z.number().min(0),
  carbsG: z.number().min(0),
  fatG: z.number().min(0),
  fiberG: z.number().min(0).nullable().optional(),
});

// ─── Routes ───────────────────────────────────────────────────────────────────

export const nutritionRoutes: FastifyPluginAsync = async (fastify) => {

  // POST /api/v1/nutrition/food-logs
  fastify.post('/food-logs', async (request, reply) => {
    try { await request.jwtVerify(); } catch {
      return reply.status(401).send({ success: false, error: { code: 'UNAUTHORIZED', message: 'Not authenticated' } });
    }
    const userId = request.user.userId;

    const parsed = createFoodLogSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({
        success: false,
        error: { code: 'VALIDATION_ERROR', message: 'Invalid request body', details: parsed.error.flatten() },
      });
    }

    const log = await nutritionRepository.createFoodLog({ userId, ...parsed.data });
    return reply.status(201).send({ success: true, data: log });
  });

  // GET /api/v1/nutrition/food-logs?date=YYYY-MM-DD
  fastify.get('/food-logs', async (request, reply) => {
    try { await request.jwtVerify(); } catch {
      return reply.status(401).send({ success: false, error: { code: 'UNAUTHORIZED', message: 'Not authenticated' } });
    }
    const userId = request.user.userId;

    const { date } = request.query as { date?: string };
    const targetDate = date ? new Date(date) : new Date();
    if (isNaN(targetDate.getTime())) {
      return reply.status(400).send({
        success: false,
        error: { code: 'VALIDATION_ERROR', message: 'date must be YYYY-MM-DD' },
      });
    }

    const logs = await nutritionRepository.getFoodLogsByDate(userId, targetDate);

    const totals = logs.reduce(
      (acc, l) => ({
        calories: acc.calories + l.calories,
        proteinG: acc.proteinG + l.proteinG,
        carbsG: acc.carbsG + l.carbsG,
        fatG: acc.fatG + l.fatG,
      }),
      { calories: 0, proteinG: 0, carbsG: 0, fatG: 0 },
    );

    return reply.send({ success: true, data: { logs, totals } });
  });

  // DELETE /api/v1/nutrition/food-logs/:id
  fastify.delete('/food-logs/:id', async (request, reply) => {
    try { await request.jwtVerify(); } catch {
      return reply.status(401).send({ success: false, error: { code: 'UNAUTHORIZED', message: 'Not authenticated' } });
    }
    const userId = request.user.userId;
    const { id } = request.params as { id: string };

    const result = await nutritionRepository.deleteFoodLog(id, userId);
    if (result.count === 0) {
      return reply.status(404).send({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Log entry not found' },
      });
    }
    return reply.send({ success: true, data: { deleted: true } });
  });
};
