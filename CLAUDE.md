# CLAUDE.md — Zenfit Fitness App

> This file is Claude Code's memory for this project. Read it fully at the start of every session before writing any code. Update PROGRESS.md after every session.

---

## Project overview

**App name:** Zenfit
**Type:** Cross-platform mobile fitness app (iOS + Android)
**Solo developer:** Yes — one person building this with Claude Code assistance
**Goal:** A comprehensive fitness app covering calorie tracking, workout logging, AI coaching, wearable integration, mental wellness, and social features.
**Current status:** See `PROGRESS.md` for latest state.

---

## Tech stack (locked — do not suggest alternatives)

### Mobile (Flutter)
- **Framework:** Flutter 3.22+
- **Language:** Dart 3.4+ (sound null safety, no dynamic types allowed)
- **Navigation:** GoRouter 14+ (declarative, deep-link ready)
- **State management:** Riverpod 2+ (AsyncNotifier for server state, Notifier for local state)
- **Animations:** flutter_animate (declarative animations), fl_chart (charts/graphs)
- **Styling:** Flutter ThemeData + custom design system (colors, typography, spacing in theme/)
- **Local DB:** Drift 2+ (offline-first SQLite ORM, reactive queries, syncs to backend)
- **Secure storage:** flutter_secure_storage (tokens), shared_preferences (fast key-value)
- **Forms:** flutter_form_builder + manual Dart validation classes

### Backend (Node.js)
- **Runtime:** Node.js 20 LTS
- **Framework:** Fastify v4
- **Language:** TypeScript
- **ORM:** Prisma v5 with PostgreSQL
- **Cache:** Redis (ioredis)
- **Job queue:** BullMQ (background sync, report generation)
- **Real-time:** Socket.io (live workout sessions, social feed)
- **Auth:** JWT access tokens (15min) + refresh tokens (30 days), stored in flutter_secure_storage
- **File storage:** Cloudinary (images, exercise videos)

### AI / ML
- **LLM:** Google Gemini API (`gemini-2.0-flash`) for coach chatbot, meal plans, workout adaptation
- **Pose detection:** Google ML Kit (on-device, for form analysis)
- **Food recognition:** Google ML Kit Vision (food photo logging)
- **Embeddings:** OpenAI text-embedding-3-small + Pinecone (personalization vectors)

### Infrastructure
- **Hosting:** AWS (ECS Fargate for API, RDS PostgreSQL, ElastiCache Redis)
- **CDN:** CloudFront + S3 for media assets
- **CI/CD:** GitHub Actions → Fastlane (mobile builds) + Docker deploy (backend)
- **OTA updates:** Firebase App Distribution (beta), App Store / Play Store (production)
- **Monitoring:** Sentry (errors), Amplitude (analytics)
- **Payments:** Stripe (subscriptions)
- **Push notifications:** firebase_messaging (Flutter FCM plugin)

### Third-party APIs
- **Food database:** Open Food Facts API (free, 2M+ products) + USDA FoodData Central
- **Barcode scanning:** mobile_scanner (Flutter barcode/QR plugin)
- **Apple Health:** health (Flutter plugin — bridges HealthKit on iOS, Google Fit on Android)
- **Google Fit:** health (same plugin, unified interface for both platforms)
- **Wearables:** Garmin Connect IQ SDK, Fitbit Web API, WHOOP API, Oura API
- **HTTP client:** Dio 5+ (interceptors for auth token injection and refresh)

---

## Folder structure

