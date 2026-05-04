import { z } from 'zod';

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().default(3000),
  DATABASE_URL: z.string().url(),
  REDIS_URL: z.string().url(),
  JWT_SECRET: z.string().min(32),
  JWT_REFRESH_SECRET: z.string().min(32),
  GEMINI_API_KEY: z.string().min(10),
  STRIPE_SECRET_KEY: z.string().startsWith('sk_'),
  STRIPE_WEBHOOK_SECRET: z.string(),
  STRIPE_PRO_PRICE_ID: z.string().optional(),
  STRIPE_COACH_PRICE_ID: z.string().optional(),
  CLOUDINARY_URL: z.string().url(),
  OPEN_FOOD_FACTS_BASE_URL: z.string().url().default('https://world.openfoodfacts.org'),
  USDA_API_KEY: z.string(),
  AMPLITUDE_API_KEY: z.string().optional(),
  // Comma-separated emails that bypass the daily AI coach rate limit (dev/admin accounts).
  ADMIN_EMAILS: z.string().optional(),
  // Firebase Admin SDK — required for server-sent push notifications.
  // Set to the full service account JSON as a single-line string.
  FIREBASE_SERVICE_ACCOUNT: z.string().optional(),
  // Google Play Billing — required for Android subscription verification.
  // GOOGLE_PLAY_PACKAGE_NAME: the app's applicationId (e.g. com.zenfit.app).
  // GOOGLE_PLAY_SERVICE_ACCOUNT_JSON: full JSON key file contents as a single-line string.
  // Grant the service account "View financial data" in Google Play Console → Setup → API access.
  GOOGLE_PLAY_PACKAGE_NAME: z.string().optional(),
  GOOGLE_PLAY_SERVICE_ACCOUNT_JSON: z.string().optional(),

  // SMTP email — all optional; if unset the app falls back to logging the reset code.
  SMTP_HOST: z.string().optional(),
  SMTP_PORT: z.coerce.number().optional(),
  SMTP_SECURE: z.string().optional(), // 'true' for TLS (port 465)
  SMTP_USER: z.string().optional(),
  SMTP_PASS: z.string().optional(),
  SMTP_FROM: z.string().optional(), // e.g. "Zenfit <no-reply@zenfit.app>"
});

const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  console.error('Invalid environment variables:', parsed.error.flatten().fieldErrors);
  process.exit(1);
}

export const config = parsed.data;
