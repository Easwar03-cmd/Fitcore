import { GoogleGenerativeAI, GoogleGenerativeAIFetchError, SchemaType, type Schema } from '@google/generative-ai';
import IORedis from 'ioredis';
import { config } from '../utils/config';
import { aiRepository } from '../repositories/ai.repository';

// ─── Gemini request queue ─────────────────────────────────────────────────────
// Gemini free-tier: 15 RPM = 1 request every 4 seconds.
// Serialising all calls through a single queue prevents concurrent bursts that
// trigger 429s. Each task waits for the previous one to finish, then the queue
// inserts a 4.5 s gap before the next call starts.

const GEMINI_MIN_GAP_MS = 4500;

class GeminiQueue {
  private readonly q: Array<() => Promise<void>> = [];
  private running = false;

  enqueue<T>(fn: () => Promise<T>): Promise<T> {
    return new Promise<T>((resolve, reject) => {
      this.q.push(async () => {
        try { resolve(await fn()); } catch (e) { reject(e); }
      });
      if (!this.running) this._drain();
    });
  }

  private async _drain() {
    this.running = true;
    while (this.q.length > 0) {
      const task = this.q.shift()!;
      await task();
      if (this.q.length > 0) {
        await new Promise<void>(r => setTimeout(r, GEMINI_MIN_GAP_MS));
      }
    }
    this.running = false;
  }
}

const geminiQueue = new GeminiQueue();

// ─── Retry helper ─────────────────────────────────────────────────────────────
// With the queue in front, 429s should be rare. We keep a short retry as a
// safety net for transient spikes.

const GEMINI_CHAT_RETRY_DELAYS_MS  = [4000];
const GEMINI_BATCH_RETRY_DELAYS_MS = [8000, 30000];

async function withGeminiRetry<T>(
  fn: () => Promise<T>,
  delays = GEMINI_BATCH_RETRY_DELAYS_MS,
): Promise<T> {
  let lastErr: unknown;
  for (let attempt = 0; attempt <= delays.length; attempt++) {
    try {
      return await fn();
    } catch (err) {
      lastErr = err;
      const is429 = err instanceof GoogleGenerativeAIFetchError && err.status === 429;
      if (is429 && attempt < delays.length) {
        await new Promise<void>((res) => setTimeout(res, delays[attempt]));
        continue;
      }
      throw err;
    }
  }
  throw lastErr;
}

// ─── System prompt ────────────────────────────────────────────────────────────

const COACH_SYSTEM_PROMPT = `You are Alex, a personal fitness coach. Reply like you're texting a client — short, direct, and human.

Style rules (strictly follow these):
- Keep each thought to 1-3 sentences max
- If you need to say more, break it into separate short paragraphs with a blank line between each (each becomes its own message bubble)
- Never use bullet points, numbered lists, or markdown headers in your replies
- Write casually — like a real person, not a report
- Use the user's name if you know it
- If they ask something simple, give a simple answer — don't pad it out
- Only go deeper when they explicitly ask for more detail

Your knowledge: strength training, hypertrophy, fat loss, nutrition, recovery, mindset.

Use the user's data (goal, calories today, workouts done) when it's relevant — but don't mention data they didn't ask about.

If there's a real medical concern, tell them to see a doctor. Never recommend dangerous practices.`;

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

// ─── RAG-lite: topic-specific context caches (15-min TTL) ────────────────────
// Each topic has its own cache so a nutrition question doesn't evict
// workout cache and vice versa.

const CTX_TTL = 15 * 60 * 1000;

type CtxTopic = 'nutrition' | 'workout' | 'body';

const _profileCache  = new Map<string, { lines: string[]; expiresAt: number }>();
const _nutritionCache = new Map<string, { line: string;   expiresAt: number }>();
const _workoutCache  = new Map<string, { lines: string[]; expiresAt: number }>();
const _bodyCache     = new Map<string, { lines: string[]; expiresAt: number }>();

// ─── Topic detection ──────────────────────────────────────────────────────────