```
zenfit/
├── apps/
│   ├── mobile/                    # Flutter app
│   │   ├── lib/
│   │   │   ├── main.dart          # App entry point
│   │   │   ├── app.dart           # MaterialApp + GoRouter setup
│   │   │   ├── router/            # GoRouter route definitions
│   │   │   │   └── app_router.dart
│   │   │   ├── features/          # One folder per feature (vertical slices)
│   │   │   │   ├── auth/
│   │   │   │   │   ├── screens/   # LoginScreen, SignupScreen, ForgotPasswordScreen
│   │   │   │   │   ├── widgets/   # AuthButton, EmailField, PasswordField
│   │   │   │   │   ├── providers/ # authProvider, authStateProvider (Riverpod)
│   │   │   │   │   └── models/    # AuthState, LoginRequest, SignupRequest
│   │   │   │   ├── onboarding/
│   │   │   │   │   ├── screens/   # GoalSelectionScreen, BodyStatsScreen, ActivityScreen
│   │   │   │   │   ├── widgets/
│   │   │   │   │   └── providers/
│   │   │   │   ├── home/          # Dashboard
│   │   │   │   │   ├── screens/
│   │   │   │   │   ├── widgets/   # CalorieRing, MacroBar, StepCounter, StreakCard
│   │   │   │   │   └── providers/
│   │   │   │   ├── nutrition/     # Food logging, meals
│   │   │   │   │   ├── screens/   # NutritionScreen, FoodSearchScreen, BarcodeScreen
│   │   │   │   │   ├── widgets/   # FoodCard, MacroBar, MealLogger, ServingInput
│   │   │   │   │   └── providers/
│   │   │   │   ├── workout/       # Workout tracking
│   │   │   │   │   ├── screens/   # WorkoutScreen, ExercisePickerScreen, ActiveWorkoutScreen
│   │   │   │   │   ├── widgets/   # ExerciseCard, SetLogger, RestTimer
│   │   │   │   │   └── providers/
│   │   │   │   ├── progress/      # Charts, body stats
│   │   │   │   │   ├── screens/
│   │   │   │   │   ├── widgets/   # CalorieChart, StrengthCurve, MuscleHeatMap
│   │   │   │   │   └── providers/
│   │   │   │   ├── social/        # Friends, challenges
│   │   │   │   │   ├── screens/
│   │   │   │   │   ├── widgets/   # FeedCard, ChallengeCard, LeaderBoard
│   │   │   │   │   └── providers/
│   │   │   │   ├── coach/         # AI coach chat
│   │   │   │   │   ├── screens/
│   │   │   │   │   ├── widgets/
│   │   │   │   │   └── providers/
│   │   │   │   ├── wellness/      # Sleep, meditation, mood
│   │   │   │   │   ├── screens/
│   │   │   │   │   ├── widgets/
│   │   │   │   │   └── providers/
│   │   │   │   └── settings/      # Profile, subscription, integrations
│   │   │   │       ├── screens/
│   │   │   │       └── providers/
│   │   │   ├── core/              # Shared across features
│   │   │   │   ├── api/           # Dio client, interceptors, API service base
│   │   │   │   │   ├── api_client.dart       # Dio instance with auth interceptor
│   │   │   │   │   └── api_response.dart     # Typed response envelope
│   │   │   │   ├── db/            # Drift database, DAOs, table definitions
│   │   │   │   │   ├── app_database.dart
│   │   │   │   │   └── daos/
│   │   │   │   ├── services/      # HealthService, NotificationService
│   │   │   │   │   ├── health_service.dart   # Apple Health + Google Fit
│   │   │   │   │   └── coach_service.dart    # AI coach API calls
│   │   │   │   ├── theme/         # AppTheme, colors, typography, spacing
│   │   │   │   │   ├── app_theme.dart
│   │   │   │   │   ├── app_colors.dart
│   │   │   │   │   └── app_text_styles.dart
│   │   │   │   ├── widgets/       # Shared UI: AppButton, AppCard, AppInput, AppModal
│   │   │   │   └── utils/         # Calorie calc, macro utils, date helpers, formatters
│   │   │   └── constants/         # API URLs, exercise list, enums
│   │   ├── test/                  # Unit + widget tests
│   │   │   ├── features/
│   │   │   └── core/utils/        # Calorie, macro, streak logic tests
│   │   ├── android/
│   │   ├── ios/
│   │   └── pubspec.yaml           # All Flutter dependencies declared here
│   │
│   └── backend/                   # Fastify API (unchanged)
│       ├── src/
│       │   ├── routes/            # One file per feature domain
│       │   │   ├── auth.routes.ts
│       │   │   ├── nutrition.routes.ts
│       │   │   ├── workout.routes.ts
│       │   │   ├── user.routes.ts
│       │   │   ├── ai.routes.ts
│       │   │   └── social.routes.ts
│       │   ├── services/          # Business logic (no DB calls here)
│       │   ├── repositories/      # All Prisma DB queries live here
│       │   ├── jobs/              # BullMQ job handlers
│       │   ├── plugins/           # Fastify plugins (auth, redis, socket)
│       │   ├── middleware/        # Rate limiting, validation
│       │   └── utils/             # Shared helpers
│       └── prisma/
│           ├── schema.prisma      # Source of truth for DB schema
│           └── migrations/
│
├── packages/
│   └── shared/                    # Shared API contract documentation
│       └── types/                 # DTOs and response shapes (for reference — Dart models mirror these)
│
├── CLAUDE.md                      # This file — Claude Code's memory
├── PROGRESS.md                    # Session-by-session build log
├── DECISIONS.md                   # Architecture decisions with reasoning
└── README.md
```

