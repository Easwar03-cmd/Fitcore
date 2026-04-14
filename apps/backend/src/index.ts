import Fastify from 'fastify';
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

const server = Fastify({
  logger: {
    level: config.NODE_ENV === 'production' ? 'warn' : 'info',
  },
});

async function bootstrap() {
  // Plugins
  await server.register(import('@fastify/cors'), { origin: true });
  await server.register(import('@fastify/helmet'));
  await server.register(fastifyJwt, { secret: config.JWT_SECRET });

  // Allow DELETE/GET requests that carry Content-Type: application/json but no body.
  // Dio (Flutter HTTP client) sends this header on every request by default.
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

  // Routes
  await server.register(authRoutes, { prefix: '/api/v1/auth' });
  await server.register(userRoutes, { prefix: '/api/v1/user' });
  await server.register(nutritionRoutes, { prefix: '/api/v1/nutrition' });
  await server.register(workoutRoutes, { prefix: '/api/v1/workout' });
  await server.register(bodyRoutes, { prefix: '/api/v1/body' });
  await server.register(aiRoutes, { prefix: '/api/v1/ai' });
  await server.register(socialRoutes, { prefix: '/api/v1/social' });
  await server.register(wellnessRoutes, { prefix: '/api/v1/wellness' });

  // Health check
  server.get('/health', async () => ({ status: 'ok', timestamp: Date.now() }));

  await server.listen({ port: config.PORT, host: '0.0.0.0' });
  server.log.info(`FitCore API running on port ${config.PORT}`);

  // ── Background jobs (gracefully skipped if Redis is unavailable) ────────
  await scheduleWeeklySummaryJob();
  startWeeklySummaryWorker();
}

bootstrap().catch((err) => {
  server.log.error(err);
  process.exit(1);
});
