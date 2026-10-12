import type { FastifyReply, FastifyRequest } from 'fastify';

/**
 * Fastify preHandler that requires a valid access token.
 * Replaces the per-route `try { await request.jwtVerify() } catch {…}` block.
 *
 *   fastify.get('/x', { preHandler: authenticate }, handler)
 */
export async function authenticate(request: FastifyRequest, reply: FastifyReply): Promise<void> {
  try {
    await request.jwtVerify();
  } catch {
    await reply.status(401).send({
      success: false,
      error: { code: 'UNAUTHORIZED', message: 'Not authenticated' },
    });
  }
}