---

## Database schema (Prisma — core models)

```prisma
model User {
  id            String   @id @default(cuid())
  email         String   @unique
  name          String
  avatarUrl     String?
  dateOfBirth   DateTime?
  gender        String?
  heightCm      Float?
  createdAt     DateTime @default(now())

  profile       UserProfile?
  foodLogs      FoodLog[]
  workoutLogs   WorkoutLog[]
  bodyStats     BodyStat[]
  goals         Goal[]
  friendships   Friendship[] @relation("UserFriendships")
  subscription  Subscription?
}

model UserProfile {
  id               String  @id @default(cuid())
  userId           String  @unique
  fitnessGoal      String  // lose_weight | build_muscle | maintain | endurance
  activityLevel    String  // sedentary | light | moderate | active | very_active
  targetWeightKg   Float?
  tdee             Int?    // calculated total daily energy expenditure
  user             User    @relation(fields: [userId], references: [id])
}

model FoodLog {
  id          String   @id @default(cuid())
  userId      String
  foodId      String   // references food database
  foodName    String
  mealType    String   // breakfast | lunch | dinner | snack
  servingG    Float
  calories    Float
  proteinG    Float
  carbsG      Float
  fatG        Float
  fiberG      Float?
  loggedAt    DateTime @default(now())
  user        User     @relation(fields: [userId], references: [id])
}

model WorkoutLog {
  id          String       @id @default(cuid())
  userId      String
  name        String
  startedAt   DateTime
  finishedAt  DateTime?
  durationMin Int?
  caloriesBurned Int?
  notes       String?
  user        User         @relation(fields: [userId], references: [id])
  sets        ExerciseSet[]
}

model ExerciseSet {
  id            String     @id @default(cuid())
  workoutLogId  String
  exerciseId    String
  exerciseName  String
  setNumber     Int
  reps          Int?
  weightKg      Float?
  durationSec   Int?       // for time-based exercises
  distanceM     Float?     // for cardio
  rpe           Int?       // rate of perceived exertion 1-10
  workoutLog    WorkoutLog @relation(fields: [workoutLogId], references: [id])
}

model BodyStat {
  id          String   @id @default(cuid())
  userId      String
  weightKg    Float?
  bodyFatPct  Float?
  muscleMassKg Float?
  bmi         Float?
  measuredAt  DateTime @default(now())
  user        User     @relation(fields: [userId], references: [id])
}

model Goal {
  id          String   @id @default(cuid())
  userId      String
  type        String   // daily_calories | weekly_workouts | steps | weight_target
  targetValue Float
  currentValue Float   @default(0)
  deadline    DateTime?
  completed   Boolean  @default(false)
  user        User     @relation(fields: [userId], references: [id])
}

model Subscription {
  id         String   @id @default(cuid())
  userId     String   @unique
  tier       String   // free | pro | coach
  stripeId   String?
  validUntil DateTime?
  user       User     @relation(fields: [userId], references: [id])
}

model Friendship {
  id          String  @id @default(cuid())
  userId      String
  friendId    String
  status      String  // pending | accepted
  user        User    @relation("UserFriendships", fields: [userId], references: [id])
}
```

