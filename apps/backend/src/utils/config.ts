import { z } from 'zod';

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().default(3000),
  DATABASE_URL: z.string().url(),
  REDIS_URL: z.string().url(),
  JWT_SECRET: z.string().min(32),
  JWT_REFRESH_SECRET: z.string().min(32),
  ANTHROPIC_API_KEY: z.string().startsWith('sk-'),
  STRIPE_SECRET_KEY: z.string().startsWith('sk_'),
  STRIPE_WEBHOOK_SECRET: z.string(),
  CLOUDINARY_URL: z.string().url(),
  OPEN_FOOD_FACTS_BASE_URL: z.string().url().default('https://world.openfoodfacts.org'),
  USDA_API_KEY: z.string(),
  SENTRY_DSN: z.string().url().optional(),
  AMPLITUDE_API_KEY: z.string().optional(),
  // Firebase Admin SDK — required for server-sent push notifications.
  // Set to the full service account JSON as a single-line string.
  FIREBASE_SERVICE_ACCOUNT: z.string().optional(),
});

const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  console.error('Invalid environment variables:', parsed.error.flatten().fieldErrors);
  process.exit(1);
}

export const config = parsed.data;
