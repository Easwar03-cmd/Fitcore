import type { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { GoogleGenerativeAIFetchError } from '@google/generative-ai';
import {
  generateMealPlan,
  analyzeFoodPhoto,
  getWorkoutRecommendation,
  getDeloadCheck,
} from '../services/ai.service';
import { prisma } from '../utils/db';
import { config } from '../utils/config';

// ─── Zod schemas ──────────────────────────────────────────────────────────────

const foodPhotoRequestSchema = z.object({
  imageBase64: z.string().min(100),
  mimeType: z.enum(['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif']),
});

// ─── Shared error handler ─────────────────────────────────────────────────────

function handleAiError(err: unknown, request: { log: { error: (...args: unknown[]) => void } }) {
  const isProd = config.NODE_ENV === 'production';
  if (err instanceof GoogleGenerativeAIFetchError) {
    request.log.error('[Gemini]', err.status, err.statusText, err.message);
    if (err.status === 429) {
      return { status: 503, code: 'AI_RATE_LIMITED', message: 'AI service is temporarily busy. Please try again in a moment.' };
    }
    // 402 = Gemini prepaid credits depleted; 403/404 = key or model problem.
    // Owner action is needed — tell users plainly instead of a generic error.
    if (err.status === 402 || err.status === 403 || err.status === 404) {
      request.log.error('[Gemini] AI unavailable — check AI Studio billing, API key and GEMINI_MODEL');
      return {
        status: 503,
        code: 'AI_UNAVAILABLE',
        message: 'AI features are temporarily unavailable. Please try again later.',
      };
    }
    return { status: 502, code: 'AI_ERROR', message: isProd ? 'AI service error' : (err.message ?? `Gemini API error (${err.status})`) };
  }
  request.log.error('[AI]', err instanceof Error ? err.message : err);
  return { status: 500, code: 'INTERNAL_ERROR', message: isProd ? 'AI request failed' : (err instanceof Error ? err.message : 'Unknown error') };
}

// ─── Routes ───────────────────────────────────────────────────────────────────

const reportSchema = z.object({
  messageText: z.string().min(1).max(5000),
  reason: z.enum(['harmful', 'inaccurate', 'offensive', 'other']),
});

export const aiRoutes: FastifyPluginAsync = async (fastify) => {
  // POST /api/v1/ai/report — user flags an AI response (Play generative-AI
  // policy). Logged at warn level so reports surface in Cloud Logging.
  fastify.post('/report', async (request, reply) => {
    try {
      await request.jwtVerify();
    } catch {
      return reply.status(401).send({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Not authenticated' },
      });
    }

    const parsed = reportSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({
        success: false,
        error: { code: 'VALIDATION_ERROR', message: 'Invalid report', details: parsed.error.flatten() },
      });
    }

    request.log.warn(
      { aiReport: { userId: request.user.userId, ...parsed.data } },
      '[AI report] user flagged an AI response',
    );
    return reply.send({ success: true, data: { received: true } });
  });

  // POST /api/v1/ai/analyze-food-photo  (20 MB limit — base64 image)
  fastify.post('/analyze-food-photo', { bodyLimit: 20 * 1024 * 1024 }, async (request, reply) => {
    try {
      await request.jwtVerify();
    } catch {
      return reply.status(401).send({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Not authenticated' },
      });
    }

    const userId = request.user.userId;

    const subscription = await prisma.subscription.findUnique({ where: { userId }, select: { tier: true, validUntil: true } });
    const hasActivePaidSub = subscription && subscription.tier !== 'free' && (!subscription.validUntil || subscription.validUntil > new Date());
    if (!hasActivePaidSub) {
      return reply.status(403).send({
        success: false,
        error: { code: 'UPGRADE_REQUIRED', message: 'Food photo logging is available on Pro and Coach plans. Upgrade to unlock.' },
      });
    }

    const parsed = foodPhotoRequestSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({
        success: false,
        error: { code: 'VALIDATION_ERROR', message: 'Invalid request body', details: parsed.error.flatten() },
      });
    }

    const { imageBase64, mimeType } = parsed.data;

    try {
      const analysis = await analyzeFoodPhoto(imageBase64, mimeType);
      return reply.send({ success: true, data: analysis });
    } catch (err) {
      const { status, code, message } = handleAiError(err, request);
      return reply.status(status).send({ success: false, error: { code, message } });
    }
  });

  // GET /api/v1/ai/deload-check
  fastify.get('/deload-check', async (request, reply) => {
    try {
      await request.jwtVerify();
    } catch {
      return reply.status(401).send({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Not authenticated' },
      });
    }
    try {
      const check = await getDeloadCheck(request.user.userId);
      return reply.send({ success: true, data: check });
    } catch (err) {
      const { status, code, message } = handleAiError(err, request);
      return reply.status(status).send({ success: false, error: { code, message } });
    }
  });

  // GET /api/v1/ai/workout-recommendation
  fastify.get('/workout-recommendation', async (request, reply) => {
    try {
      await request.jwtVerify();
    } catch {
      return reply.status(401).send({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Not authenticated' },
      });
    }

    const userId = request.user.userId;
    const query = request.query as { type?: string };
    const type = query.type === 'home' ? 'home' : 'gym';

    try {
      const recommendation = await getWorkoutRecommendation(userId, type);
      return reply.send({ success: true, data: recommendation });
    } catch (err) {
      const { status, code, message } = handleAiError(err, request);
      return reply.status(status).send({ success: false, error: { code, message } });
    }
  });

  // POST /api/v1/ai/meal-plan  (Pro / Coach tier only)
  fastify.post('/meal-plan', async (request, reply) => {
    try {
      await request.jwtVerify();
    } catch {
      return reply.status(401).send({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Not authenticated' },
      });
    }

    const userId = request.user.userId;

    const subscription = await prisma.subscription.findUnique({
      where: { userId },
      select: { tier: true, validUntil: true },
    });
    const hasActivePaidSub = subscription && subscription.tier !== 'free' && (!subscription.validUntil || subscription.validUntil > new Date());

    if (!hasActivePaidSub) {
      return reply.status(403).send({
        success: false,
        error: {
          code: 'UPGRADE_REQUIRED',
          message: 'AI meal plans are available on Pro and Coach plans. Upgrade to unlock.',
        },
      });
    }

    try {
      const plan = await generateMealPlan(userId);
      return reply.send({ success: true, data: plan });
    } catch (err) {
      const { status, code, message } = handleAiError(err, request);
      return reply.status(status).send({ success: false, error: { code, message } });
    }
  });
};