---

## Core business logic rules

### Calorie calculations
- **TDEE formula:** Mifflin-St Jeor BMR × activity multiplier
  - BMR (male) = (10 × weightKg) + (6.25 × heightCm) − (5 × age) + 5
  - BMR (female) = (10 × weightKg) + (6.25 × heightCm) − (5 × age) − 161
  - Activity multipliers: sedentary 1.2 | light 1.375 | moderate 1.55 | active 1.725 | very active 1.9
- **Goal adjustment:** weight loss = TDEE − 500 kcal | muscle gain = TDEE + 300 kcal | maintain = TDEE
- **Post-workout recalculation:** re-run TDEE after logging workout, add burned calories to daily budget

### Macro split defaults
- Weight loss: 40% protein, 30% carbs, 30% fat
- Muscle gain: 30% protein, 50% carbs, 20% fat
- Maintenance: 30% protein, 40% carbs, 30% fat
- Always calculate in grams: protein/carbs = 4 kcal/g, fat = 9 kcal/g

### Workout volume tracking
- Track weekly sets per muscle group (chest, back, shoulders, arms, legs, core)
- Minimum effective volume: 10 sets/week per muscle group
- Maximum recoverable volume: 20 sets/week per muscle group
- Flag overtraining or undertraining in the AI coach's weekly summary

### Streak logic
- Streak increments if user logs at least one of: a food log, a workout, OR hits 7500+ steps for the day
- Streak resets at midnight local time if none of the above
- Grace period: one missed day allowed per 7-day window (shows "streak shield" in UI)

---

## API design conventions

### Base URL structure
```
/api/v1/auth/*         — login, signup, refresh, logout
/api/v1/user/*         — profile, settings, stats
/api/v1/nutrition/*    — food logs, food search, meal plans
/api/v1/workout/*      — workout logs, exercise library, templates
/api/v1/body/*         — body stats, progress photos
/api/v1/ai/*           — coach chat, meal suggestions, workout adaptation
/api/v1/social/*       — friends, challenges, feed
/api/v1/integrations/* — Apple Health, Google Fit, wearables
```

### Response envelope (always use this shape)
```typescript
// Success
{ success: true, data: T, meta?: { page, total, cursor } }

// Error
{ success: false, error: { code: string, message: string, details?: unknown } }
```

### Auth flow
- POST `/api/v1/auth/signup` → returns `{ accessToken, refreshToken, user }`
- POST `/api/v1/auth/login` → same
- POST `/api/v1/auth/refresh` → `{ accessToken }` (send refreshToken in body)
- Access token in `Authorization: Bearer <token>` header on every request
- Refresh token stored in SecureStore on device, never in memory

---

## Feature status tracker

Update this table as features are completed. Use: `[ ]` todo, `[~]` in progress, `[x]` done.

