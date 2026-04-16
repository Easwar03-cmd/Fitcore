import type { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import {
  checkCoachRateLimit,
  sendCoachMessage,
  getFreeTierMessageCount,
  incrementFreeTierCount,
  type ChatMessage,
} from '../services/ai.service';
import { getCoachContext } from '../repositories/coach.repository';
import { prisma } from '../utils/db';
import { config } from '../utils/config';
import Anthropic from '@anthropic-ai/sdk';

// ─── Zod schemas ──────────────────────────────────────────────────────────────

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
  message: z.string().min(1).max(1000),
  history: z.array(chatHistoryItemSchema).max(10).default([]),
});

const FREE_TIER_LIMIT = 5;

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
      if (err instanceof Anthropic.BadRequestError && err.message.includes('credit balance')) {
        return reply.status(503).send({
          success: false,
          error: { code: 'AI_BILLING', message: 'AI service is temporarily unavailable. Please try again later.' },
        });
      }
      return reply.status(500).send({
        success: false,
        error: { code: 'INTERNAL_ERROR', message: 'Failed to get coach response' },
      });
    }
  });

  // POST /api/v1/ai/chat
  fastify.post('/chat', async (request, reply) => {
    // ── Auth ──────────────────────────────────────────────────────────────────
    try {
      await request.jwtVerify();
    } catch {
      return reply.status(401).send({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Not authenticated' },
      });
    }

    const userId = request.user.userId;

    // ── Validate body ─────────────────────────────────────────────────────────
    const parsed = chatRequestSchema.safeParse(request.body);
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

    const { message, history } = parsed.data;

    // ── Subscription tier ─────────────────────────────────────────────────────
    const subscription = await prisma.subscription.findUnique({
      where: { userId },
      select: { tier: true },
    });
    const tier = subscription?.tier ?? 'free';
    const isPaid = tier === 'pro' || tier === 'coach';

    // ── Rate limit check (read-only — increment happens after success) ─────────
    let currentCount = 0;
    if (!isPaid) {
      const count = await getFreeTierMessageCount(userId);
      // null means Redis unavailable — fail open (don't block the user)
      if (count !== null) {
        currentCount = count;
        if (currentCount >= FREE_TIER_LIMIT) {
          return reply.status(429).send({
            success: false,
            error: {
              code: 'RATE_LIMIT_EXCEEDED',
              message: 'Daily message limit reached. Upgrade to Pro for unlimited coaching.',
              messagesUsedToday: currentCount,
              limit: FREE_TIER_LIMIT,
            },
          });
        }
      }
    }

    // ── Build context + call Claude ───────────────────────────────────────────
    try {
      const ctx = await getCoachContext(userId, prisma);

      // Inject context as a JSON block prepended to the current user message
      const userMessageWithContext =
        `<coach_context>\n${JSON.stringify(ctx, null, 2)}\n</coach_context>\n\n${message}`;

      const messages: ChatMessage[] = [
        ...history.map((h) => ({ role: h.role, content: h.content })),
        { role: 'user', content: userMessageWithContext },
      ];

      const anthropic = new Anthropic({ apiKey: config.ANTHROPIC_API_KEY });
      const response = await anthropic.messages.create({
        model: 'claude-sonnet-4-6',
        max_tokens: 400,
        system:
          'You are Zenfit Coach, a knowledgeable and motivating fitness assistant. ' +
          "You have access to the user's fitness data including their goals, recent workouts, calorie logs, and body stats. " +
          'Give concise, actionable advice. Always be encouraging but honest. ' +
          'Never recommend extreme diets or dangerous exercises. ' +
          'If the user describes symptoms that could indicate a medical issue, always recommend consulting a doctor. ' +
          'Keep responses under 200 words unless the user explicitly asks for more detail.',
        messages: messages.map((m) => ({ role: m.role, content: m.content })),
      });

      const textBlock = response.content.find((b) => b.type === 'text');
      const replyText = textBlock?.type === 'text' ? textBlock.text : '';

      // Increment counter only after a successful call so failures don't cost the user a message
      const messagesUsedToday = isPaid ? 0 : await incrementFreeTierCount(userId);

      return reply.send({
        success: true,
        data: { reply: replyText, messagesUsedToday },
      });
    } catch (err) {
      request.log.error(err);
      if (err instanceof Anthropic.RateLimitError) {
        return reply.status(503).send({
          success: false,
          error: { code: 'AI_UNAVAILABLE', message: 'AI service temporarily unavailable. Try again shortly.' },
        });
      }
      if (err instanceof Anthropic.BadRequestError && err.message.includes('credit balance')) {
        return reply.status(503).send({
          success: false,
          error: { code: 'AI_BILLING', message: 'AI service is temporarily unavailable. Please try again later.' },
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
