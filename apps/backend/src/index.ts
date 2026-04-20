import Fastify, { type FastifyError } from 'fastify';
import fastifyJwt from '@fastify/jwt';
import { config } from './utils/config';
import { authRoutes } from './routes/auth.routes';
import { userRoutes } from './routes/user.routes';
import { nutritionRoutes } from './routes/nutrition.routes';
import { workoutRoutes } from './routes/workout.routes';
import { bodyRoutes } from './routes/body.routes';
import { aiRoutes } from './routes/ai.routes';
import { socialRoutes } from './routes/social.routes';
import { wellnessRoutes } from './routes/wellness.routes';
import { integrationsRoutes } from './routes/integrations.routes';
import {
  scheduleWeeklySummaryJob,
  startWeeklySummaryWorker,
} from './jobs/weekly_summary.job';

const server = Fastify({
  // 1 MB global limit covers all regular API payloads (workout logs, nutrition, etc.).
  // The food-photo route overrides this to 20 MB per-route.
  bodyLimit: 1 * 1024 * 1024,
  logger: {
    level: config.NODE_ENV === 'production' ? 'warn' : 'info',
  },
});

async function bootstrap() {
  // ── Security plugins ────────────────────────────────────────────────────────
  await server.register(import('@fastify/cors'), { origin: true });

  await server.register(import('@fastify/helmet'), { global: true });

  // Global rate-limit: 100 req/min per IP.
  await server.register(import('@fastify/rate-limit'), {
    global: true,
    max: 100,
    timeWindow: '1 minute',
    keyGenerator: (request) =>
      (request.headers['x-forwarded-for'] as string)?.split(',')[0]?.trim() ??
      request.ip,
    errorResponseBuilder: (_request, context) => ({
      success: false,
      error: {
        code: 'RATE_LIMITED',
        message: `Too many requests. Try again in ${context.after}.`,
      },
    }),
  });

  // ── Auth plugin ─────────────────────────────────────────────────────────────
  await server.register(fastifyJwt, { secret: config.JWT_SECRET });

  // ── Body parser ─────────────────────────────────────────────────────────────
  // Allow DELETE/GET requests that carry Content-Type: application/json but no
  // body. Dio (Flutter HTTP client) sends this header on every request by default.
  server.addContentTypeParser('application/json', { parseAs: 'string' }, (_req, body, done) => {
    if (!body || (body as string).trim() === '') {
      done(null, {});
      return;
    }
    try {
      done(null, JSON.parse(body as string));
    } catch (err) {
      done(err as Error, undefined);
    }
  });

  // ── Global error handler ────────────────────────────────────────────────────
  server.setErrorHandler((error: FastifyError, request, reply) => {
    request.log.error({ err: error }, 'Unhandled error');

    const statusCode = error.statusCode ?? 500;
    const isProd = config.NODE_ENV === 'production';

    if (statusCode < 500) {
      return reply.status(statusCode).send({
        success: false,
        error: {
          code: error.code ?? 'VALIDATION_ERROR',
          message: error.message,
        },
      });
    }

    return reply.status(statusCode).send({
      success: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: isProd ? 'An unexpected error occurred' : error.message,
      },
    });
  });

  // ── Routes ──────────────────────────────────────────────────────────────────
  await server.register(authRoutes, { prefix: '/api/v1/auth' });
  await server.register(userRoutes, { prefix: '/api/v1/user' });
  await server.register(nutritionRoutes, { prefix: '/api/v1/nutrition' });
  await server.register(workoutRoutes, { prefix: '/api/v1/workout' });
  await server.register(bodyRoutes, { prefix: '/api/v1/body' });
  await server.register(aiRoutes, { prefix: '/api/v1/ai' });
  await server.register(socialRoutes, { prefix: '/api/v1/social' });
  await server.register(wellnessRoutes, { prefix: '/api/v1/wellness' });
  await server.register(integrationsRoutes, { prefix: '/api/v1/integrations' });

  server.get('/health', async () => ({ status: 'ok', timestamp: Date.now() }));

  await server.listen({ port: config.PORT, host: '0.0.0.0' });
  server.log.info(`Zenfit API running on port ${config.PORT}`);

  // ── Background jobs (gracefully skipped if Redis is unavailable) ────────────
  await scheduleWeeklySummaryJob();
  startWeeklySummaryWorker();
}

bootstrap().catch((err) => {
  server.log.error(err);
  process.exit(1);
});