### Phase 1 — MVP Core
- [x] Project setup (monorepo, Flutter app, Fastify, Prisma, PostgreSQL) — backend + Flutter scaffold done; Drift DB + sync DAO scaffolded; FCM configured for Android (`google-services.json` placed, Google Services plugin wired in Gradle); **GCP Cloud Run production deployment live at https://zenfit-api-122167595419.us-central1.run.app**; Cloud Build CI/CD on push to main; Cloud SQL PostgreSQL 15 (zenfit-db, us-central1); Upstash Redis; 12 secrets in Secret Manager
- [x] Auth screens (signup, login, forgot password)
- [x] Onboarding flow (goal selection, body stats, activity level)
- [x] Tab navigation shell (Home, Nutrition, Workout, Progress, Wellness) — 5-tab bottom nav; Social moved to AppBar icon (people_outline); avatar leading button on HomeScreen → ProfileScreen; ProfileScreen replaces SettingsScreen with card-grouped UI (Notifications, Wearable, Subscription, Logout); PopScope in MainShell: back on any non-Home tab goes to /home, back on Home exits app
- [x] Light / dark / auto theme system — `AppTheme.light` + `AppTheme.dark`; `ThemePreference` enum (auto/light/dark) persisted in SharedPreferences; `effectiveThemeModeProvider` auto-switches at 6 AM (light) / 6 PM (dark) via a boundary Timer; 400ms animated crossfade (`themeAnimationDuration`); toggle in Profile → Appearance via `SegmentedButton`; all 209 hardcoded neutral `AppColors.*` references replaced with `Theme.of(context).colorScheme.*` for full light-mode text visibility
- [x] Food search + logging (Open Food Facts API + USDA + Indian food database) — three parallel searches; Indian results surface first; 150-item curated Indian food database bundled as `assets/data/indian_foods.json`; serving-chip quick-select in log sheet for Indian foods; NutritionScreen meal sections redesigned as tappable `MealCard` widgets (emoji + kcal header + `+` button; empty placeholder; collapsed horizontal `FoodChip` scroll + "See all" toggle; expanded full list with swipe-to-delete; flutter_animate entry animations; `mealType` passed via GoRouter `extra` to pre-select meal in `LogFoodSheet`)
- [x] Barcode scanner
- [x] Macro/calorie dashboard for the day
- [x] Basic workout logger (exercise picker, set/rep/weight input)
- [x] Rest timer
- [x] Workout history list
- [x] Body weight logging
- [x] Home dashboard (calorie ring, steps, water, streak) — personalised targets fixed: TDEE now correctly parsed from nested `profile` key in API response (was always falling back to 2000); step goal personalised by activity level (sedentary 7k → very_active 15k) + fitness goal (+2k lose_weight, +3k endurance, 0 build_muscle); water target = `weightKg × 30–40 ml/kg` by activity level, rounded to 50 ml, clamped 1,500–5,000 ml; `/user/profile` endpoint now returns `currentWeightKg` (latest BodyStat) and `heightCm`; all SharedPreferences keys now scoped by userId (streak, water, burned kcal, meal plan cache) — data can no longer leak between accounts on the same device; `homeProvider` and `mealPlanProvider` watch `authProvider` and rebuild on login/logout/account switch

### Phase 2 — Integrations & Analytics
- [x] Apple HealthKit sync — steps, HR, sleep, weight read; workout energy write; one-time permissions prompt
- [x] Google Fit sync — same health plugin, same code path
- [x] Step counting (native pedometer) — live via getTodaySteps() → home dashboard
- [x] GPS workout tracking (running/cycling) — GpsService, outdoor mode toggle (all exercises), live pace/distance bar, route map on summary
- [x] Calories burned estimation — outdoor: distance × MET × weight (kOutdoorKcalPerKgPerKm); indoor fallback: time × MET × weight
- [x] Progress charts (weight trend, calorie trend, strength curve)
- [x] Muscle group volume heat map
- [x] Sleep tracking display (from wearable) — full Wellness screen: sleep card, stages bar, 7-day trend, sleep score, HR card + zone, mood logger (1-5 emoji + 14-day trend), readiness ring
- [x] Offline mode (Drift sync queue)
- [x] Push notifications (reminders, streaks) — FCM token registration, local scheduled notifications (workout/food/streak), weekly summary BullMQ job

