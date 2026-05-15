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
import { paymentsRoutes } from './routes/payments.routes';
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
  const allowedOrigins = [
    'https://zenfit-api-122167595419.us-central1.run.app',
    ...(config.NODE_ENV !== 'production' ? ['http://localhost:3000', 'http://127.0.0.1:3000'] : []),
  ];
  await server.register(import('@fastify/cors'), {
    origin: (origin, cb) => {
      // Mobile app (Flutter/Dio) sends no Origin header — intentionally allowed.
      // CORS is browser-only enforcement; JWT auth is the actual access control.
      if (!origin) return cb(null, true);
      if (allowedOrigins.includes(origin)) return cb(null, true);
      cb(new Error('Not allowed by CORS'), false);
    },
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  });

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
    // Save raw string so webhook routes can verify Stripe signatures.
    (_req as unknown as Record<string, unknown>).rawBody = body ?? '';
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
  await server.register(paymentsRoutes, { prefix: '/api/v1/payments' });

  server.get('/health', async () => ({ status: 'ok' }));

  server.get('/payment/success', async (_req, reply) => {
    return reply.type('text/html').send(
      `<!DOCTYPE html><html><head><meta charset="utf-8"><title>Zenfit — Payment Successful</title>
      <style>body{font-family:sans-serif;display:flex;flex-direction:column;align-items:center;justify-content:center;height:100vh;margin:0;background:#0f0f14;color:#fff;}
      h1{font-size:2rem;margin-bottom:.5rem;}p{color:#aaa;font-size:1rem;}</style></head>
      <body><h1>🎉 Welcome to Pro!</h1><p>Your subscription is active. You can close this tab and return to Zenfit.</p></body></html>`,
    );
  });

  server.get('/payment/cancel', async (_req, reply) => {
    return reply.type('text/html').send(
      `<!DOCTYPE html><html><head><meta charset="utf-8"><title>Zenfit — Checkout Cancelled</title>
      <style>body{font-family:sans-serif;display:flex;flex-direction:column;align-items:center;justify-content:center;height:100vh;margin:0;background:#0f0f14;color:#fff;}
      h1{font-size:2rem;margin-bottom:.5rem;}p{color:#aaa;font-size:1rem;}</style></head>
      <body><h1>Checkout Cancelled</h1><p>No charges were made. You can close this tab and return to Zenfit.</p></body></html>`,
    );
  });

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
