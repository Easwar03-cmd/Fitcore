import { GoogleGenerativeAI, SchemaType, type Schema } from '@google/generative-ai';
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

  const result = await model.generateContent([
    { inlineData: { mimeType, data: base64Image } },
    prompt,
  ]);

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

  const result = await model.generateContent(prompt);
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

  const result = await model.generateContent(prompt);
  return JSON.parse(result.response.text()) as WorkoutRecommendation;
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