### Phase 3 — AI Features
- [x] AI coach chat (Gemini API integration) — upgraded to `gemini-2.5-flash`; rate limits removed entirely; greeting message injected on first open ("Hey {name}!"); RAG context cache (nutrition/workout/body, 15-min TTL) injected per message; multi-bubble display; silent 4s auto-retry on 503; all errors surface with Retry snackbar; suggestion chips + rate-limit banner removed; `isLocal` flag on ChatMessage keeps greeting out of backend history
- [x] Adaptive daily calorie target (post-workout adjustment) — `caloriesBurnedToday` persisted in SharedPreferences (daily key); `adaptiveTarget = tdee + caloriesBurnedToday` on `HomeDashboardState`; `WorkoutSessionNotifier.finishWorkout` calls `homeProvider.addBurnedCalories` on both online save and offline enqueue; calorie ring, macro bars, and target label all use `adaptiveTarget`; "+X kcal from workout" chip shown when burned > 0
- [x] AI meal plan generator (weekly) — Gemini JSON schema; 7-day plan; Pro/Coach gate; cached in SharedPreferences; expandable PlannedMealCard; paywall view for free tier
- [ ] Grocery list from meal plan
- [x] Food photo logging (Gemini Vision) — multimodal analysis; detects all items in mixed dishes; proportional macro scaling on serving edit; camera FAB on NutritionScreen; available all tiers
- [x] Workout recommendation engine — split into gym vs home; `GET /ai/workout-recommendation?type=gym|home`; gym prompt enforces equipment exercises, home prompt enforces bodyweight-only; `workoutRecommendationProvider` is a Riverpod family (WorkoutType.gym / .home) with keepAlive and manual-only generate(); new GymWorkoutScreen at `/workout/gym`; home recommendation section at top of HomeWorkoutListScreen; main WorkoutScreen navigates to each sub-screen instead of auto-fetching
- [x] Home workout page — 40 bodyweight/calisthenics exercises in kHomeExerciseLibrary; HomeWorkoutListScreen at /workout/home; category + difficulty filter chips; SetInputMode (repsOnly / durationOnly / repsAndWeight) on SetLogger; no weight input for bodyweight exercises
- [x] Recovery score (HRV + sleep + training load) — HRV (SDNN) fetched from HealthKit/Google Fit; formula: sleepScore×0.4 + hrComponent×0.3 + trainingLoad×0.3; HRV preferred over RHR when available (10–100ms → 0–100); falls back to resting HR; Wellness screen card renamed "Recovery Score"; 4-pill breakdown: Sleep · HRV · HR · Load
- [x] Deload week detection — pure algorithmic (no Gemini); 4-week set count analysis via getFourWeekWorkoutSummary; flags ≥3 consecutive weeks ≥40 sets or 4-week avg >60 sets; GET /ai/deload-check; DeloadBannerCard on WorkoutScreen (amber warning / green OK)
- [x] AI exercise form monitor — on-device real-time pose detection (google_mlkit_pose_detection ^0.13.0 + camera ^0.11.0); 9 supported exercises (squat, lunge, push-up, plank, deadlift, romanian deadlift, overhead press, bicep curl, pull-up); per-exercise joint-angle rules in PoseAnalyzer; green skeleton overlay = correct form, amber = correction cue text; simple rep counter via good-form streak detection; front/back camera toggle; NV21 on Android + correct (sensorOrientation ± deviceOrientation) % 360 rotation; no backend or API calls — fully on-device; entry point is "AI Form Monitor" card on WorkoutScreen → `/workout/monitor`

### Phase 4 — Social & Monetization
- [ ] User search + friend system
- [ ] Activity feed
- [ ] 30-day challenges
- [ ] Leaderboards
- [ ] XP + level system
- [ ] Badges & achievements
- [ ] Streak shields
- [x] Stripe subscription integration (Free / Pro / Coach tiers)
- [x] Paywall screens for premium features
- [ ] Coach marketplace (basic)
- [x] Ad placeholder slots (home screen banner + popup) — swap for AdWidget from google_mobile_ads before launch; TODO(admob) comments mark each slot

---

## Subscription tiers

