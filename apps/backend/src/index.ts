import * as Sentry from '@sentry/node';
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
import {
  scheduleWeeklySummaryJob,
  startWeeklySummaryWorker,
} from './jobs/weekly_summary.job';

// ── Sentry (initialise before anything else so it can catch startup errors) ──
if (config.SENTRY_DSN) {
  Sentry.init({
    dsn: config.SENTRY_DSN,
    environment: config.NODE_ENV,
    // Capture 10 % of transactions in production; full sampling elsewhere.
    tracesSampleRate: config.NODE_ENV === 'production' ? 0.1 : 1.0,
  });
}

const server = Fastify({
  // Reject JSON bodies larger than 10 kb to prevent memory-exhaustion attacks.
  bodyLimit: 10 * 1024,
  logger: {
    level: config.NODE_ENV === 'production' ? 'warn' : 'info',
  },
});

async function bootstrap() {
  // ── Security plugins ────────────────────────────────────────────────────────
  await server.register(import('@fastify/cors'), { origin: true });

  // HTTP security headers (X-Frame-Options, CSP, HSTS, etc.)
  await server.register(import('@fastify/helmet'), {
    // contentSecurityPolicy: false is the default; enable once you know your
    // CDN / asset URLs so you can whitelist them properly.
    global: true,
  });

  // Global rate-limit: 100 req/min per IP.
  // Auth routes override this with a stricter 10 req/min limit (see auth.routes.ts).
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
  // Never leak stack traces or internal error details to clients in production.
  server.setErrorHandler((error: FastifyError, request, reply) => {
    request.log.error({ err: error }, 'Unhandled error');

    if (config.SENTRY_DSN) {
      Sentry.captureException(error);
    }

    const statusCode = error.statusCode ?? 500;
    const isProd = config.NODE_ENV === 'production';

    // Validation errors (400) are safe to relay; server errors are not.
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
        // Stack traces only in non-production environments.
        ...(isProd ? {} : { stack: error.stack }),
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

  // Health check (excluded from rate-limiting by the high global limit)
  server.get('/health', async () => ({ status: 'ok', timestamp: Date.now() }));

  await server.listen({ port: config.PORT, host: '0.0.0.0' });
  server.log.info(`Zenfit API running on port ${config.PORT}`);

  // ── Background jobs (gracefully skipped if Redis is unavailable) ────────────
  await scheduleWeeklySummaryJob();
  startWeeklySummaryWorker();
}

bootstrap().catch((err) => {
  server.log.error(err);
  if (config.SENTRY_DSN) Sentry.captureException(err);
  process.exit(1);
});
