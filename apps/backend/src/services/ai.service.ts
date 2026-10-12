import { GoogleGenerativeAI, GoogleGenerativeAIFetchError, SchemaType, type Schema } from '@google/generative-ai';
import pino from 'pino';
import { config } from '../utils/config';
import { aiRepository } from '../repositories/ai.repository';

const log = pino({ level: config.NODE_ENV === 'production' ? 'warn' : 'info' });

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

// Overridable via env so a model retirement doesn't need a code change.
const GEMINI_MODEL = config.GEMINI_MODEL;

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

export async function getWorkoutRecommendation(
  userId: string,
  type: 'gym' | 'home' = 'gym',
): Promise<WorkoutRecommendation> {
  const [user, bodyStat, weeklyWorkouts] = await Promise.all([
    aiRepository.getUserWithProfile(userId),
    aiRepository.getLatestBodyStat(userId),
    aiRepository.getWeeklyWorkoutSummary(userId),
  ]);

  if (!user) throw new Error('User not found');

  const goal = user.profile?.fitnessGoal ?? 'maintain';
  const activityLevel = user.profile?.activityLevel ?? 'moderate';

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

  const equipmentRule = type === 'home'
    ? 'CRITICAL: Recommend ONLY bodyweight/calisthenics exercises — no equipment whatsoever. ' +
      'Use exercises like push-ups, pull-ups, squats, lunges, dips, pike push-ups, burpees, ' +
      'mountain climbers, hollow body holds, pistol squats, handstand push-ups, etc.'
    : 'Recommend gym exercises using equipment (barbells, dumbbells, cables, machines, etc.). ' +
      'Include compound lifts and accessory work appropriate for a gym setting.';

  const prompt =
    `You are a personal trainer. Based on the user's recent workout history, ` +
    `recommend the optimal ${type === 'home' ? 'home/bodyweight' : 'gym'} workout for today.\n\n` +
    `User goal: ${goal}\n` +
    `Activity level: ${activityLevel}\n` +
    (bodyStat?.weightKg ? `Body weight: ${bodyStat.weightKg} kg\n` : '') +
    `Trained today already: ${hasTrainedToday ? 'Yes' : 'No'}\n\n` +
    `Workout history (last 7 days):\n` +
    (historyLines.length > 0 ? historyLines.join('\n') : 'No workouts logged this week') +
    `\n\nRules:\n` +
    `- ${equipmentRule}\n` +
    `- Recommend the muscle groups most in need of training based on history\n` +
    `- If the user trained hard yesterday, suggest a lighter session or different muscle group\n` +
    `- If no workouts this week, suggest a full-body session\n` +
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