| Feature | Free | Pro ($9.99/mo) | Coach ($19.99/mo) |
|---|---|---|---|
| Calorie & macro tracking | ✓ | ✓ | ✓ |
| Workout logging | ✓ | ✓ | ✓ |
| Basic progress charts | ✓ | ✓ | ✓ |
| AI coach chat | 5 msg/day | Unlimited | Unlimited |
| Adaptive meal plans | — | ✓ | ✓ |
| Advanced analytics | — | ✓ | ✓ |
| Wearable sync | Basic | Full | Full |
| Social & challenges | ✓ | ✓ | ✓ |
| Coach marketplace access | — | — | ✓ |
| Food photo logging | — | ✓ | ✓ |

---

## Coding rules (enforce strictly)

1. **Dart sound null safety always.** No `dynamic` types. Use proper generics and sealed classes.
2. **Keep files under 300 lines.** If a file grows beyond this, split it into sub-widgets or sub-services.
3. **One concern per file.** No mixing API calls + UI + business logic in one widget.
4. **All API calls go through `core/api/api_client.dart`.** Never use `http` or `Dio` directly in a feature widget.
5. **All DB queries go through Drift DAO files.** No raw SQL or direct table access in providers.
6. **Validate all API inputs on the backend with Zod.** Dart models handle deserialization with `fromJson` factories.
7. **Error handling is mandatory.** Every async method needs try/catch. Use `AsyncValue` from Riverpod to surface errors in UI.
8. **Environment variables** in `--dart-define` or `.env` via `flutter_dotenv`. Never hardcode secrets or API URLs.
9. **No `print()` in production code.** Use the `logger` package with log levels.
10. **Write tests for business logic.** At minimum: calorie calculation utils, macro utils, streak logic in `test/core/utils/`.

---

## Component architecture pattern

```dart
// Every feature follows this structure:
// 1. Riverpod provider (AsyncNotifier) handles server state + local UI state
// 2. Screen widget consumes the provider via ConsumerWidget
// 3. Sub-widgets are pure — they receive data and callbacks as constructor params only

// Example: NutritionScreen
// features/nutrition/screens/nutrition_screen.dart   ← ConsumerWidget, wires provider to UI
// features/nutrition/widgets/meal_logger.dart        ← StatelessWidget, no providers
// features/nutrition/widgets/food_card.dart          ← StatelessWidget, no providers
// features/nutrition/providers/nutrition_provider.dart ← AsyncNotifier, all API calls live here
// features/nutrition/models/food_log.dart            ← Dart model with fromJson/toJson

// Provider pattern (Riverpod AsyncNotifier):
// @riverpod
// class NutritionNotifier extends _$NutritionNotifier {
//   @override
//   Future<List<FoodLog>> build() => ref.read(apiClientProvider).getFoodLogs();
//   Future<void> logFood(FoodLog log) async { ... }
// }
```

---

## AI coach — Claude API integration

### System prompt (use this exactly)
```
You are Zenfit Coach, a knowledgeable and motivating fitness assistant. You have access to the user's fitness data including their goals, recent workouts, calorie logs, and body stats. Give concise, actionable advice. Always be encouraging but honest. Never recommend extreme diets or dangerous exercises. If the user describes symptoms that could indicate a medical issue, always recommend consulting a doctor. Keep responses under 200 words unless the user explicitly asks for more detail.
```

### Context to inject with every message
```dart
class CoachContext {
  final CoachUser user;        // name, fitnessGoal, tdee
  final CoachToday today;      // caloriesLogged, calorieTarget, workoutDone, steps
  final CoachWeekSummary week; // workoutsCompleted, avgCalories, weightChange
}
```

### Rate limiting
- Free tier: 5 messages/day per user (tracked in Redis with 24h TTL key `coach:limit:{userId}`)
- Pro/Coach tier: unlimited
- Always check subscription tier before calling Claude API

---

## Environment variables required

