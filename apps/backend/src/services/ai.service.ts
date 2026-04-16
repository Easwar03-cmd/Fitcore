import Anthropic from '@anthropic-ai/sdk';
import IORedis from 'ioredis';
import { config } from '../utils/config';
import { aiRepository } from '../repositories/ai.repository';

// ─── System prompt (from CLAUDE.md spec) ─────────────────────────────────────

const COACH_SYSTEM_PROMPT =
  'You are Zenfit Coach, a knowledgeable and motivating fitness assistant. ' +
  'You have access to the user\'s fitness data including their goals, recent workouts, calorie logs, and body stats. ' +
  'Give concise, actionable advice. Always be encouraging but honest. ' +
  'Never recommend extreme diets or dangerous exercises. ' +
  'If the user describes symptoms that could indicate a medical issue, always recommend consulting a doctor. ' +
  'Keep responses under 200 words unless the user explicitly asks for more detail.';

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
  | { allowed: true; remaining: number | null } // null = unlimited (pro/coach)
  | { allowed: false; remaining: 0 };

export async function checkCoachRateLimit(
  userId: string,
  subscriptionTier: string | null,
): Promise<RateLimitResult> {
  // Pro and Coach tiers are unlimited
  if (subscriptionTier === 'pro' || subscriptionTier === 'coach') {
    return { allowed: true, remaining: null };
  }

  try {
    const redis = getRedis();
    const key = `coach:limit:${userId}`;
    const count = await redis.incr(key);
    if (count === 1) {
      // First message today — set 24 h TTL
      await redis.expire(key, 24 * 60 * 60);
    }
    const remaining = Math.max(0, FREE_TIER_DAILY_LIMIT - count);
    return count <= FREE_TIER_DAILY_LIMIT
      ? { allowed: true, remaining }
      : { allowed: false, remaining: 0 };
  } catch {
    // Redis unavailable — fail open for better UX
    return { allowed: true, remaining: FREE_TIER_DAILY_LIMIT };
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
  if (user.profile?.targetWeightKg) {
    lines.push(`Target weight: ${user.profile.targetWeightKg} kg`);
  }

  lines.push(
    `Today – calories logged: ${Math.round(nutrition.calories)} kcal`,
    `Today – protein: ${Math.round(nutrition.proteinG)}g / carbs: ${Math.round(nutrition.carbsG)}g / fat: ${Math.round(nutrition.fatG)}g`,
    `Workout today: ${workout ? `Yes (${workout.name}${workout.durationMin ? `, ${workout.durationMin} min` : ''})` : 'No'}`,
    `Workouts this week: ${weekCount}`,
  );

  return `<user_context>\n${lines.join('\n')}\n</user_context>`;
}

// ─── Claude API call ──────────────────────────────────────────────────────────

export type ChatMessage = { role: 'user' | 'assistant'; content: string };

export async function sendCoachMessage(
  userId: string,
  messages: ChatMessage[],
): Promise<string> {
  const anthropic = new Anthropic({ apiKey: config.ANTHROPIC_API_KEY });
  const context = await buildContext(userId);

  // Inject live user context into system prompt.
  // The base prompt is stable (cache-friendly); per-request context follows it.
  const systemPrompt = context
    ? `${COACH_SYSTEM_PROMPT}\n\n${context}`
    : COACH_SYSTEM_PROMPT;

  const stream = anthropic.messages.stream({
    model: 'claude-sonnet-4-6',
    max_tokens: 1024,
    system: systemPrompt,
    messages: messages.map((m) => ({ role: m.role, content: m.content })),
  });

  const final = await stream.finalMessage();
  const textBlock = final.content.find((b) => b.type === 'text');
  return textBlock?.type === 'text' ? textBlock.text : '';
}
