import type { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { GoogleGenerativeAIFetchError } from '@google/generative-ai';
import {
  checkCoachRateLimit,
  sendCoachMessage,
  getFreeTierMessageCount,
  incrementFreeTierCount,
  generateMealPlan,
  analyzeFoodPhoto,
  getWorkoutRecommendation,
  getDeloadCheck,
  type ChatMessage,
} from '../services/ai.service';
import { prisma } from '../utils/db';
import { config } from '../utils/config';

// ─── Zod schemas ──────────────────────────────────────────────────────────────

const foodPhotoRequestSchema = z.object({
  imageBase64: z.string().min(100),
  mimeType: z.enum(['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif']),
});

const chatMessageSchema = z.object({
  role: z.enum(['user', 'assistant']),
  content: z.string().min(1).max(4000),
});

const coachRequestSchema = z.object({
  messages: z.array(chatMessageSchema).min(1).max(50),
});

const chatHistoryItemSchema = z.object({
  role: z.enum(['user', 'assistant']),
  content: z.string().min(1),
});

const chatRequestSchema = z.object({
  message: z.string().min(1).max(4000),
  history: z.array(chatHistoryItemSchema).max(20).default([]),
});

const FREE_TIER_LIMIT = 5;

// ─── Shared error handler ─────────────────────────────────────────────────────

function handleAiError(err: unknown, request: { log: { error: (...args: unknown[]) => void } }) {
  if (err instanceof GoogleGenerativeAIFetchError) {
    request.log.error('[Gemini]', err.status, err.statusText, err.message);
    if (err.status === 429) {
      return { status: 503, code: 'AI_RATE_LIMITED', message: 'Gemini API rate limit hit. Please wait 60 seconds and try again.' };
    }
    const msg = err.message ?? `Gemini API error (${err.status})`;
    return { status: 502, code: 'AI_ERROR', message: msg };
  }
  request.log.error('[AI]', err instanceof Error ? err.message : err);
  if (err instanceof Error) {
    return { status: 500, code: 'INTERNAL_ERROR', message: err.message };
  }
  return { status: 500, code: 'INTERNAL_ERROR', message: 'Failed to get coach response' };
}

// ─── Routes ───────────────────────────────────────────────────────────────────

export const aiRoutes: FastifyPluginAsync = async (fastify) => {
  // POST /api/v1/ai/coach
  fastify.post('/coach', async (request, reply) => {
    try {
      await request.jwtVerify();
    } catch {
      return reply.status(401).send({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Not authenticated' },
      });
    }

    const userId = request.user.userId;

    const parsed = coachRequestSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({
        success: false,
        error: { code: 'VALIDATION_ERROR', message: 'Invalid request body', details: parsed.error.flatten() },
      });
    }

    const { messages } = parsed.data;

    const { prisma: db } = await import('../utils/db');
    const subscription = await db.subscription.findUnique({ where: { userId }, select: { tier: true } });
    const tier = subscription?.tier ?? 'free';

    const rateLimit = await checkCoachRateLimit(userId, tier);
    if (!rateLimit.allowed) {
      return reply.status(429).send({
        success: false,
        error: { code: 'RATE_LIMITED_COACH', message: 'Daily message limit reached. Upgrade to Pro for unlimited coaching.' },
      });
    }

    try {
      const responseText = await sendCoachMessage(userId, messages as ChatMessage[]);
      return reply.send({ success: true, data: { message: responseText, remainingMessages: rateLimit.remaining } });
    } catch (err) {
      const { status, code, message } = handleAiError(err, request);
      return reply.status(status).send({ success: false, error: { code, message } });
    }
  });

  // POST /api/v1/ai/chat
  fastify.post('/chat', async (request, reply) => {
    try {
      await request.jwtVerify();
    } catch {
      return reply.status(401).send({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Not authenticated' },
      });
    }

    const userId = request.user.userId;

    const parsed = chatRequestSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({
        success: false,
        error: { code: 'VALIDATION_ERROR', message: 'Invalid request body', details: parsed.error.flatten() },
      });
    }

    const { message, history } = parsed.data;

    const [subscription, user] = await Promise.all([
      prisma.subscription.findUnique({ where: { userId }, select: { tier: true } }),
      prisma.user.findUnique({ where: { id: userId }, select: { email: true } }),
    ]);
    const tier = subscription?.tier ?? 'free';
    const adminEmails = (config.ADMIN_EMAILS ?? '').split(',').map((e: string) => e.trim()).filter(Boolean);
    const isAdmin = adminEmails.includes(user?.email ?? '');
    const isPaid = isAdmin || tier === 'pro' || tier === 'coach';

    // The first message of a session (empty history) is a free opener — it is
    // not counted toward the daily limit. Subsequent messages in the same
    // conversation (history.length > 0) are counted for free-tier users.
    const isSessionStarter = history.length === 0;

    // Rate limit check (read-only — increment happens after success)
    if (!isPaid && !isSessionStarter) {
      const count = await getFreeTierMessageCount(userId);
      if (count !== null && count >= FREE_TIER_LIMIT) {
        return reply.status(429).send({
          success: false,
          error: {
            code: 'RATE_LIMIT_EXCEEDED',
            message: 'Daily message limit reached. Upgrade to Pro for unlimited coaching.',
            messagesUsedToday: count,
            limit: FREE_TIER_LIMIT,
          },
        });
      }
    }

    try {
      const messages: ChatMessage[] = [
        ...history.map((h) => ({ role: h.role as 'user' | 'assistant', content: h.content })),
        { role: 'user' as const, content: message },
      ];

      const replyText = await sendCoachMessage(userId, messages);
      const messagesUsedToday = (isPaid || isSessionStarter) ? 0 : await incrementFreeTierCount(userId);

      return reply.send({ success: true, data: { reply: replyText, messagesUsedToday, dailyLimit: isPaid ? 0 : FREE_TIER_LIMIT } });
    } catch (err) {
      const { status, code, message: msg } = handleAiError(err, request);
      return reply.status(status).send({ success: false, error: { code, message: msg } });
    }
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

    try {
      const recommendation = await getWorkoutRecommendation(userId);
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
      select: { tier: true },
    });
    const tier = subscription?.tier ?? 'free';

    if (tier === 'free') {
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