```bash
# Backend (.env)
DATABASE_URL=postgresql://...
REDIS_URL=redis://...
JWT_SECRET=
JWT_REFRESH_SECRET=
ANTHROPIC_API_KEY=
STRIPE_SECRET_KEY=
STRIPE_WEBHOOK_SECRET=
CLOUDINARY_URL=
OPEN_FOOD_FACTS_BASE_URL=https://world.openfoodfacts.org
USDA_API_KEY=
SENTRY_DSN=
AMPLITUDE_API_KEY=

# Mobile (pubspec.yaml + flutter_dotenv / --dart-define)
FLUTTER_API_URL=
FLUTTER_STRIPE_PUBLISHABLE_KEY=
FLUTTER_AMPLITUDE_KEY=
FLUTTER_SENTRY_DSN=
```

---

## Session startup checklist

At the beginning of every Claude Code session, do this in order:

1. Read `PROGRESS.md` to see what was last built and what's next
2. Read `DECISIONS.md` to recall any architectural decisions already made
3. Check the feature status table above — find the first `[ ]` item in the current phase
4. Ask: "What is the smallest vertical slice I can build and test today?"
5. Build that slice completely (route + provider + screen + widget + basic test)
6. Update `PROGRESS.md` and the feature status table before ending the session

---

## Common pitfalls to avoid

- **Do not use `SharedPreferences` for sensitive data.** Use `flutter_secure_storage` for tokens and anything private. `SharedPreferences` is only for non-sensitive settings.
- **Do not call the Claude API from the Flutter app directly.** All AI calls go through the backend `/api/v1/ai/*` routes so the API key is never exposed.
- **Do not store refresh tokens in Riverpod state.** Keep them in `flutter_secure_storage` only — Riverpod state can be inspected.
- **Do not skip Zod validation on the backend** even for internal routes.
- **Do not build social features before the core tracking loop is solid.** Core = food log + workout log + dashboard working end-to-end.
- **Do not use `dynamic` to escape Dart type errors.** Fix the types properly with proper generics or sealed classes.
- **Drift sync conflicts:** last-write-wins for user-generated data (logs). For settings/profile, server wins.
- **Do not call `setState` inside a `ConsumerWidget`.** Use Riverpod notifiers to update state — mixing setState and Riverpod causes unpredictable rebuilds.

---

## PROGRESS.md template (copy this to start)

```markdown
# Zenfit — Build Progress

## Last session
**Date:** YYYY-MM-DD
**Duration:** X hours
**What was built:**
- ...

**Decisions made:**
- ...

**What's broken / known issues:**
- ...

## Next session
**Priority task:**
**Files to look at first:**

## Session history
| Date | Built | Phase |
|---|---|---|
```

---

## DECISIONS.md template (copy this to start)

```markdown
# Architecture Decisions

## ADR-001: Flutter over React Native
**Date:** ...
**Decision:** Use Flutter 3.22+ with Dart for the mobile app
**Reason:** More opinionated structure keeps Claude Code focused; Dart's strong typing reduces ambiguity; Flutter renders its own pixels so iOS/Android behavior is identical; faster hot reload in practice for solo dev
**Trade-off:** Smaller plugin ecosystem than React Native for some niche integrations

## ADR-002: GoRouter over Navigator 2.0 directly
**Date:** ...
**Decision:** Use GoRouter for navigation
**Reason:** Declarative, deep-link ready out of the box, integrates cleanly with Riverpod auth state for redirect logic
**Trade-off:** Extra dependency, but it's the Flutter team's recommended solution

## ADR-003: Drift over Hive or Isar for local DB
**Date:** ...
**Decision:** Use Drift for local SQLite storage
**Reason:** Type-safe SQL with code generation, reactive streams, built-in migration system, offline-first by design
**Trade-off:** More setup boilerplate than Hive, but far more powerful for relational fitness data

## graphify: Knowledge graph exists
- Read GRAPH_REPORT.md for god nodes and community structure before searching raw files.

# Instructions
- Be concise. Avoid long summaries or explanations.
- Only explain what's necessary — skip preamble and post-amble.
- Prefer short responses unless asked for detail.
ef  

(add new decisions here as you make them)
```