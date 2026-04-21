// ─── API Response Envelope ───────────────────────────────────────────────────

export interface ApiSuccess<T> {
  success: true;
  data: T;
  meta?: {
    page?: number;
    total?: number;
    cursor?: string;
  };
}

export interface ApiError {
  success: false;
  error: {
    code: string;
    message: string;
    details?: unknown;
  };
}

export type ApiResponse<T> = ApiSuccess<T> | ApiError;

// ─── Auth ─────────────────────────────────────────────────────────────────────

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
}

export interface AuthResponse extends AuthTokens {
  user: UserDto;
}

// ─── User ─────────────────────────────────────────────────────────────────────

export type FitnessGoal = 'lose_weight' | 'build_muscle' | 'maintain' | 'endurance';
export type ActivityLevel = 'sedentary' | 'light' | 'moderate' | 'active' | 'very_active';
export type SubscriptionTier = 'free' | 'pro' | 'coach';

export interface UserDto {
  id: string;
  email: string;
  name: string;
  avatarUrl: string | null;
  dateOfBirth: string | null;
  gender: string | null;
  heightCm: number | null;
  hasProfile: boolean;
  createdAt: string;
}

export interface UserProfileDto {
  fitnessGoal: FitnessGoal;
  activityLevel: ActivityLevel;
  targetWeightKg: number | null;
  tdee: number | null;
  currentWeightKg: number | null;
  heightCm: number | null;
}

// ─── Nutrition ────────────────────────────────────────────────────────────────

export type MealType = 'breakfast' | 'lunch' | 'dinner' | 'snack';

export interface FoodLogDto {
  id: string;
  foodId: string;
  foodName: string;
  mealType: MealType;
  servingG: number;
  calories: number;
  proteinG: number;
  carbsG: number;
  fatG: number;
  fiberG: number | null;
  loggedAt: string;
}

export interface DailyNutritionSummary {
  date: string;
  totalCalories: number;
  totalProteinG: number;
  totalCarbsG: number;
  totalFatG: number;
  calorieTarget: number;
  logs: FoodLogDto[];
}

// ─── Workout ──────────────────────────────────────────────────────────────────

export interface ExerciseSetDto {
  id: string;
  exerciseId: string;
  exerciseName: string;
  setNumber: number;
  reps: number | null;
  weightKg: number | null;
  durationSec: number | null;
  distanceM: number | null;
  rpe: number | null;
}

export interface WorkoutLogDto {
  id: string;
  name: string;
  startedAt: string;
  finishedAt: string | null;
  durationMin: number | null;
  caloriesBurned: number | null;
  notes: string | null;
  sets: ExerciseSetDto[];
}

// ─── Body Stats ───────────────────────────────────────────────────────────────

export interface BodyStatDto {
  id: string;
  weightKg: number | null;
  bodyFatPct: number | null;
  muscleMassKg: number | null;
  bmi: number | null;
  measuredAt: string;
}

// ─── AI Coach ────────────────────────────────────────────────────────────────

export interface CoachMessage {
  role: 'user' | 'assistant';
  content: string;
  timestamp: string;
}

export interface CoachContext {
  user: { name: string; fitnessGoal: FitnessGoal; tdee: number };
  today: {
    caloriesLogged: number;
    calorieTarget: number;
    workoutDone: boolean;
    steps: number;
  };
  weekSummary: {
    workoutsCompleted: number;
    avgCalories: number;
    weightChange: number;
  };
}

export interface CoachResponse {
  message: string;
  messagesRemainingToday: number | null; // null = unlimited (pro/coach tier)
}
