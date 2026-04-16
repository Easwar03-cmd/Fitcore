import type { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { checkCoachRateLimit, sendCoachMessage, type ChatMessage } from '../services/ai.service';
import Anthropic from '@anthropic-ai/sdk';

// ─── Zod schemas ──────────────────────────────────────────────────────────────

const chatMessageSchema = z.object({
  role: z.enum(['user', 'assistant']),
  content: z.string().min(1).max(4000),
});

const coachRequestSchema = z.object({
  messages: z.array(chatMessageSchema).min(1).max(50),
});

// ─── Routes ───────────────────────────────────────────────────────────────────

export const aiRoutes: FastifyPluginAsync = async (fastify) => {
  // POST /api/v1/ai/coach
  fastify.post('/coach', async (request, reply) => {
    // ── Auth ────────────────────────────────────────────────────────────────
    try {
      await request.jwtVerify();
    } catch {
      return reply.status(401).send({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Not authenticated' },
      });
    }

    const userId = request.user.userId;

    // ── Validate body ───────────────────────────────────────────────────────
    const parsed = coachRequestSchema.safeParse(request.body);
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

    const { messages } = parsed.data;

    // ── Subscription tier (for rate limiting) ───────────────────────────────
    // Fetched inline from the JWT user; full subscription is in DB.
    // We import prisma lazily here to avoid a circular dep via ai.service.
    const { prisma } = await import('../utils/db');
    const subscription = await prisma.subscription.findUnique({
      where: { userId },
      select: { tier: true },
    });
    const tier = subscription?.tier ?? 'free';

    // ── Rate limit (free tier: 5 msgs/day tracked in Redis) ─────────────────
    const rateLimit = await checkCoachRateLimit(userId, tier);
    if (!rateLimit.allowed) {
      return reply.status(429).send({
        success: false,
        error: {
          code: 'RATE_LIMITED_COACH',
          message: 'Daily message limit reached. Upgrade to Pro for unlimited coaching.',
        },
      });
    }

    // ── Call Claude ─────────────────────────────────────────────────────────
    try {
      const responseText = await sendCoachMessage(userId, messages as ChatMessage[]);
      return reply.send({
        success: true,
        data: {
          message: responseText,
          remainingMessages: rateLimit.remaining,
        },
      });
    } catch (err) {
      request.log.error(err);
      if (err instanceof Anthropic.RateLimitError) {
        return reply.status(503).send({
          success: false,
          error: { code: 'AI_UNAVAILABLE', message: 'AI service temporarily unavailable. Try again shortly.' },
        });
      }
      return reply.status(500).send({
        success: false,
        error: { code: 'INTERNAL_ERROR', message: 'Failed to get coach response' },
      });
    }
  });

  // POST /api/v1/ai/meal-plan
  fastify.post('/meal-plan', async (_request, reply) => {
    // TODO: Pro/Coach tier only — generate weekly meal plan via Claude
    return reply.status(501).send({ success: false, error: { code: 'NOT_IMPLEMENTED', message: 'Coming soon' } });
  });
};
