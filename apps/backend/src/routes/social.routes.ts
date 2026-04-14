import type { FastifyPluginAsync } from 'fastify';

export const socialRoutes: FastifyPluginAsync = async (fastify) => {
  // GET /api/v1/social/friends
  fastify.get('/friends', async (_request, reply) => {
    // TODO: list accepted friendships
    return reply.status(501).send({ success: false, error: { code: 'NOT_IMPLEMENTED', message: 'Coming soon' } });
  });

  // POST /api/v1/social/friends/:userId
  fastify.post('/friends/:userId', async (_request, reply) => {
    // TODO: send friend request
    return reply.status(501).send({ success: false, error: { code: 'NOT_IMPLEMENTED', message: 'Coming soon' } });
  });

  // GET /api/v1/social/feed
  fastify.get('/feed', async (_request, reply) => {
    // TODO: friends' activity feed (workouts, achievements)
    return reply.status(501).send({ success: false, error: { code: 'NOT_IMPLEMENTED', message: 'Coming soon' } });
  });

  // GET /api/v1/social/challenges
  fastify.get('/challenges', async (_request, reply) => {
    // TODO: active 30-day challenges
    return reply.status(501).send({ success: false, error: { code: 'NOT_IMPLEMENTED', message: 'Coming soon' } });
  });
};
