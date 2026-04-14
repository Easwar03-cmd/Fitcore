import type { FastifyPluginAsync } from 'fastify';

export const aiRoutes: FastifyPluginAsync = async (fastify) => {
  // POST /api/v1/ai/coach
  fastify.post('/coach', async (_request, reply) => {
    // TODO:
    // 1. Check auth + subscription tier
    // 2. Rate-limit free tier (Redis key coach:limit:{userId}, 5 msg/day TTL 24h)
    // 3. Build CoachContext from user's today data
    // 4. Call Claude API (claude-sonnet-4-6) with system prompt from CLAUDE.md
    // 5. Return response
    return reply.status(501).send({ success: false, error: { code: 'NOT_IMPLEMENTED', message: 'Coming soon' } });
  });

  // POST /api/v1/ai/meal-plan
  fastify.post('/meal-plan', async (_request, reply) => {
    // TODO: Pro/Coach tier only — generate weekly meal plan via Claude
    return reply.status(501).send({ success: false, error: { code: 'NOT_IMPLEMENTED', message: 'Coming soon' } });
  });
};
