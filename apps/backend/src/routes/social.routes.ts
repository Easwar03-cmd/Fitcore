import type { FastifyPluginAsync } from 'fastify';

const UNAUTHORIZED = { success: false, error: { code: 'UNAUTHORIZED', message: 'Not authenticated' } };
const NOT_IMPLEMENTED = { success: false, error: { code: 'NOT_IMPLEMENTED', message: 'Coming soon' } };

export const socialRoutes: FastifyPluginAsync = async (fastify) => {
  // GET /api/v1/social/friends
  fastify.get('/friends', async (request, reply) => {
    try { await request.jwtVerify(); } catch { return reply.status(401).send(UNAUTHORIZED); }
    // TODO: list accepted friendships
    return reply.status(501).send(NOT_IMPLEMENTED);
  });

  // POST /api/v1/social/friends/:userId
  fastify.post('/friends/:userId', async (request, reply) => {
    try { await request.jwtVerify(); } catch { return reply.status(401).send(UNAUTHORIZED); }
    // TODO: send friend request
    return reply.status(501).send(NOT_IMPLEMENTED);
  });

  // GET /api/v1/social/feed
  fastify.get('/feed', async (request, reply) => {
    try { await request.jwtVerify(); } catch { return reply.status(401).send(UNAUTHORIZED); }
    // TODO: friends' activity feed (workouts, achievements)
    return reply.status(501).send(NOT_IMPLEMENTED);
  });

  // GET /api/v1/social/challenges
  fastify.get('/challenges', async (request, reply) => {
    try { await request.jwtVerify(); } catch { return reply.status(401).send(UNAUTHORIZED); }
    // TODO: active 30-day challenges
    return reply.status(501).send(NOT_IMPLEMENTED);
  });
};
