import { GoogleGenerativeAI } from '@google/generative-ai';
import IORedis from 'ioredis';
import { config } from '../utils/config';
import { aiRepository } from '../repositories/ai.repository';

// ─── System prompt ────────────────────────────────────────────────────────────

const COACH_SYSTEM_PROMPT =
  'You are Zenfit Coach, a knowledgeable and motivating fitness assistant. ' +
  "You have access to the user's fitness data including their goals, recent workouts, calorie logs, and body stats. " +
  'Give concise, actionable advice. Always be encouraging but honest. ' +
  'Never recommend extreme diets or dangerous exercises. ' +
  'If the user describes symptoms that could indicate a medical issue, always recommend consulting a doctor. ' +
  'Keep responses under 200 words unless the user explicitly asks for more detail.';

const GEMINI_MODEL = 'gemini-2.0-flash';

const FREE_TIER_DAILY_LIMIT = 5;

// ─── Redis (lazy, fail-open) ──────────────────────────────────────────────────

let _redis: IORedis | null = null;

function getRedis(): IORedis {
  if (!_redis) {
    _redis = new IORedis(config.REDIS_URL, {
      maxRetriesPerRequest: 1,
      enableOfflineQueue: false,
      lazyConnect: true,
      retryStrategy: () => null,
    });
    let _warnedOnce = false;
    _redis.on('error', (err: Error) => {
      if (_warnedOnce) return;
      _warnedOnce = true;
      console.warn('[ai-service] Redis unavailable — rate limiting skipped:', err.message);
    });
  }
  return _redis;
}

// ─── Rate limiting ────────────────────────────────────────────────────────────

export type RateLimitResult =
  | { allowed: true; remaining: number | null }
  | { allowed: false; remaining: 0 };

export async function checkCoachRateLimit(
  userId: string,
  subscriptionTier: string | null,
): Promise<RateLimitResult> {
  if (subscriptionTier === 'pro' || subscriptionTier === 'coach') {
    return { allowed: true, remaining: null };
  }

  try {
    const redis = getRedis();
    const key = `coach:limit:${userId}`;
    const count = await redis.incr(key);
    if (count === 1) await redis.expire(key, 24 * 60 * 60);
    const remaining = Math.max(0, FREE_TIER_DAILY_LIMIT - count);
    return count <= FREE_TIER_DAILY_LIMIT
      ? { allowed: true, remaining }
      : { allowed: false, remaining: 0 };
  } catch {
    return { allowed: true, remaining: FREE_TIER_DAILY_LIMIT };
  }
}

export async function getFreeTierMessageCount(userId: string): Promise<number | null> {
  try {
    const redis = getRedis();
    const val = await redis.get(`coach:limit:${userId}`);
    return val === null ? 0 : parseInt(val, 10);
  } catch {
    return null;
  }
}

export async function incrementFreeTierCount(userId: string): Promise<number> {
  try {
    const redis = getRedis();
    const key = `coach:limit:${userId}`;
    const count = await redis.incr(key);
    if (count === 1) await redis.expire(key, 24 * 60 * 60);
    return count;
  } catch {
    return 0;
  }
}

// ─── Context builder ──────────────────────────────────────────────────────────

async function buildContext(userId: string): Promise<string> {
  const [user, nutrition, workout, weekCount, bodyStat] = await Promise.all([
    aiRepository.getUserWithProfile(userId),
    aiRepository.getTodayNutrition(userId),
    aiRepository.getTodayWorkout(userId),
    aiRepository.getWeekWorkoutCount(userId),
    aiRepository.getLatestBodyStat(userId),
  ]);

  if (!user) return '';

  const lines: string[] = [
    `User: ${user.name}`,
    `Goal: ${user.profile?.fitnessGoal ?? 'not set'}`,
    `Activity level: ${user.profile?.activityLevel ?? 'not set'}`,
    `TDEE: ${user.profile?.tdee ?? 'unknown'} kcal`,
  ];

  if (bodyStat?.weightKg) lines.push(`Current weight: ${bodyStat.weightKg} kg`);
  if (user.profile?.targetWeightKg) lines.push(`Target weight: ${user.profile.targetWeightKg} kg`);

  lines.push(
    `Today – calories logged: ${Math.round(nutrition.calories)} kcal`,
    `Today – protein: ${Math.round(nutrition.proteinG)}g / carbs: ${Math.round(nutrition.carbsG)}g / fat: ${Math.round(nutrition.fatG)}g`,
    `Workout today: ${workout ? `Yes (${workout.name}${workout.durationMin ? `, ${workout.durationMin} min` : ''})` : 'No'}`,
    `Workouts this week: ${weekCount}`,
  );

  return `<user_context>\n${lines.join('\n')}\n</user_context>`;
}

// ─── Gemini API call ──────────────────────────────────────────────────────────

export type ChatMessage = { role: 'user' | 'assistant'; content: string };

export async function sendCoachMessage(
  userId: string,
  messages: ChatMessage[],
): Promise<string> {
  if (messages.length === 0) return '';

  const context = await buildContext(userId);
  const systemPrompt = context
    ? `${COACH_SYSTEM_PROMPT}\n\n${context}`
    : COACH_SYSTEM_PROMPT;

  const genAI = new GoogleGenerativeAI(config.GEMINI_API_KEY);
  const model = genAI.getGenerativeModel({
    model: GEMINI_MODEL,
    systemInstruction: systemPrompt,
  });

  // Gemini uses 'model' instead of 'assistant' for the AI role.
  // History = everything except the last message (which we send now).
  const history = messages.slice(0, -1).map((m) => ({
    role: m.role === 'assistant' ? ('model' as const) : ('user' as const),
    parts: [{ text: m.content }],
  }));

  const lastMessage = messages[messages.length - 1];

  const chat = model.startChat({ history });
  const result = await chat.sendMessage(lastMessage.content);
  return result.response.text();
}