const CASUAL_RE = /^(hi+|hello|hey|thanks?|thank you|ok|okay|sure|bye|good|great|yes|no|lol|haha|cool|nice|awesome|got it|sounds good|perfect|alright|sup|what'?s up|wassup|yep|nope|hmm+)[\s!?.]*$/i;

function isCasualMessage(msg: string): boolean {
  const t = msg.trim();
  if (t.length <= 12) return true;
  return CASUAL_RE.test(t);
}

function detectTopics(msg: string): Set<CtxTopic> {
  const topics = new Set<CtxTopic>();
  const m = msg.toLowerCase();

  if (/\b(calori|eat|food|meal|diet|macr|protein|carb|fat|fiber|hungry|breakfast|lunch|dinner|snack|nutri|what.*eat|how much.*eat|should.*eat)\b/.test(m)) {
    topics.add('nutrition');
  }
  if (/\b(workout|exercise|train|gym|lift|run|running|sets?|reps?|cardio|muscle|squat|bench|deadlift|session|volume|strength|weights?|push|pull)\b/.test(m)) {
    topics.add('workout');
  }
  if (/\b(weigh|body fat|bmi|physique|progress|body stat|measurement|\bkg\b|\blbs?\b|\bpounds?\b|bulk|cut|lean)\b/.test(m)) {
    topics.add('body');
  }

  return topics;
}

// ─── Context retriever ────────────────────────────────────────────────────────
// Only fetches the DB data that is actually relevant to the user's message.
// Casual / short messages get no context — the AI answers from general knowledge.

async function retrieveContext(userId: string, userMessage: string): Promise<string> {
  if (isCasualMessage(userMessage)) return '';

  const topics = detectTopics(userMessage);
  if (topics.size === 0) return '';

  const now = Date.now();
  const parts: string[] = [];

  // ── Profile (name + goal) — fetched once for any topic-bearing message ──
  const cachedProfile = _profileCache.get(userId);
  if (cachedProfile && cachedProfile.expiresAt > now) {
    parts.push(...cachedProfile.lines);
  } else {
    const user = await aiRepository.getUserWithProfile(userId);
    if (!user) return '';
    const profileLines = [
      `User: ${user.name}`,
      `Goal: ${user.profile?.fitnessGoal ?? 'not set'}`,
      `Activity level: ${user.profile?.activityLevel ?? 'not set'}`,
      `TDEE: ${user.profile?.tdee ?? 'unknown'} kcal`,
    ];
    if (user.profile?.targetWeightKg) profileLines.push(`Target weight: ${user.profile.targetWeightKg} kg`);
    _profileCache.set(userId, { lines: profileLines, expiresAt: now + CTX_TTL });
    parts.push(...profileLines);
  }

  // ── Nutrition (today's calories + macros) ──
  if (topics.has('nutrition')) {
    const cachedNutrition = _nutritionCache.get(userId);
    if (cachedNutrition && cachedNutrition.expiresAt > now) {
      parts.push(cachedNutrition.line);
    } else {
      const nutrition = await aiRepository.getTodayNutrition(userId);
      const line = `Today – calories: ${Math.round(nutrition.calories)} kcal | protein: ${Math.round(nutrition.proteinG)}g | carbs: ${Math.round(nutrition.carbsG)}g | fat: ${Math.round(nutrition.fatG)}g`;
      _nutritionCache.set(userId, { line, expiresAt: now + CTX_TTL });
      parts.push(line);
    }
  }

  // ── Workout (today + this week) ──
  if (topics.has('workout')) {
    const cachedWorkout = _workoutCache.get(userId);
    if (cachedWorkout && cachedWorkout.expiresAt > now) {
      parts.push(...cachedWorkout.lines);
    } else {
      const [workout, weekCount] = await Promise.all([
        aiRepository.getTodayWorkout(userId),
        aiRepository.getWeekWorkoutCount(userId),
      ]);
      const workoutLines = [
        `Workout today: ${workout ? `Yes (${workout.name}${workout.durationMin ? `, ${workout.durationMin} min` : ''})` : 'No'}`,
        `Workouts this week: ${weekCount}`,
      ];
      _workoutCache.set(userId, { lines: workoutLines, expiresAt: now + CTX_TTL });
      parts.push(...workoutLines);
    }
  }

  // ── Body stats (current weight) ──
  if (topics.has('body')) {
    const cachedBody = _bodyCache.get(userId);
    if (cachedBody && cachedBody.expiresAt > now) {
      if (cachedBody.lines.length > 0) parts.push(...cachedBody.lines);
    } else {
      const bodyStat = await aiRepository.getLatestBodyStat(userId);
      const bodyLines: string[] = [];
      if (bodyStat?.weightKg) bodyLines.push(`Current weight: ${bodyStat.weightKg} kg`);
      _bodyCache.set(userId, { lines: bodyLines, expiresAt: now + CTX_TTL });
      parts.push(...bodyLines);
    }
  }

  if (parts.length === 0) return '';
  return `<user_context>\n${parts.join('\n')}\n</user_context>`;
}

// ─── Food photo analysis ──────────────────────────────────────────────────────

export interface DetectedFoodItem {
  foodName: string;
  servingG: number;
  calories: number;
  proteinG: number;
  carbsG: number;
  fatG: number;
  fiberG?: number;
  confidence: 'high' | 'medium' | 'low';
}

export interface FoodPhotoAnalysis {
  detectedFoods: DetectedFoodItem[];
  totalCalories: number;
  notes?: string;
}

const FOOD_PHOTO_SYSTEM_PROMPT =
  'You are a highly accurate nutritionist and food recognition expert. ' +
  'Analyze food images with extreme precision. ' +
  'For every food item visible — including garnishes, sauces, sides, and condiments — ' +
  'identify the specific food name, estimate the portion weight in grams, ' +
  'and provide accurate nutritional values based on standard food databases (USDA, IFCT). ' +
  'Be especially thorough with Indian and Asian mixed dishes: identify each component separately. ' +
  'Use specific food names (e.g. "basmati rice" not "rice", "dal makhani" not "lentils"). ' +
  'Portion estimates must be realistic for the plate/bowl size visible.';

export async function analyzeFoodPhoto(
  base64Image: string,
  mimeType: string,
): Promise<FoodPhotoAnalysis> {
  const prompt =
    'Analyze this food photo and identify EVERY food item visible on the plate or bowl. ' +
    'Include all components: main dish, sides, sauces, gravies, garnishes, and beverages. ' +
    'For each item provide: specific food name, estimated serving weight (grams), ' +
    'calories (kcal), protein (g), carbohydrates (g), fat (g), fiber (g if applicable), ' +
    'and your confidence level (high/medium/low). ' +
    'For composite dishes (biryani, curry, thali), identify each visible component separately. ' +
    'Use standard nutritional databases for accuracy. ' +
    'If you cannot identify something clearly, still estimate it and mark confidence as low.';

  const responseSchema: Schema = {
    type: SchemaType.OBJECT,
    properties: {
      detectedFoods: {
        type: SchemaType.ARRAY,
        items: {
          type: SchemaType.OBJECT,
          properties: {
            foodName: { type: SchemaType.STRING },
            servingG: { type: SchemaType.NUMBER },
            calories: { type: SchemaType.NUMBER },
            proteinG: { type: SchemaType.NUMBER },
            carbsG: { type: SchemaType.NUMBER },
            fatG: { type: SchemaType.NUMBER },
            fiberG: { type: SchemaType.NUMBER },
            confidence: { type: SchemaType.STRING },
          },
          required: ['foodName', 'servingG', 'calories', 'proteinG', 'carbsG', 'fatG', 'confidence'],
        },
      },
      totalCalories: { type: SchemaType.NUMBER },
      notes: { type: SchemaType.STRING },
    },
    required: ['detectedFoods', 'totalCalories'],
  };

  const genAI = new GoogleGenerativeAI(config.GEMINI_API_KEY);
  const model = genAI.getGenerativeModel({
    model: GEMINI_MODEL,
    systemInstruction: FOOD_PHOTO_SYSTEM_PROMPT,
    generationConfig: {
      responseMimeType: 'application/json',
      responseSchema,
    },
  });

  const result = await geminiQueue.enqueue(() =>
    withGeminiRetry(() =>
      model.generateContent([{ inlineData: { mimeType, data: base64Image } }, prompt]),
    ),
  );

  const text = result.response.text();
  const parsed = JSON.parse(text) as FoodPhotoAnalysis;

  if (!parsed.detectedFoods || parsed.detectedFoods.length === 0) {
    throw new Error('No food items detected in the image. Please try a clearer photo.');
  }

  return parsed;
}

// ─── Meal plan types ──────────────────────────────────────────────────────────

export interface PlannedMeal {
  mealType: 'breakfast' | 'lunch' | 'dinner' | 'snack';
  name: string;
  calories: number;
  proteinG: number;
  carbsG: number;
  fatG: number;
  ingredients: string[];
  prepTimeMin: number;
}

export interface DayMealPlan {
  dayName: string;
  totalCalories: number;
  totalProteinG: number;
  totalCarbsG: number;
  totalFatG: number;
  meals: PlannedMeal[];
}

export interface WeeklyMealPlan {
  days: DayMealPlan[];
}

// ─── Meal plan generator ──────────────────────────────────────────────────────

const DAY_NAMES = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/** Compute daily macro gram targets from TDEE + goal (mirrors CLAUDE.md formula). */
function macrosForGoal(tdee: number, goal: string) {
  const cal = goal === 'lose_weight' ? tdee - 500 : goal === 'build_muscle' ? tdee + 300 : tdee;
  const splits =
    goal === 'lose_weight'
      ? { p: 0.4, c: 0.3, f: 0.3 }
      : goal === 'build_muscle'
        ? { p: 0.3, c: 0.5, f: 0.2 }
        : { p: 0.3, c: 0.4, f: 0.3 };
  return {
    calories: Math.round(cal),
    proteinG: Math.round((cal * splits.p) / 4),
    carbsG: Math.round((cal * splits.c) / 4),
    fatG: Math.round((cal * splits.f) / 9),
  };
}

export async function generateMealPlan(userId: string): Promise<WeeklyMealPlan> {
  const [user, bodyStat] = await Promise.all([
    aiRepository.getUserWithProfile(userId),
    aiRepository.getLatestBodyStat(userId),
  ]);

  if (!user || !user.profile) throw new Error('User profile not found');

  const { fitnessGoal, activityLevel, tdee } = user.profile;
  const macros = macrosForGoal(tdee ?? 2000, fitnessGoal ?? 'maintain');

  const prompt =
    `Generate a 7-day meal plan for a fitness app user.\n` +
    `User goal: ${fitnessGoal ?? 'maintain'}\n` +
    `Activity level: ${activityLevel ?? 'moderate'}\n` +
    `Daily calorie target: ${macros.calories} kcal\n` +
    `Daily macro targets: protein ${macros.proteinG}g, carbs ${macros.carbsG}g, fat ${macros.fatG}g\n` +
    (bodyStat?.weightKg ? `Current weight: ${bodyStat.weightKg} kg\n` : '') +
    `Rules:\n` +
    `- Include exactly 3 or 4 meals per day (breakfast, lunch, dinner, optionally snack)\n` +
    `- Each day's total calories must be within 80 kcal of the daily target\n` +
    `- Vary meals across the 7 days — no repeated meal names\n` +
    `- Use practical, commonly available ingredients\n` +
    `- Days must be in order: Monday through Sunday\n` +
    `- Meal types must be one of: breakfast, lunch, dinner, snack`;

  const responseSchema: Schema = {
    type: SchemaType.OBJECT,
    properties: {
      days: {
        type: SchemaType.ARRAY,
        items: {
          type: SchemaType.OBJECT,
          properties: {
            dayName: { type: SchemaType.STRING },
            totalCalories: { type: SchemaType.NUMBER },
            totalProteinG: { type: SchemaType.NUMBER },
            totalCarbsG: { type: SchemaType.NUMBER },
            totalFatG: { type: SchemaType.NUMBER },
            meals: {
              type: SchemaType.ARRAY,
              items: {
                type: SchemaType.OBJECT,
                properties: {
                  mealType: { type: SchemaType.STRING },
                  name: { type: SchemaType.STRING },
                  calories: { type: SchemaType.NUMBER },
                  proteinG: { type: SchemaType.NUMBER },
                  carbsG: { type: SchemaType.NUMBER },
                  fatG: { type: SchemaType.NUMBER },
                  ingredients: { type: SchemaType.ARRAY, items: { type: SchemaType.STRING } },
                  prepTimeMin: { type: SchemaType.NUMBER },
                },
                required: ['mealType', 'name', 'calories', 'proteinG', 'carbsG', 'fatG', 'ingredients', 'prepTimeMin'],
              },
            },
          },
          required: ['dayName', 'totalCalories', 'totalProteinG', 'totalCarbsG', 'totalFatG', 'meals'],
        },
      },
    },
    required: ['days'],
  };

  const genAI = new GoogleGenerativeAI(config.GEMINI_API_KEY);
  const model = genAI.getGenerativeModel({
    model: GEMINI_MODEL,
    generationConfig: {
      responseMimeType: 'application/json',
      responseSchema,
    },
  });

  const result = await geminiQueue.enqueue(() =>
    withGeminiRetry(() => model.generateContent(prompt)),
  );
  const text = result.response.text();
  const parsed = JSON.parse(text) as WeeklyMealPlan;

  // Ensure exactly 7 days with correct names
  if (!parsed.days || parsed.days.length !== 7) {
    throw new Error('Meal plan generation returned unexpected structure');
  }
  parsed.days.forEach((d, i) => { d.dayName = DAY_NAMES[i]; });

  return parsed;
}

// ─── Workout recommendation ───────────────────────────────────────────────────

export interface SuggestedExercise {
  name: string;
  sets: number;
  reps: string;
  restSec: number;
}

export interface WorkoutRecommendation {
  workoutName: string;
  reasoning: string;
  targetMuscleGroups: string[];
  suggestedExercises: SuggestedExercise[];
  estimatedDurationMin: number;
  intensity: 'light' | 'moderate' | 'hard';
}

export async function getWorkoutRecommendation(userId: string): Promise<WorkoutRecommendation> {
  const [user, bodyStat, weeklyWorkouts] = await Promise.all([
    aiRepository.getUserWithProfile(userId),
    aiRepository.getLatestBodyStat(userId),
    aiRepository.getWeeklyWorkoutSummary(userId),
  ]);

  if (!user) throw new Error('User not found');

  const goal = user.profile?.fitnessGoal ?? 'maintain';
  const activityLevel = user.profile?.activityLevel ?? 'moderate';

  // Summarise last 7 days of training
  const historyLines: string[] = weeklyWorkouts.map((w) => {
    const date = w.startedAt.toISOString().split('T')[0];
    const exercises = [...new Set(w.sets.map((s) => s.exerciseName))].join(', ');
    const totalSets = w.sets.length;
    return `${date}: ${w.name} — ${exercises} (${totalSets} sets, ${w.durationMin ?? '?'} min)`;
  });

  const hasTrainedToday = weeklyWorkouts.some((w) => {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    return w.startedAt >= today;
  });

  const prompt =
    `You are a personal trainer. Based on the user's recent workout history, ` +
    `recommend the optimal workout for today.\n\n` +
    `User goal: ${goal}\n` +
    `Activity level: ${activityLevel}\n` +
    (bodyStat?.weightKg ? `Body weight: ${bodyStat.weightKg} kg\n` : '') +
    `Trained today already: ${hasTrainedToday ? 'Yes' : 'No'}\n\n` +
    `Workout history (last 7 days):\n` +
    (historyLines.length > 0 ? historyLines.join('\n') : 'No workouts logged this week') +
    `\n\nRules:\n` +
    `- Recommend the muscle groups most in need of training based on the history\n` +
    `- If the user just trained yesterday (hard session), suggest light or a different muscle group\n` +
    `- If no workouts this week, suggest a full-body or compound session\n` +
    `- Include 4–6 exercises with sets, reps (or duration as a string like "30s"), and rest in seconds\n` +
    `- intensity must be one of: light, moderate, hard`;

  const responseSchema: Schema = {
    type: SchemaType.OBJECT,
    properties: {
      workoutName: { type: SchemaType.STRING },
      reasoning: { type: SchemaType.STRING },
      targetMuscleGroups: { type: SchemaType.ARRAY, items: { type: SchemaType.STRING } },
      suggestedExercises: {
        type: SchemaType.ARRAY,
        items: {
          type: SchemaType.OBJECT,
          properties: {
            name: { type: SchemaType.STRING },
            sets: { type: SchemaType.NUMBER },
            reps: { type: SchemaType.STRING },
            restSec: { type: SchemaType.NUMBER },
          },
          required: ['name', 'sets', 'reps', 'restSec'],
        },
      },
      estimatedDurationMin: { type: SchemaType.NUMBER },
      intensity: { type: SchemaType.STRING },
    },
    required: ['workoutName', 'reasoning', 'targetMuscleGroups', 'suggestedExercises', 'estimatedDurationMin', 'intensity'],
  };

  const genAI = new GoogleGenerativeAI(config.GEMINI_API_KEY);
  const model = genAI.getGenerativeModel({
    model: GEMINI_MODEL,
    generationConfig: { responseMimeType: 'application/json', responseSchema },
  });

  const result = await geminiQueue.enqueue(() =>
    withGeminiRetry(() => model.generateContent(prompt)),
  );
  return JSON.parse(result.response.text()) as WorkoutRecommendation;
}

// ─── Deload check ─────────────────────────────────────────────────────────────

export interface DeloadCheck {
  needsDeload: boolean;
  consecutiveHighVolumeWeeks: number;
  totalSetsThisWeek: number;
  weeklyAverageSets: number;
  reason: string;
  recommendation: string;
}

const HIGH_VOLUME_THRESHOLD = 40; // sets/week considered high

export async function getDeloadCheck(userId: string): Promise<DeloadCheck> {
  const logs = await aiRepository.getFourWeekWorkoutSummary(userId);

  // Bucket logs into 4 weekly slots (0 = 3 weeks ago, 3 = current week).
  const now = new Date();
  const weeklySetCounts = [0, 0, 0, 0];
  for (const log of logs) {
    const daysAgo = Math.floor(
      (now.getTime() - log.startedAt.getTime()) / (1000 * 60 * 60 * 24),
    );
    const weekIdx = 3 - Math.floor(daysAgo / 7);
    if (weekIdx >= 0 && weekIdx <= 3) weeklySetCounts[weekIdx] += log.sets.length;
  }

  const totalSetsThisWeek = weeklySetCounts[3];
  const weeklyAverageSets = Math.round(
    weeklySetCounts.reduce((a, b) => a + b, 0) / 4,
  );

  // Count consecutive high-volume weeks ending with the current week.
  let consecutiveHighVolumeWeeks = 0;
  for (let i = 3; i >= 0; i--) {
    if (weeklySetCounts[i] >= HIGH_VOLUME_THRESHOLD) consecutiveHighVolumeWeeks++;
    else break;
  }

  const needsDeload =
    consecutiveHighVolumeWeeks >= 3 || weeklyAverageSets > 60;

  const reason = needsDeload
    ? consecutiveHighVolumeWeeks >= 3
      ? `${consecutiveHighVolumeWeeks} consecutive high-volume weeks (≥${HIGH_VOLUME_THRESHOLD} sets each).`
      : `4-week average of ${weeklyAverageSets} sets/week is very high.`
    : '';

  const recommendation = needsDeload
    ? 'Cut volume by 40–50% and intensity by ~20% this week. Focus on technique and mobility. You\'ll come back stronger.'
    : '';

  return {
    needsDeload,
    consecutiveHighVolumeWeeks,
    totalSetsThisWeek,
    weeklyAverageSets,
    reason,
    recommendation,
  };
}

// ─── Gemini API call ──────────────────────────────────────────────────────────

export type ChatMessage = { role: 'user' | 'assistant'; content: string };

export async function sendCoachMessage(
  userId: string,
  messages: ChatMessage[],
): Promise<string> {
  if (messages.length === 0) return '';

  const lastUserMessage = [...messages].reverse().find((m) => m.role === 'user')?.content ?? '';
  const context = await retrieveContext(userId, lastUserMessage);
  const systemPrompt = context
    ? `${COACH_SYSTEM_PROMPT}\n\n${context}`
    : COACH_SYSTEM_PROMPT;

  const genAI = new GoogleGenerativeAI(config.GEMINI_API_KEY);

  // Build the full conversation as a contents array.
  // Using generateContent (not startChat) avoids issues with chat session
  // state when retrying and is more reliable with multi-turn history.
  // Gemini requires: alternating user/model roles, last entry must be user.
  const contents = messages.map((m) => ({
    role: m.role === 'assistant' ? ('model' as const) : ('user' as const),
    parts: [{ text: m.content }],
  }));

  const result = await geminiQueue.enqueue(() =>
    withGeminiRetry(() => {
      const model = genAI.getGenerativeModel({
        model: GEMINI_MODEL,
        systemInstruction: systemPrompt,
      });
      return model.generateContent({ contents });
    }, GEMINI_CHAT_RETRY_DELAYS_MS),
  );
  return result.response.text();
}
