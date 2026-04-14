import type { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';

import { workoutRepository } from '../repositories/workout.repository';

// ─── Zod schemas ──────────────────────────────────────────────────────────────

const exerciseSetSchema = z.object({
  exerciseId: z.string().min(1).max(100),
  exerciseName: z.string().min(1).max(200),
  setNumber: z.number().int().positive(),
  reps: z.number().int().positive().optional(),
  weightKg: z.number().positive().optional(),
  durationSec: z.number().int().positive().optional(),
});

const createWorkoutLogSchema = z.object({
  name: z.string().min(1).max(200),
  startedAt: z.string().datetime(),
  finishedAt: z.string().datetime().optional(),
  durationMin: z.number().int().min(0).optional(),
  caloriesBurned: z.number().int().min(0).optional(),
  distanceM: z.number().int().min(0).optional(),
  routePolyline: z.string().max(100_000).optional(),
  sets: z.array(exerciseSetSchema).min(1).max(500),
});

// ─── Routes ───────────────────────────────────────────────────────────────────

export const workoutRoutes: FastifyPluginAsync = async (fastify) => {
  // POST /api/v1/workout/logs — create a completed workout session
  fastify.post('/logs', async (request, reply) => {
    try { await request.jwtVerify(); } catch {
      return reply.status(401).send({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Not authenticated' },
      });
    }
    const userId = request.user.userId;

    const parsed = createWorkoutLogSchema.safeParse(request.body);
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

    const {
      name,
      startedAt,
      finishedAt,
      durationMin,
      caloriesBurned,
      distanceM,
      routePolyline,
      sets,
    } = parsed.data;

    const log = await workoutRepository.createWorkoutLog({
      userId,
      name,
      startedAt: new Date(startedAt),
      finishedAt: finishedAt ? new Date(finishedAt) : undefined,
      durationMin,
      caloriesBurned,
      distanceM,
      routePolyline,
      sets,
    });

    return reply.status(201).send({ success: true, data: log });
  });

  // GET /api/v1/workout/logs — last 20 workouts for the user
  fastify.get('/logs', async (request, reply) => {
    try { await request.jwtVerify(); } catch {
      return reply.status(401).send({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Not authenticated' },
      });
    }
    const userId = request.user.userId;
    const logs = await workoutRepository.getWorkoutLogs(userId);
    return reply.send({ success: true, data: logs });
  });

  // ── Stubs (Phase 2+) ─────────────────────────────────────────────────────

  fastify.patch('/logs/:id', async (_request, reply) =>
    reply.status(501).send({
      success: false,
      error: { code: 'NOT_IMPLEMENTED', message: 'Coming soon' },
    }),
  );

  fastify.get('/exercises', async (_request, reply) =>
    reply.status(501).send({
      success: false,
      error: { code: 'NOT_IMPLEMENTED', message: 'Coming soon' },
    }),
  );

  fastify.get('/templates', async (_request, reply) =>
    reply.status(501).send({
      success: false,
      error: { code: 'NOT_IMPLEMENTED', message: 'Coming soon' },
    }),
  );
};
