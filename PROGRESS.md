# FitCore — Build Progress

## Last session
**Date:** 2026-04-14 (session 15)
**What was built:**

### Railway production deployment + sign-in bug fixes

**Infrastructure:**
- `railway.toml` at repo root — Dockerfile builder, health check path `/health`, restart policy
- `apps/backend/Dockerfile` — two-stage Yarn workspace build (Node 20 slim); production image preserves monorepo structure so hoisted node_modules resolve correctly; `CMD` runs `prisma migrate deploy` before starting the server
- `.github/workflows/deploy-backend.yml` — typecheck + Railway webhook redeploy on push to `main` touching `apps/backend/**`
- `GET /health` updated to return `{ status: 'ok', timestamp: Date.now() }`

**Flutter per-environment API URL:**
- `apps/mobile/lib/constants/app_constants.dart` — `AppConstants.apiBaseUrl` uses `String.fromEnvironment('FLUTTER_API_URL')`; falls back to `http://localhost:3000` in debug, `https://fitcore-production-c558.up.railway.app` in release (`dart.vm.product` compile-time constant)
- `api_client.dart` and `auth_provider.dart` updated to use `AppConstants.apiBaseUrl` as dotenv fallback

**Sign-in bug fixes (3 separate root causes, found in sequence):**
1. `auth_provider.dart` still hardcoded `http://localhost:3000` — all auth requests went to localhost on device
2. `apps/mobile/.env` had `FLUTTER_API_URL=http://192.168.1.5:3000` bundled as a Flutter asset — overrode `AppConstants` in every build including release; removed the value, left a comment explaining the pattern
3. `User.fcmToken` column existed in `schema.prisma` but had no migration — `PrismaClientInitializationError` on every user query; created `20260414000000_add_fcm_token` migration

**Railway debugging:**
- Initial deploy failed: Dockerfile used `npm ci` but project uses Yarn workspaces — rewrote to `yarn install --frozen-lockfile` from monorepo root
- `railway.toml` was in `apps/backend/` — Railway reads it from repo root only; moved
- `prisma migrate deploy` in `railway.toml` startCommand was silently ignored — moved into Dockerfile `CMD` to guarantee it runs
- `DATABASE_URL` was set to `localhost:5432` placeholder — fixed by linking Railway PostgreSQL service via `${{Postgres.DATABASE_URL}}`

**Decisions made:**
- `prisma migrate deploy` lives in Dockerfile `CMD` (not `railway.toml` startCommand) — Railway was ignoring the startCommand override; CMD is always executed
- `.env` file stays gitignored and should never contain `FLUTTER_API_URL` — `AppConstants` handles the per-environment default; developers override locally if testing against a LAN backend
- `railway.toml` startCommand kept as a belt-and-suspenders duplicate in case Railway starts honouring it in future

**Known issues:**
- `RAILWAY_DEPLOY_WEBHOOK_URL` GitHub Actions secret not yet set — auto-deploy via webhook not wired; Railway must be redeployed manually from the dashboard for now
- Redis not provisioned on Railway — weekly summary push notifications disabled; BullMQ jobs won't run until Redis is added as a Railway service
- `settings_screen.dart` still orphaned (no route points to it)
- iOS push notifications still deferred

## Next session
**Priority task:** Phase 3 — AI coach chat (Claude API integration)

1. **Backend** — implement `POST /api/v1/ai/chat` in `ai.routes.ts`:
   - Query `CoachContext` (user profile, today's food logs, today's workout, step count) from DB
   - Call `claude-sonnet-4-6` via `@anthropic-ai/sdk` with the FitCore Coach system prompt from CLAUDE.md
   - Enforce 5 msg/day Redis rate limit for free tier (key: `coach:limit:{userId}`, 24h TTL) — skip gracefully if Redis unavailable
   - Return `{ success: true, data: { reply: string, messagesUsedToday: number } }`

2. **Flutter** — build out `coach_screen.dart`:
   - Scrollable message list (user bubbles right, coach bubbles left)
   - Text input bar with send button + loading indicator
   - Rate-limit banner for free users showing `X / 5 messages used today`
   - `coach_provider.dart` (`AsyncNotifier<List<ChatMessage>>`) — stores session history in memory

**Files to look at first:**
- `apps/backend/src/routes/ai.routes.ts` — stub to implement
- `apps/mobile/lib/features/coach/screens/coach_screen.dart` — placeholder to build out
- `apps/backend/src/repositories/` — create `coach.repository.ts` for CoachContext DB queries

---

## Previous session
**Date:** 2026-04-14 (session 14)
**What was built:**

### Navigation restructure + ProfileScreen

**Bottom nav (main_shell.dart + app_router.dart):**
- Removed Social from bottom nav — now 5 tabs: Home, Nutrition, Workout, Progress, Wellness
- Social and its sub-routes (friend-search, challenges, leaderboard) moved outside `ShellRoute` so they push as full-screen pages with a back arrow
- Wellness route moved back inside `ShellRoute` (had been incorrectly placed outside it)

**HomeScreen AppBar (home_screen.dart):**
- Added `leading` CircleAvatar showing the user's name initial — taps to `/profile`
- Replaced settings gear icon in `actions` with `Icons.people_outline` — taps to `/social`

**ProfileScreen (features/settings/screens/profile_screen.dart — new file):**
- Centred avatar header (radius 40) with name + email stacked below
- Card-based grouped layout — no `Divider` lines between sections; each group (`Settings`, `Account`) is a `ClipRRect` + `Material(color: surfaceVariant)` rounded card (radius 14)
- Settings group: Notifications (→ `/profile/notifications`), Wearable Integrations (placeholder snackbar), Subscription (placeholder snackbar)
- Account group: Log Out with confirmation dialog
- Subtle intra-card separators (30% opacity, indented) — visible only between items within the same card

**Router + routes (app_router.dart, app_routes.dart):**
- `/settings` route removed; replaced with `/profile` → `ProfileScreen`
- `notificationPrefs` constant updated from `/settings/notifications` → `/profile/notifications`
- `notification-prefs` GoRoute moved under `/profile` as a sub-route
- Old `SettingsScreen` import removed from router

**Build fix:**
- `main_shell.dart` was referencing `syncQueueServiceProvider` which doesn't exist — the actual provider exported from `sync_queue_service.dart` is `syncServiceProvider`. Fixed import + renamed reference.

**Device:**
- Debug APK built and installed on CPH2401 (Android 14, wireless ADB) via `adb install -r`

**Decisions made:**
- Social is accessed via AppBar push (not a tab) — keeps bottom nav focused on primary tracking loops; Social is a Phase 4 feature and shouldn't compete for prime nav real estate
- ProfileScreen replaces SettingsScreen entirely — `settings_screen.dart` still exists in the codebase but is no longer routed to; safe to delete in a future cleanup pass
- Card-grouped UI (iOS Settings style) chosen over `Divider`-separated `ListView` — fits the dark theme better and provides clearer visual chunking per section

**Known issues:**
- `settings_screen.dart` is orphaned (no route points to it) — can be deleted whenever convenient
- Wearable Integrations and Subscription tiles in ProfileScreen show "Coming soon" snackbars — real screens are Phase 4 work
- `app_database.g.dart` still requires codegen on first clone: `flutter pub run build_runner build --delete-conflicting-outputs`
- Weekly summary push disabled until Redis (Memurai) is installed
- iOS push notifications deferred — requires Mac/Xcode or Codemagic

## Next session
**Priority task:** Phase 3 — AI coach chat (Claude API integration).

1. **Backend** — implement `POST /api/v1/ai/chat` in `ai.routes.ts`:
   - Query `CoachContext` (user profile, today's food logs, today's workout, step count) from DB
   - Call `claude-sonnet-4-6` via `@anthropic-ai/sdk` with the FitCore Coach system prompt from CLAUDE.md
   - Enforce 5 msg/day Redis rate limit for free tier (key: `coach:limit:{userId}`, 24h TTL) — skip gracefully if Redis unavailable
   - Return `{ success: true, data: { reply: string, messagesUsedToday: number } }`

2. **Flutter** — build out `coach_screen.dart`:
   - Scrollable message list (user bubbles right, coach bubbles left)
   - Text input bar with send button + loading indicator
   - Rate-limit banner for free users showing `X / 5 messages used today`
   - `coach_provider.dart` (`AsyncNotifier<List<ChatMessage>>`) — stores session history in memory

**Files to look at first:**
- `apps/backend/src/routes/ai.routes.ts` — stub to implement
- `features/coach/screens/coach_screen.dart` — placeholder to build out
- `apps/backend/src/repositories/` — create `coach.repository.ts` for CoachContext DB queries

---

## Previous session
**Date:** 2026-04-13 (session 13)
**What was built:**

### Push Notifications — Android fully shipped, iOS code prepared

This session completed everything needed to ship push notifications on Android and resolved all build/runtime errors discovered during device testing.

**Android build fixes:**
- `NotificationPreferencesNotifier.update()` renamed to `save()` — clashed with Riverpod's built-in `AsyncNotifier.update()` signature.
- `zonedSchedule()` missing required `uiLocalNotificationDateInterpretation` parameter — added `UILocalNotificationDateInterpretation.absoluteTime` to all 3 scheduled notification calls.
- `flutter_local_notifications` requires core library desugaring — added `isCoreLibraryDesugaringEnabled = true` and `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")` to `android/app/build.gradle.kts`.
- Google Services plugin missing from Gradle — declared `id("com.google.gms.google-services") version "4.4.2" apply false` in `settings.gradle.kts` and applied in `app/build.gradle.kts`.
- `google-services.json` downloaded with `(1)` suffix — renamed to correct filename.
- Package name mismatch: Firebase registered app as `com.fitcore.app` but Gradle `namespace` was `com.fitcore.fitcore` — fixed by keeping `namespace = "com.fitcore.fitcore"` (matches `MainActivity.kt` folder path) and setting only `applicationId = "com.fitcore.app"` (matches Firebase/`google-services.json`). Changing `namespace` broke `MainActivity` class lookup → app crashed with `ClassNotFoundException`.

**Firebase / backend:**
- `FIREBASE_SERVICE_ACCOUNT` populated in `.env` with real service account JSON — Firebase Admin SDK now active on the backend.
- Ran `prisma db push` — `fcmToken String?` column applied to the DB.
- Ran `prisma generate` (required stopping backend first on Windows due to DLL file lock — killed all `node.exe` processes with `taskkill //F //IM node.exe`).
- Backend restarted cleanly.

**Redis / BullMQ graceful degradation:**
- Redis is not installed on this machine — BullMQ worker was flooding console with `ECONNREFUSED` errors on every retry.
- Fixed `weekly_summary.job.ts`: added `lazyConnect: true`, `retryStrategy: () => null`, `enableOfflineQueue: false`, and a once-only error logger. `scheduleWeeklySummaryJob()` and `startWeeklySummaryWorker()` now catch connection failures and log a single warning then skip — API continues running normally without Redis.
- Weekly push notifications will activate automatically when Redis is installed (Memurai recommended for Windows).

**iOS code preparation (Xcode not available on Windows — deferred):**
- `apps/mobile/ios/Runner/AppDelegate.swift` — added `import FirebaseCore` and `FirebaseApp.configure()` call.
- `apps/mobile/ios/Runner/Info.plist` — added `UIBackgroundModes` (`fetch`, `remote-notification`).
- Remaining iOS steps deferred to when a Mac / Codemagic is available: add `GoogleService-Info.plist` via Xcode, enable Push Notifications + Background Modes capabilities, upload APNs key to Firebase Console.

**APK built and installed:**
- `flutter build apk --release` → 137.9 MB — clean build, no errors.
- `flutter install --release --uninstall-only` + `flutter install --release` — old app removed, fresh install on CPH2401 (Android 14).
- App confirmed launching (`Impeller Vulkan` renderer active, Health Connect permissions live).

**Decisions made:**
- `namespace` ≠ `applicationId` in Android Gradle: `namespace` must match the Kotlin package folder structure; `applicationId` is the Firebase/Play Store identity. They can differ and often should.
- Redis not a hard dependency — BullMQ job degrades gracefully. All core API features (auth, nutrition, workout, wellness) work without Redis.
- iOS push deferred: no Xcode on Windows; recommended path is Codemagic CI/CD (free tier, 500 min/month) or a cloud Mac rental. All Dart-side code is already correct for iOS.

**What's broken / known issues:**
- FCM token `POST /api/v1/user/fcm-token` returns 500 if backend was started before `prisma generate` ran — resolved in this session; backend now has correct schema.
- Weekly summary push disabled until Redis is running. Install **Memurai** (Redis for Windows) to enable.
- iOS push notifications fully deferred — requires Mac with Xcode or Codemagic for `GoogleService-Info.plist` placement + Push Notifications capability.

## Next session
**Priority task:** Phase 3 — AI coach chat (Claude API integration).

1. **Backend** — implement `POST /api/v1/ai/chat` in `ai.routes.ts`:
   - Query `CoachContext` (user profile, today's food logs, today's workout, step count) from DB
   - Call `claude-sonnet-4-6` via `@anthropic-ai/sdk` with the FitCore Coach system prompt from CLAUDE.md
   - Enforce 5 msg/day Redis rate limit for free tier (key: `coach:limit:{userId}`, 24h TTL) — skip if Redis unavailable
   - Return `{ success: true, data: { reply: string, messagesUsedToday: number } }`

2. **Flutter** — build out `coach_screen.dart`:
   - Scrollable message list (user bubbles right, coach bubbles left)
   - Text input bar with send button + loading indicator while waiting for response
   - Rate-limit banner for free users showing `X / 5 messages used today`
   - Create `coach_provider.dart` (`AsyncNotifier<List<ChatMessage>>`) — stores message history in memory for the session

**Files to look at first:**
- `apps/backend/src/routes/ai.routes.ts` — stub to implement
- `features/coach/screens/coach_screen.dart` — placeholder to build out
- `features/coach/providers/` — create `coach_provider.dart`
- `apps/backend/src/repositories/` — create `coach.repository.ts` for CoachContext DB queries

---

## Previous session
**Date:** 2026-04-13 (session 12)
**What was built:**

### Push Notifications — full implementation

**Backend:**
- Added `fcmToken String?` field to `User` model in `prisma/schema.prisma`. Run `prisma db push` to apply (stop backend first or use `db push`).
- `apps/backend/src/repositories/user.repository.ts` — added `saveFcmToken(id, token)` and `findAllWithFcmToken()`.
- `apps/backend/src/routes/user.routes.ts` — new `POST /api/v1/user/fcm-token` endpoint (JWT-guarded, Zod-validated). Accepts `{ token: string | null }` — null clears the token on logout.
- Installed `firebase-admin` npm package.
- `apps/backend/src/utils/firebase.ts` — lazy Firebase Admin SDK initialisation from `FIREBASE_SERVICE_ACCOUNT` env var (JSON string). Exports `sendPush(token, title, body, data)` — gracefully returns false if env var not set.
- `apps/backend/src/utils/config.ts` — added optional `FIREBASE_SERVICE_ACCOUNT` env var.
- `apps/backend/src/jobs/weekly_summary.job.ts` — BullMQ `Queue` + `Worker` + repeatable cron job (`0 18 * * 0`, every Sunday 18:00 UTC). For each user with an FCM token: computes weekly workout count, avg daily calories, consecutive streak days; sends FCM push via Firebase Admin.
- `apps/backend/src/index.ts` — calls `startWeeklySummaryWorker()` and `scheduleWeeklySummaryJob()` on bootstrap.
- `apps/backend/.env` — added `FIREBASE_SERVICE_ACCOUNT=` placeholder.

**Flutter:**
- `pubspec.yaml` — added `flutter_local_notifications: ^17.2.4` and `timezone: ^0.9.4`.
- `apps/mobile/lib/core/services/notification_service.dart` — singleton `NotificationService`. Handles: FCM token fetch + `POST /api/v1/user/fcm-token`; token refresh listener; `flutter_local_notifications` initialisation with two Android channels (`fitcore_default`, `fitcore_reminders`); `scheduleWorkoutReminder(enabled, hour, minute)` daily at user-chosen time; `scheduleFoodLogReminder(enabled)` daily at 20:00; `scheduleStreakWarning(enabled)` daily at 21:00; `cancelFoodLogReminder()` / `cancelStreakWarning()` for in-app cancellation when condition met; FCM foreground message handler shows local notification.
- `apps/mobile/lib/features/settings/providers/notification_preferences_provider.dart` — `NotificationPreferences` model + `AsyncNotifier` backed by `SharedPreferences`. Stores: workout reminder toggle + HH:MM, food log reminder toggle, streak warning toggle.
- `apps/mobile/lib/features/settings/screens/notification_preferences_screen.dart` — `ConsumerWidget` with section headers, `SwitchListTile` per notification type, `AnimatedCrossFade` time picker tile (only shown when workout reminder is on), `TextButton` launches `showTimePicker`. Reschedules all local notifications on every change.
- `apps/mobile/lib/features/auth/providers/auth_provider.dart` — calls `NotificationService.instance.registerFcmToken()` (best-effort, `.ignore()`) after `_storeTokens`; calls `clearFcmToken()` in `_clearSession()` before wiping local session.
- `apps/mobile/lib/features/settings/screens/settings_screen.dart` — added "Notifications" `ListTile` (navigates to `/settings/notifications`).
- `apps/mobile/lib/constants/app_routes.dart` — added `notificationPrefs = '/settings/notifications'`.
- `apps/mobile/lib/router/app_router.dart` — added `notification-prefs` sub-route under `/settings`.
- `apps/mobile/lib/main.dart` — added `Firebase.initializeApp()`, `NotificationService.instance.init()`, `requestPermissions()` before `runApp`.
- `apps/mobile/android/app/src/main/AndroidManifest.xml` — added `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM` permissions; `ScheduledNotificationReceiver` and `ScheduledNotificationBootReceiver` receivers; FCM default channel meta-data.

**Decisions made:**
- FCM token registration is fire-and-forget (`.ignore()`) — login must never block on a network call to a non-critical endpoint.
- Notification preferences stored in `SharedPreferences` (not backend) — purely local; no cross-device sync needed for reminder times.
- Weekly summary BullMQ job sends to all users with an FCM token; no per-user opt-out on the server — users can mute via device notification settings. Simpler than an additional API + DB field.
- Used `AndroidScheduleMode.inexactAllowWhileIdle` for local scheduled notifications — avoids requiring the runtime exact-alarm permission dialog on Android 12, while still firing within a few minutes of the target time. Change to `exactAllowWhileIdle` if precision is required.
- `USE_EXACT_ALARM` manifest permission added alongside `SCHEDULE_EXACT_ALARM` — on Android 13+ `USE_EXACT_ALARM` grants exact alarms for select app categories without a user prompt; fallback is `SCHEDULE_EXACT_ALARM` which shows a system settings redirect.

**What's broken / known issues:**
- `Firebase.initializeApp()` in `main.dart` requires a `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) to be present. These files come from the Firebase console project. Without them the app will crash at startup. Add them to `android/app/` and `ios/Runner/` respectively.
- `FIREBASE_SERVICE_ACCOUNT` in backend `.env` is a placeholder — weekly summary pushes are silently skipped until a real service account JSON is pasted in (single-line, all newlines in the private key replaced with `\n`).
- Run `prisma db push` (with backend stopped) to apply the `fcmToken` column.
- Run `flutter pub get` to fetch `flutter_local_notifications` and `timezone`.

---

## Previous session
**Date:** 2026-04-13 (session 11)
**What was built:**

### Wellness Screen — full implementation

**Backend:**
- Added `MoodLog` model to `prisma/schema.prisma` (`id`, `userId`, `score 1–5`, `loggedAt`); ran `prisma db push` (bypassed advisory lock — see decisions).
- `apps/backend/src/repositories/wellness.repository.ts` — `logMood`, `getMoodHistory(days)`, `getTodayMood`, `getYesterdayCalsBurned` (aggregates WorkoutLog).
- `apps/backend/src/routes/wellness.routes.ts` — `POST /mood`, `GET /mood?days=N`, `GET /training-load`; Zod validated, JWT guarded, standard `{ success, data }` envelope.
- Registered at `/api/v1/wellness` in `src/index.ts`.

**Flutter — models / providers:**
- `features/wellness/models/wellness_state.dart` — `MoodLogEntry`, `ReadinessLevel` enum, immutable `WellnessState` with `sleepFormatted` / `hrZoneLabel` computed getters and `copyWithMood()`.
- `features/wellness/providers/wellness_provider.dart` — `WellnessNotifier extends AsyncNotifier<WellnessState>`; 7 futures started concurrently (health + API) before first `await`; readiness formula 40 % sleep + 30 % HR norm + 30 % training score; `logMood` optimistic update; `refresh()` resets to loading.

**Flutter — widgets:**
- `sleep_card.dart` — duration header, `_SleepStagesBar` (Expanded flex by minutes: deep/light/REM/awake), `_SleepTrendChart` (BarChart 7 days, dimmed bars < 7 h), `_ScoreBadge`.
- `heart_rate_card.dart` — resting BPM, zone badge colour-coded (success/info/warning/error), `_HrTrendChart` LineChart 7 days.
- `mood_logger_card.dart` — 5 emoji buttons (AnimatedContainer), disables after daily log, "✓ Logged" badge, `_MoodTrendChart` LineChart 14 days with per-score colours.
- `readiness_ring.dart` — `CustomPainter` animated arc (same pattern as CalorieRing); colour red/orange/green by level; recommendation label pill below ring.

**Flutter — screen + nav:**
- `wellness_screen.dart` fully rewritten: `_WellnessDashboard` (RefreshIndicator → ListView, staggered flutter_animate fade+slideY), readiness ring card → sleep → HR → mood order; `_ReadinessBreakdown` pills; `_ErrorView`.
- Moved `/wellness` GoRoute from outside-ShellRoute into `ShellRoute.routes` so it receives the bottom nav.
- Added `AppRoutes.wellness` to `_tabs` in `main_shell.dart` + `BottomNavigationBarItem` (self_improvement icon, "Wellness" label).

**Android manifest fix:**
- Added 7 Health Connect `<uses-permission>` entries.
- Added `ACTION_SHOW_PERMISSIONS_RATIONALE` intent-filter to `MainActivity`.
- Added `ViewPermissionUsageActivity` alias with `VIEW_PERMISSION_USAGE` + `HEALTH_PERMISSIONS` (required on Android 14 for app to appear in Health Connect list).
- Added `<package android:name="com.google.android.apps.healthdata"/>` in `<queries>`.

**Health service additions (`health_service.dart`):**
- `getSleepHistoryDays(int days)` — single SLEEP_ASLEEP query over full window, groups by wake-up date.
- `getHeartRateHistoryDays(int days)` — single HEART_RATE query, groups by day, returns `List<int?>` (null = no data).

**Decisions made:**
- Used `prisma db push` instead of `migrate dev` because the running backend process held the Postgres advisory lock (`pg_advisory_lock(72707369)`), causing `P1002` timeout. `db push` bypasses the lock entirely. For future schema changes during development, stop the backend first before running `migrate dev`.
- Wellness route moved into `ShellRoute` (not top-level) so the bottom nav is always visible on that tab — matches the pattern of every other main tab.
- Single bulk health query for 7-day history then aggregate in Dart, rather than 7 separate per-day queries. Reduces health plugin round-trips from O(N) to O(1).
- Readiness formula weights set to 40/30/30 (sleep/HR/training) — sleep is the strongest signal for daily readiness; weights can be tuned once real data is available.
- Outdoor toggle shown for all exercise types (not just cardio) — already decided in session 10; carried forward.

**Known issues:**
- Backend must be stopped before running `prisma migrate dev` to avoid advisory lock timeout.
- `ANTHROPIC_API_KEY` in backend `.env` is still a placeholder — AI coach routes will 500 until it is set.
- `app_database.g.dart` requires `flutter pub run build_runner build` on first clone; not auto-generated.
- If backend is unreachable, `wellness_provider.dart` catches API errors and falls back to null mood/training values — readiness ring still renders using only sleep + HR.
- First install after manifest change requires a full uninstall/reinstall for Health Connect permissions dialog to appear.

---

## Previous session
**Date:** 2026-04-13 (session 10)
**What was built:**

### GPS Outdoor Tracking — bug fix + APK reinstall

Investigated why the outdoor toggle was not visible on device. All GPS code was already implemented from session 8; the only problem was a visibility gate.

**Bug:** `_WorkoutBody` in `active_workout_screen.dart` wrapped the `_OutdoorToggle` card in `if (_isCardio)`, which checked whether `currentExercise.muscleGroup == MuscleGroup.cardio`. Any non-cardio exercise (Bench Press, Squat, etc.) made the toggle completely invisible.

**Fix (`active_workout_screen.dart`):**
- Removed the `if (_isCardio)` conditional block around `_OutdoorToggle`.
- Deleted the now-unused `_isCardio` getter from `_WorkoutBody`.
- Outdoor toggle now renders for every exercise — GPS route tracking is useful for any outdoor session, not just cardio.

**Calorie logic unchanged** — `finishWorkout()` already falls back gracefully: if the exercise ID is not in `kOutdoorKcalPerKgPerKm` it uses the default 0.90 kcal/kg/km coefficient; if no meaningful GPS distance was recorded it uses the time-based MET estimate.

**Build + install:**
- `flutter build apk --release` → 134.9 MB APK, no errors.
- Installed to CPH2401 (Android 14, wireless ADB) via `flutter install --release`.

**Decisions made:**
- Outdoor toggle shown for all exercises rather than cardio-only: an outdoor calisthenics or strength session in the park benefits from route tracking too, and hiding the toggle based on muscle group is surprising UX.

**Known issues:**
- None introduced this session. Pre-existing items carry forward: `app_database.g.dart` requires `build_runner` on first clone; `getTodayHeartRate()` / `getSleepStages()` implemented but not yet wired to Wellness screen; backend `ANTHROPIC_API_KEY` is a placeholder.

## Next session
**Priority task:** Phase 3 — AI coach chat.
1. Backend: implement `POST /api/v1/ai/chat` in `ai.routes.ts` — inject `CoachContext` (user profile + today's food/workout/steps), call `claude-sonnet-4-6` via `@anthropic-ai/sdk`, enforce 5 msg/day Redis rate limit for free tier.
2. Flutter: build `coach_screen.dart` — scrollable message list, text input bar, streaming or non-streaming response, loading indicator, rate-limit banner for free users.

**Files to look at first:**
- `apps/backend/src/routes/ai.routes.ts` — stub to implement
- `features/coach/screens/coach_screen.dart` — placeholder to build out
- `features/coach/providers/` — create `coach_provider.dart` (AsyncNotifier for message list)
- `apps/backend/src/repositories/` — add `coach.repository.ts` for CoachContext DB queries

---

## Previous sessions

### Session 9 — 2026-04-13
**Date:** 2026-04-13 (session 9)

**What was built:**

### Full Progress Screen — Phase 2 analytics complete

Replaced the placeholder Progress screen with a fully-featured analytics view:

**New files:**
- `features/progress/models/progress_data.dart` — `DayCalories`, `ExerciseWeekPoint`, `WeeklySummary`, `ProgressData` models
- `features/progress/providers/progress_provider.dart` — `ProgressNotifier` fires 17 parallel API calls (body stats, workout logs, user profile, 14 days of food logs) and computes all derived data client-side: strength curves, muscle group volume, weekly summaries
- `features/progress/widgets/weight_trend_chart.dart` — `WeightTrendChart`: `fl_chart` `LineChart` showing last 30 days of body-weight entries with a linear-regression trend line overlay (dashed orange)
- `features/progress/widgets/calorie_trend_chart.dart` — `CalorieTrendChart`: 7-day `BarChart` with green/red bars (under/over target) and a dashed yellow target line via `ExtraLinesData`
- `features/progress/widgets/strength_curve_chart.dart` — `StrengthCurveChart`: `LineChart` with up to 3 coloured lines (top 3 most-logged weighted exercises) showing max weight per week over 8 weeks; includes exercise name legend
- `features/progress/widgets/muscle_heatmap.dart` — `MuscleHeatmap`: front-view body silhouette using `CustomPainter` (10 body regions as scaled `RRect`s); 5-level colour scale from grey (0 sets) through blue gradient to red (16+ = overtraining); back muscles (back, hamstrings, glutes) shown as labelled chips alongside
- `features/progress/widgets/weekly_summary_card.dart` — `WeeklySummaryCard`: side-by-side this-week/last-week comparison for workouts completed, avg daily calories, and total volume (kg moved); colour-coded ± delta percentages

**Updated files:**
- `features/progress/screens/progress_screen.dart` — Replaced placeholder; `progressProvider` drives the full screen via `AsyncValue.when`; `RefreshIndicator` for pull-to-refresh; strength curves section hidden when no weighted history exists

**Key decisions:**
- All 17 API calls run in parallel via `Future.wait`; individual failures degrade gracefully (treat as 0/empty) so a single missing endpoint never breaks the screen
- Muscle group classification uses keyword matching on `exerciseName` (no schema change needed)
- Back muscles shown as chips rather than a back-view silhouette (saves screen space; back-view CustomPainter adds complexity for marginal gain)
- Strength curve x-axis uses absolute week index (0–7) computed from `weekStart` so all 3 exercises share a consistent time axis even when they have different numbers of data points

**Known limitations:**
- `/workout/logs` returns last 20 workouts; users doing 5+ workouts/week will see fewer than 8 weeks of strength curve data
- Calorie trend covers only the most recent 7 days of API data

---

### Task 1 — HealthKit / Google Fit integration (`health ^12`)

Fully implemented `core/services/health_service.dart`:

- **`requestPermissions()`** — requests STEPS, HEART_RATE, SLEEP_ASLEEP, SLEEP_AWAKE, WEIGHT with READ access, WORKOUT with READ_WRITE. Sleep stage types (DEEP, LIGHT, REM) requested best-effort in a separate call so iOS failures don't block the base grant.
- **`getTodaySteps()`** — production-ready; auto-requests permissions if not yet granted, returns 0 on any failure, queries midnight→now.
- **`getTodayHeartRate()`** — averages all HEART_RATE readings from today; returns `null` when no readings exist.
- **`getLastNightSleep()`** — sums SLEEP_ASLEEP intervals in the window 8 pm previous evening → 10 am today (clamped to now if before 10 am); returns total minutes.
- **`getSleepStages()`** — queries SLEEP_DEEP, SLEEP_LIGHT, SLEEP_REM in the same window; returns `null` (not a zero `SleepStages`) when all three are zero, so callers can fall back to total-only display.
- **`writeWorkout()`** — writes active energy burned as `ACTIVE_ENERGY_BURNED` (the portable cross-platform equivalent; a full WORKOUT session object requires platform-specific API not exposed by the health plugin's unified interface).

Wired into the rest of the app:
- `workout_provider.dart` `finishWorkout()` — calls `writeWorkout()` fire-and-forget via `unawaited()` after the backend POST / offline queue step. Failures are logged, never surfaced.
- `home_provider.dart` `_loadState()` — already calls `getTodaySteps()` (no change needed); `StepCounterCard` on the home dashboard now receives live HealthKit / Google Fit step data.
- `home_screen.dart` — converted from `ConsumerWidget` to `ConsumerStatefulWidget`; `initState` schedules `_maybePromptHealthPermissions()` via `addPostFrameCallback`. Shows a one-time `AlertDialog` listing all requested permissions with Allow / Skip actions. Flag `health_perms_prompted` written to SharedPreferences immediately before the dialog opens so a crash never re-prompts. On Allow → `requestPermissions()` → `homeProvider.refresh()` to repopulate steps.

**Decisions made:**
- `ACTIVE_ENERGY_BURNED` used instead of the `WORKOUT` type for writes because health ^12's unified API doesn't expose a cross-platform workout session write method; calories are the highest-value field for the native health app.
- `getSleepStages()` returns `null` (not zero `SleepStages`) to let callers distinguish "no data source" from "source returned 0 minutes" — avoids misleading UI.
- One-time prompt lives in `HomeScreen.initState` (not the onboarding flow) because RouterNotifier handles the onboarding→home redirect; injecting a permission step there would require restructuring the router redirect chain.
- `unawaited()` from `dart:async` (Dart 3.4+) is used for the fire-and-forget health write to suppress the un-awaited-future lint without a `// ignore` comment.

### Task 1 — GPS outdoor workout tracking (Phase 2 complete slice)

Full vertical slice: `GpsService` → `WorkoutSessionNotifier` → `ActiveWorkoutScreen` → `WorkoutSummaryScreen`.

**`core/services/gps_service.dart`** (already authored, confirmed complete):
- `GpsService.startTracking()` — requests `ACCESS_FINE_LOCATION` permission via `geolocator`, resets accumulated route/distance, opens a `LocationSettings(accuracy: high, distanceFilter: 5m)` position stream.
- `GpsService.stopTracking()` — cancels the stream subscription; safe to call when not tracking.
- `GpsService._onPosition()` — Haversine distance filter (< 5 m discarded as jitter); accumulates `_points` list and `_totalDistanceKm`; maintains a 30-second rolling pace window; emits `GpsUpdate` on the broadcast stream.
- `GpsService.encodePolyline()` — static, implements Google Encoded Polyline Algorithm; produces compact string for backend storage.
- `kOutdoorKcalPerKgPerKm` — map of cardio exercise IDs → kcal/kg/km (running 0.98, cycling 0.50, etc.).
- `outdoorCaloriesForExercise()` — top-level function, falls back to 0.90 for unknown IDs.
- `gpsServiceProvider` — `Provider<GpsService>` with `ref.onDispose(service.dispose)`.

**`workout_provider.dart`** — `WorkoutSessionNotifier` extended:
- `StreamSubscription<GpsUpdate>? _gpsSub` field; cancelled in `ref.onDispose` and `resetSession`.
- `toggleOutdoorMode()` — async; if turning on: calls `gps.startTracking()`, subscribes `_gpsSub = gps.updates.listen(_onGpsUpdate)`; if turning off: stops GPS, cancels sub.
- `_onGpsUpdate()` — copies `route`, `distanceKm`, `paceMinPerKm` into `WorkoutSessionState`.
- `finishWorkout()` — stops GPS, captures `routePoints`; if `distanceKm > 0.05 && hasCardio`: uses `outdoorCaloriesForExercise` (distance-based); otherwise falls back to time-based MET. Encodes polyline; includes `distanceM` and `routePolyline` in backend payload.
- Fixed missing `import 'package:latlong2/latlong.dart'`.

**`workout_session_state.dart`** — `WorkoutSessionState` and `WorkoutSummary` extended with `isOutdoorMode`, `routePoints`, `distanceKm`, `paceMinPerKm` (session) and `distanceKm`, `routePolyline`, `routePoints` (summary). Uses sentinel pattern for nullable `copyWith` field.

**`active_workout_screen.dart`** — `_OutdoorToggle` card (cardio exercises only) + `_GpsStatsBar` (distance + pace, shown while outdoor mode is active). `onToggleOutdoor` wired to `workoutSessionProvider.notifier.toggleOutdoorMode()`.

**`workout_summary_screen.dart`** — `_DistanceCard` (wide card, outdoor workouts only) + `_RouteMap` (flutter_map with OpenStreetMap tiles, polyline layer, start/finish markers). Uses `CameraFit.bounds` to auto-fit the route with padding.

**Decisions made:**
- Haversine formula inlined in `GpsService` instead of using `latlong2`'s `Distance` class — avoids potential unit conversion ambiguity and keeps the jitter threshold in km consistent with `_totalDistanceKm`.
- `distanceFilter: 5` in `LocationSettings` reduces battery drain and stream volume on slow-moving workouts.
- Polyline encoding done on-device before the backend POST so the route is immediately available in the `WorkoutSummary` for the map without a round-trip.
- `flutter_map` with OpenStreetMap tiles chosen for the summary map — no API key required, offline rendering not needed (route review happens post-workout on Wi-Fi).

**Known issues:**
- `latlong2` import was missing from `workout_provider.dart`; fixed before the release build.
- `ACCESS_BACKGROUND_LOCATION` is deliberately **not** requested — GPS only runs while the workout screen is in the foreground; background tracking is not a FitCore feature.

### Task 2 — Settings back navigation fix

`SettingsScreen` had no back button because it was reached via `context.go()`, which replaces the GoRouter stack rather than pushing onto it, so the `AppBar` never inserted an automatic leading arrow.

- `settings_screen.dart` — added explicit `leading: IconButton(Icons.arrow_back_rounded, context.pop())` to the `AppBar`.
- `home_screen.dart` — changed `context.go(AppRoutes.settings)` → `context.push(AppRoutes.settings)` so the full GoRouter stack is preserved; this also re-enables the OS back gesture and Android predictive-back animation for free.

### Task 3 — Android release build (proguard fix + device install)

R8 minification was stripping classes referenced by ML Kit text recognition (non-Latin script stubs) and Flutter's Play Store deferred components plugin. Both are unused by FitCore but referenced in plugin dispatch tables.

- Created `android/app/proguard-rules.pro` with `-dontwarn` rules for all missing classes (generated by R8 into `build/.../missing_rules.txt`).
- Wired the file into `android/app/build.gradle.kts` `release` block via `proguardFiles(...)`.
- Built 132.7 MB release APK and installed on CPH2401 (Android 14, connected wirelessly via ADB).

**Decisions made:**
- `context.push()` preferred over `context.go()` for all routes reached from within the main shell — preserves the back stack without any manual leading-button wiring in the destination screen. Settings was the only offender; other detail screens already used `push`.
- Proguard `-dontwarn` chosen over `-keep` for the missing classes — they are genuinely unused at runtime; keeping them would increase APK size for no benefit.

**Known issues:**
- `app_database.g.dart` still requires codegen on first clone: `cd apps/mobile && flutter pub run build_runner build --delete-conflicting-outputs`
- `getTodayHeartRate()` and `getSleepStages()` are implemented but not yet wired to any screen — Wellness screen is the planned consumer.
- Backend `ANTHROPIC_API_KEY` is a placeholder (`sk-ant-placeholder`) — AI coach chat will fail until a real key is supplied in `apps/backend/.env`.

## Next session
**Priority task:** Phase 2 — Wire `getLastNightSleep()` + `getSleepStages()` + `getTodayHeartRate()` into `WellnessScreen` (currently a placeholder). Then Phase 3 — AI coach chat: implement the `/api/v1/ai/chat` backend endpoint with Claude API call + `CoachContext` injection, and build out `coach_screen.dart`.

**Files to look at first:**
- `features/wellness/screens/wellness_screen.dart` — placeholder; add sleep + HR cards
- `apps/backend/src/routes/ai.routes.ts` — stub; implement chat endpoint
- `features/coach/screens/coach_screen.dart` — placeholder; build chat UI

---

## Session history
| Date | Built | Phase |
|---|---|---|
| 2026-04-14 (s14) | Nav restructure: 5-tab bottom nav, Social → AppBar, avatar → ProfileScreen, card-grouped settings UI | 1 polish |
| 2026-04-13 (s13) | Push notifications Android shipped: Gradle fixes, Firebase wired, prisma migration, graceful Redis fallback, iOS AppDelegate+Info.plist prepped | 2 ✅ |
| 2026-04-13 (s12) | Push notifications full implementation: FCM token reg, local scheduled notifications, BullMQ weekly summary job, notification prefs screen | 2 |
| 2026-04-13 (s11) | Wellness screen: sleep card, HR card, mood logger, readiness ring, backend mood API | 2 |
| 2026-04-13 (s10) | GPS outdoor toggle visibility fix (removed cardio-only gate); release APK reinstalled | 2 bug fix |
| 2026-04-13 (s8+9) | GPS outdoor tracking full slice + progress screen analytics | 2 |
| 2026-04-12 (s7) | Settings back nav fix, Android proguard rules, device reinstall | 1 polish |
| 2026-04-12 (s6) | HealthKit/Google Fit full integration (5 read + writeWorkout), one-time permissions prompt | 2 |

## Previous session (2026-04-12 session 5)

**What was built:**

### Task 1 — Full UI audit: loading / error / empty / hardcoded values (13 screens)

Found and fixed 5 issues:

1. **HomeScreen** — `foodLogsProvider` error silently showed 0 kcal / 0g with no feedback. Added `AsyncError` branch to the `ref.listen` to show a SnackBar.
2. **NutritionScreen** — `_DaySummary` showed consumed calories with no target. Now watches `homeProvider` for TDEE and shows `"500 / 2000 kcal"` + `"1500 remaining"` (or over-budget in red).
3. **ProgressScreen** — API error caused body weight card to show `"No entries yet"` misleadingly. Now shows `"Failed to load — tap to retry"` in error colour when `statsAsync.hasError`.
4. **BodyLogScreen** — history error had no action. Added `OutlinedButton('Retry')` calling `refresh()`.
5. **FoodSearchScreen** — `_ErrorView` had no retry. Added optional `onRetry` callback that re-runs the last search.

### Task 2 — Workout calorie burn: MET × actual body weight

`workout_provider.dart` `finishWorkout()` now reads the user's latest `BodyStat.weightKg` from the already-cached `bodyLogProvider` (falls back to 70 kg if none). Formula: `MET × weightKg × (durationMin / 60.0)` — strength MET 5.0, cardio MET 8.0.

### Task 3 — Offline retry queue (Drift)

Full vertical slice: Drift DB → service → provider hooks → lifecycle trigger → UI indicator.

**Flutter**
- `core/db/app_database.dart` — Drift `@DriftDatabase`; `PendingSyncItems` table (id, endpoint, payloadJson, createdAt); `appDatabaseProvider`
- `core/db/daos/sync_dao.dart` — `part of` the database file; `enqueue`, `getAll`, `deleteById`, `watchCount` (reactive stream)
- `core/services/sync_queue_service.dart` — `SyncQueueService.flush()` retries items oldest-first, stops on first failure to preserve ordering; `syncQueueCountProvider` (StreamProvider wrapping `watchCount`)
- `nutrition_provider.dart` `logFood()` — payload extracted before POST; `e.response == null` → enqueue + return normally (no error thrown); server errors still surface as before
- `workout_provider.dart` `finishWorkout()` — same pattern; `DioException` split into network-error branch (enqueue) and server-error branch (log only)
- `router/main_shell.dart` — converted to `ConsumerStatefulWidget` + `WidgetsBindingObserver`; calls `flush()` on cold start and on `AppLifecycleState.resumed`
- `features/home/screens/home_screen.dart` — watches `syncQueueCountProvider`; shows `CircularProgressIndicator` + `"Syncing…"` text in AppBar while queue is non-empty

**Decisions made:**
- `e.response == null` is the network-error gate — true only when Dio received no response (socket error, timeout); 4xx/5xx always have a response and are not enqueued
- On network error in `logFood`, no exception is thrown — the sheet closes normally and the 'Syncing…' indicator signals pending data; avoids a confusing "saved locally" vs "failed" split message
- Flush stops on first failure (not skip-and-continue) — preserves ordering so that a workout log is never replayed out of sequence relative to food logs recorded the same day
- No `connectivity_plus` dependency added — flush is triggered on app resume only; this covers the primary use case (user logs offline, opens app on Wi-Fi) without adding a dependency
- `SyncDao` is a `part of` `app_database.dart` (not a separate library file) — avoids the circular import between the DAO and the database class while keeping the DAO in its own file under `daos/`

**Known issues / required step:**
- `app_database.g.dart` does not exist yet — every `_$` symbol and `Companion` class shows as undefined until codegen runs. **Must run before first build:**
  ```
  cd apps/mobile && flutter pub run build_runner build --delete-conflicting-outputs
  ```
- Water goal (2000 ml) remains hardcoded in `WaterTrackerCard` — no schema field for it
- Calorie burn is still an estimate (no GPS, no heart rate); MET formula is significantly more accurate than the previous flat rate but still approximate

## Next session
**Priority task:** Phase 2 — Wire `getTodayHeartRate()` and `getSleepStages()` / `getLastNightSleep()` into the Wellness screen. Then Phase 3 — AI coach chat: implement `/api/v1/ai` backend endpoint (Claude API call + context injection) and fill `coach_screen.dart`.

**Files to look at first:**
- `features/wellness/screens/wellness_screen.dart` — placeholder; wire health service sleep + HR data here
- `apps/backend/src/routes/ai.routes.ts` — implement chat endpoint
- `features/coach/screens/coach_screen.dart` — placeholder to fill

---

## Session history
| Date | Built | Phase |
|---|---|---|
| 2026-04-12 (s6) | HealthKit/Google Fit integration: 5 read methods + writeWorkout, one-time permissions prompt | 2 |
| 2026-04-12 (s5) | UI audit fixes (5 screens), MET calorie formula, offline Drift retry queue | 1 polish + 2 |
| 2026-04-12 (s4) | UI audit (13 screens audited, 5 issues fixed — loading/error/empty/hardcoded) | 1 polish |
| 2026-04-11 (s3) | Workout history (expandable cards), body weight logging full stack, Progress screen entry point | 1 ✅ |
| 2026-04-11 (s2) | Workout logger (exercise picker, active workout, rest timer, summary), backend POST + GET /workout/logs | 1 |
| 2026-04-09 | Home dashboard (calorie ring, steps, water tracker, streak card) | 1 |
| 2026-04-09 | Bug fixes: swipe-delete persist, raw food search (USDA merge) | 1 |
| 2026-04-09 | Onboarding flow (goal, body stats, activity), settings + logout | 1 |

---

## Previous session — UI audit (2026-04-12 session 4)
**Date:** 2026-04-11 (session 3 — Phase 1 complete)

**What was built:**

### Task 1 — Workout history screen

**Flutter**
- `features/workout/models/workout_log.dart` — `ExerciseSetLog` (id, exerciseName, setNumber, reps, weightKg, durationSec; `detail` computed getter) + `WorkoutLog` (id, name, startedAt, finishedAt, durationMin, caloriesBurned, sets; `setsByExercise` getter groups sets by exercise name preserving insertion order); both with `fromJson` factories
- `features/workout/providers/workout_history_provider.dart` — `WorkoutHistoryNotifier` (`AsyncNotifier`): `build()` calls `GET /workout/logs`, `refresh()` re-fetches
- `features/workout/screens/workout_history_screen.dart` — `ConsumerWidget` with `RefreshIndicator`; each workout rendered as a `Card` wrapping `ExpansionTile` (name + date in title/subtitle, duration/sets/calories stat chips in trailing); on expand: sets grouped by exercise with coloured exercise name header and set rows; empty and error states included

### Task 2 — Body weight logging

**Backend**
- `repositories/body.repository.ts` — `createBodyStat(userId, weightKg, bodyFatPct?)` Prisma create; `getBodyStats(userId)` last 30 ordered by `measuredAt desc`
- `routes/body.routes.ts` — `POST /api/v1/body/stats` (Zod: weightKg positive ≤500, bodyFatPct 1–70 optional) → 201 + created stat; `GET /api/v1/body/stats` → last 30 entries; both JWT-guarded
- `index.ts` — registered `bodyRoutes` at `/api/v1/body`

**Flutter**
- `features/progress/models/body_stat.dart` — `BodyStat` (id, measuredAt, weightKg?, bodyFatPct?) with `fromJson`
- `features/progress/providers/body_log_provider.dart` — `BodyLogNotifier` (`AsyncNotifier`): `build()` fetches `GET /body/stats`; `logWeight(weightKg, bodyFatPct?)` POSTs then re-fetches to get server timestamp; `refresh()`
- `features/progress/screens/body_log_screen.dart` — `ConsumerStatefulWidget`; weight + body fat TextFields with decimal input formatters; today's date shown as read-only label; `ref.listen` pre-fills weight field from last entry once data loads; "Save Weight" with loading spinner; coloured success/error SnackBars; history list below as `_StatRow` widgets showing date + weight + body fat; `RefreshIndicator` on full scroll view
- `features/progress/screens/progress_screen.dart` — updated to `ConsumerWidget`; watches `bodyLogProvider`; body weight summary card shows last logged weight + date (or "No entries yet" prompt) and taps through to `bodyLog`; charts placeholder with descriptive copy for Phase 2; AppBar scale icon retained

**Decisions made:**
- `BodyLogNotifier.logWeight` re-fetches from server after POST (rather than prepending locally) — ensures `measuredAt` timestamp is exactly what the DB recorded, avoids clock skew between device and server
- `_preFilledWeight` flag in `_BodyLogScreenState` ensures the weight field is only pre-filled once from the last entry (not re-overwritten every time the provider refreshes after a save)
- Weight field cleared after successful save — signals to the user that the action completed; field can be re-populated from the history list
- `ProgressScreen` upgraded from `StatelessWidget` → `ConsumerWidget` (watches `bodyLogProvider` to show latest weight in summary card); this is a read-only watch, does not trigger extra fetches
- `setsByExercise` implemented as a getter on `WorkoutLog` rather than in the provider — keeps the provider thin and makes the grouping available wherever the model is used

**Known issues:**
- `body_log_screen.dart`: `FilteringTextInputFormatter` regex `^\d+\.?\d{0,1}` allows only 1 decimal place; if user pastes "75.55" the second decimal is dropped silently (acceptable for weight logging)
- Workout history shows calories as `~N` from the estimate stored at workout-end; no recalculation on view
- Progress screen body weight card shows only the most recent entry's date in short form (`dd Mon`); full date visible inside `BodyLogScreen`

## Next session
**Priority task:** Phase 1 is complete. Start Phase 2 — first target: Apple HealthKit / Google Fit sync via the `health` plugin (step counting already partially wired in `health_service.dart`; extend to read weight and workouts).

**Alternatively:** AI coach chat (Phase 3 item but high user value — Claude API integration through backend `/api/v1/ai` stub already registered).

**Files to look at first:**
- `core/services/health_service.dart` — extend with weight + workout read
- `apps/backend/src/routes/ai.routes.ts` — implement coach chat endpoint
- `features/coach/screens/coach_screen.dart` — placeholder to fill

---

## Session history
| Date | Built | Phase |
|---|---|---|
| 2026-04-11 (s3) | Workout history (expandable cards), body weight logging full stack, Progress screen entry point | 1 ✅ |
| 2026-04-11 (s2) | Workout logger (exercise picker, active workout, rest timer, summary), backend POST + GET /workout/logs | 1 |
| 2026-04-09 | Home dashboard (calorie ring, steps, water tracker, streak card) | 1 |
| 2026-04-09 | Bug fixes: swipe-delete persist, raw food search (USDA merge) | 1 |
| 2026-04-09 | Onboarding flow (goal, body stats, activity), settings + logout | 1 |

---

## Previous session — Workout logging flow (2026-04-11 session 2)
**Date:** 2026-04-11 (session 2)

**What was built:**

### Workout logging flow (full vertical slice — Screens 1–3 + backend)

**Flutter**
- `features/workout/models/exercise.dart` — `Exercise` model + `MuscleGroup` enum with label/icon/color extensions; `kExerciseLibrary` const list of 50 exercises (6 chest, 7 back, 5 shoulders, 7 arms, 10 legs, 7 core, 8 cardio)
- `features/workout/models/workout_session_state.dart` — `LoggedSet`, `WorkoutSummary`, `WorkoutSessionState` with `copyWith`; computed getters: `isActive`, `setsForCurrentExercise`, `nextSetNumber`
- `features/workout/providers/workout_provider.dart` — `WorkoutSessionNotifier` (`Notifier`): `startWorkout`, `setExercise`, `logSet` (appends set + starts 90s rest timer via `Timer.periodic`), `skipRest`, `finishWorkout` (POSTs to backend, estimates calories at 5 kcal/min strength / 8 kcal/min cardio, sets `summary`), `resetSession`; `ref.onDispose` cancels timer
- `features/workout/widgets/set_logger.dart` — stateful form with reps + weight (kg) TextFields, pre-fills from last logged set, "Add Set" `ElevatedButton`; validates at least one field filled
- `features/workout/widgets/rest_timer_widget.dart` — `CircularProgressIndicator` countdown (90s); turns red in last 10s; "Skip Rest" button
- `features/workout/screens/exercise_picker_screen.dart` — `TextField` search bar; `ListView` grouped by `MuscleGroup` with colour-coded section headers; `context.pop<Exercise>(e)` on tap; staggered `flutter_animate` fade-in per group
- `features/workout/screens/active_workout_screen.dart` — `ConsumerStatefulWidget`; elapsed timer (`Timer.periodic`) displayed in AppBar; cancel dialog (`_confirmCancel` with `async/await`); switches between `SetLogger` and `RestTimerWidget` based on `isResting`; "Switch Exercise" pushes to picker and calls `setExercise`; "Finish" calls `finishWorkout` then navigates to summary; 0-set guard with SnackBar
- `features/workout/screens/workout_summary_screen.dart` — stats row (duration / total sets / ~calories); exercises list; animated trophy icon; "Done" resets session and `context.go(/workout)`
- `features/workout/screens/workout_screen.dart` — updated to `ConsumerWidget`; shows "Start Workout" or "Resume / New Workout" depending on `session.isActive`; `context.push<Exercise>` picks exercise then starts session
- `constants/app_routes.dart` — added `workoutSummary = '/workout/summary'`
- `router/app_router.dart` — added `GoRoute(path: 'summary', ...)` inside workout sub-routes

**Backend**
- `repositories/workout.repository.ts` — `createWorkoutLog` (Prisma create with nested `sets`; `include: { sets: true }`); `getWorkoutLogs` (last 20, ordered by `startedAt desc`)
- `routes/workout.routes.ts` — `POST /api/v1/workout/logs` fully implemented with Zod validation (`createWorkoutLogSchema` + `exerciseSetSchema`); `GET /api/v1/workout/logs` returns last 20; remaining stubs (PATCH, GET /exercises, GET /templates) preserved

**Decisions made:**
- Rest timer runs in the `Notifier` via `dart:async Timer.periodic`; cancelled via `ref.onDispose` — no separate isolate or stream needed
- Calorie estimate is client-computed (5 kcal/min strength, 8 kcal/min cardio) and sent to backend; rough estimate flagged with `~` in UI
- Network failure on `finishWorkout` POST is swallowed — summary still shows (workout data shown even offline)
- `WorkoutSummaryScreen` uses `automaticallyImplyLeading: false` — user exits via "Done" button only to prevent accidental back-navigation losing state
- `workoutSummary` route placed inside the workout `ShellRoute` sub-routes so GoRouter back-stack works naturally from active → summary

**Known issues:**
- `flutter analyze` may flag `surfaceContainerHighest` if theme doesn't define it (fallback to `surface` works fine)
- Cardio exercises show reps/weight fields — a duration-specific field for cardio is Phase 2 UX polish
- Calorie burn estimate is rough (5 kcal/min strength, 8 kcal/min cardio × duration) — acceptable for MVP, needs user weight for accuracy
- Workout history screen is still a placeholder — `GET /api/v1/workout/logs` is implemented on the backend but the Flutter side is not wired up yet

## Next session
**Priority task:** Complete Phase 1 — Workout history list + body weight logging. These are the last two unchecked Phase 1 items.

**Workout history** (`[ ]` → `[x]`):
- Wire `WorkoutHistoryScreen` to `GET /api/v1/workout/logs`
- Show each workout as a card: name, date, duration, sets, calories
- Tap to expand sets detail

**Body weight logging** (`[ ]` → `[x]`):
- `POST /api/v1/body/stats` + `GET /api/v1/body/stats` backend routes
- Simple screen: weight input + date picker, list of recent entries
- Hook into Progress tab placeholder

**Files to look at first:**
- `features/workout/screens/workout_history_screen.dart` (placeholder to fill)
- `apps/backend/src/routes/workout.routes.ts` (GET /logs already done — just wire Flutter)
- `features/progress/screens/progress_screen.dart` (placeholder — add body weight entry point)
- `apps/backend/src/routes/` — need a new `body.routes.ts` for body stats

---

## Session history
| Date | Built | Phase |
|---|---|---|
| 2026-04-11 | Workout logger (exercise picker, active workout, rest timer, summary), backend POST + GET /workout/logs | 1 |
| 2026-04-09 | Home dashboard (calorie ring, steps, water tracker, streak card) | 1 |
| 2026-04-09 | Bug fixes: swipe-delete persist, raw food search (USDA merge) | 1 |
| 2026-04-09 | Onboarding flow (goal, body stats, activity), settings + logout | 1 |

---

## Previous session — Home dashboard (2026-04-09)

**What was built:**

### Home dashboard (full vertical slice)

**Flutter**
- `lib/core/services/health_service.dart` — implemented `requestPermissions()` and `getTodaySteps()` using `health ^12`; `configure()` + `requestAuthorization([HealthDataType.STEPS])`; `getTotalStepsInInterval(midnight, now)` wrapped in try/catch (returns 0 on denial or error); added `healthServiceProvider` Riverpod `Provider`
- `features/home/models/home_state.dart` — `UserProfileDto` (parses backend `/user/profile` response: tdee, fitnessGoal, activityLevel; `FitnessGoal goal` getter converts string → enum); `HomeDashboardState` (tdee, fitnessGoal, steps, waterMl, streak, graceUsed; `copyWith`; `goal` getter)
- `features/home/providers/home_provider.dart` — `HomeDashboardNotifier` (AsyncNotifier): `build()` kicks off profile + steps fetches in parallel, loads today's water from SharedPreferences, loads persisted streak; `addWater(ml)` updates state + persists to `water_ml_YYYY-MM-DD` key; `updateStreakForToday(hasLogs)` computes streak using consecutive-day logic with grace-shield support; `refresh()` re-runs build; fallback TDEE of 2000 kcal if profile fetch fails
- `features/home/widgets/calorie_ring.dart` — `CalorieRing` (`StatefulWidget`): `AnimationController` (1200ms, easeOutCubic) drives a `CustomPainter` arc from 0 → progress fraction; re-animates on `didUpdateWidget`; shows consumed kcal, "kcal eaten", and a pill showing remaining/over in primary/error colour
- `features/home/widgets/macro_bars.dart` — `MacroBars`: three `_MacroRow` widgets for protein/carbs/fat; each uses `TweenAnimationBuilder` (900ms, easeOutCubic) on `LinearProgressIndicator`; targets computed from `MacroCalculator.forGoal(tdee, goal)`
- `features/home/widgets/step_counter_card.dart` — `StepCounterCard`: animated `LinearProgressIndicator` (secondary → success colour when goal reached), formatted step count (k suffix), pct label
- `features/home/widgets/water_tracker_card.dart` — `WaterTrackerCard`: animated progress bar, 8 droplet icons (filled vs outlined), `+250ml` / `+500ml` `OutlinedButton.icon` buttons; `onAdd` callback to parent
- `features/home/widgets/streak_card.dart` — `StreakCard`: flame icon (warning colour when >0 else muted), `TweenAnimationBuilder` scale bounce on the count, shield-ready/used indicator with `Icons.shield_rounded`
- `features/home/screens/home_screen.dart` — full `ConsumerWidget` dashboard: `ref.listen(foodLogsProvider, ...)` calls `updateStreakForToday` when logs load (no rebuild loop); `homeAsync.when` renders loading/error/data; `_Dashboard` is pure `StatelessWidget` (callbacks passed as params); staggered `flutter_animate` fade+slideY on all four cards (0ms / 80ms / 160ms / 240ms delays); pull-to-refresh wired

**Decisions made:**
- `health.configure()` called with no args — `useHealthConnectIfAvailable` parameter doesn't exist in health ^12.0.0 (was added later); Health Connect fallback is automatic on Android 14+
- `homeProvider` does NOT watch `foodLogsProvider` — the screen uses `ref.listen` to fire `updateStreakForToday` once without creating a rebuild dependency in the provider
- Water key is day-specific (`water_ml_YYYY-MM-DD`) so it resets automatically across calendar days without any cleanup logic
- Profile fetch failing gracefully (fallback TDEE=2000, goal=maintain) — dashboard stays usable even if the backend is unreachable
- `_Dashboard` and all card widgets are pure `StatelessWidget` / `StatelessWidget` — callbacks injected from `HomeScreen`; follows CLAUDE.md component architecture pattern

**Known issues:**
- `flutter analyze`: 2 `info`-level `prefer_const_constructors` hints in `water_tracker_card.dart` (non-blocking; ClipRRect contains animated child so cannot be const)
- Steps will show 0 until the user grants Health / Google Fit permissions (graceful — no crash)
- Streak persists locally only; no backend streak endpoint exists yet (Phase 2)

**CLAUDE.md feature status update:**
- `[ ]` Macro/calorie dashboard for the day → `[x]`
- `[ ]` Home dashboard (calorie ring, steps, water, streak) → `[x]`

---

## Previous session
**Date:** 2026-04-09

**What was built:**

### Bug fixes: swipe-delete + raw food search

**Delete not persisting (two-layer fix):**
- Root cause: Fastify's JSON parser rejected `DELETE /food-logs/:id` with HTTP 400 (`FST_ERR_CTP_EMPTY_JSON_BODY`) because Dio sends `Content-Type: application/json` on all requests including DELETE, and Fastify's default parser rejects an empty body for that content-type
- Fix 1 — `apps/backend/src/index.ts`: added global `addContentTypeParser` that treats an empty JSON body as `{}` instead of an error
- Fix 2 — `apps/mobile/lib/features/nutrition/widgets/meal_section.dart`: moved API call inside `confirmDismiss` (awaited, returns `true` only on success) instead of fire-and-forget in `onDismissed`; kcal total now recalculates immediately on confirmed delete via `removeLogLocally`
- `apps/mobile/lib/features/nutrition/providers/nutrition_provider.dart`: `removeLogLocally` recalculates `DayTotals` from remaining logs in-place; `deleteLog` simplified (no re-fetch — UI updates optimistically)

**Raw/whole foods not appearing in search (banana, chicken, rice, etc.):**
- Root cause: Open Food Facts only covers packaged/branded products — raw whole foods are not in their database
- Fix: `apps/mobile/lib/core/services/open_food_facts_service.dart` rewritten to run USDA FoodData Central search in parallel with OFF using `Future.wait`; results merged with deduplication (USDA first for better raw food data, then OFF for branded goods); both are non-fatal (failure of either source is swallowed)
- `apps/mobile/lib/features/nutrition/models/food_item.dart`: added `FoodItem.fromUsdaJson` factory; USDA nutrient IDs used: 1008=kcal, 1003=protein, 1005=carbs, 1004=fat, 1079=fiber; uses `dataType=SR Legacy,Foundation` to cover raw and foundational foods

**Verified on CPH2401 (OnePlus, Android 14):**
- Swipe-delete: kcal total drops immediately + item stays gone after pull-to-refresh ✓
- "banana" search returns USDA results (~89 kcal/100g raw banana) ✓
- Packaged foods still appear from OFF alongside USDA results ✓

**Decisions made:**
- `deleteLog` no longer re-fetches from server after delete — `removeLogLocally` updates state immediately; server is source of truth only on next full refresh
- USDA `DEMO_KEY` used (rate-limited to 1000 req/hour/IP); swap for real key via `USDA_API_KEY` env var when needed
- USDA results placed first in merged list (better raw food macro accuracy); OFF appended after

**Known issues:**
- None — delete and raw food search both verified working

---

## Previous session
**Date:** 2026-04-09

**What was built:**

### Onboarding flow (full vertical slice)
- `packages/shared/src/types/index.ts` — added `hasProfile: boolean` to `UserDto`
- `apps/backend/src/repositories/user.repository.ts` — all finders now include `profile` relation; added `upsertProfile`, `createBodyStat`, `updateStats`
- `apps/backend/src/services/auth.service.ts` — `toUserDto` accepts `Prisma.UserGetPayload<{ include: { profile: true } }>`, sets `hasProfile`
- `apps/backend/src/routes/user.routes.ts` — implemented `GET /api/v1/user/profile` + `POST /api/v1/user/profile`; Mifflin-St Jeor TDEE calculated server-side; Prisma transaction atomically updates User + upserts UserProfile + creates BodyStat; Zod validation on all inputs
- `features/auth/models/auth_state.dart` — added `hasProfile: bool` + `copyWith` to `UserDto`
- `features/auth/providers/auth_provider.dart` — added `markProfileComplete()` — flips `hasProfile` in-memory, fires RouterNotifier
- `features/onboarding/models/onboarding_state.dart` — `OnboardingData` accumulates goal + body stats across screens
- `features/onboarding/providers/onboarding_provider.dart` — `OnboardingNotifier` with `setGoal`, `setBodyStats`, `submit(activityLevel)` → POST → `markProfileComplete()`
- `features/onboarding/screens/goal_selection_screen.dart` — 4 animated goal cards, step indicator (1/3), Continue disabled until selection
- `features/onboarding/screens/body_stats_screen.dart` — height/weight text fields with validation, date picker (min age 13), gender dropdown
- `features/onboarding/screens/activity_level_screen.dart` — 5 animated level cards, loading spinner on submit, inline error display
- `router/router_notifier.dart` — full redirect matrix: unauthenticated → `/login`; authenticated + auth route + no profile → `/onboarding/goal`; authenticated + no profile + non-onboarding → `/onboarding/goal`; authenticated + has profile + onboarding route → `/home`

### Settings + Logout
- `features/home/screens/home_screen.dart` — added ⚙ settings icon in AppBar
- `features/settings/screens/settings_screen.dart` — user avatar initial + name + email header; Log Out button (red) with confirmation dialog; logout clears tokens + RouterNotifier redirects to `/login`

**Decisions made:**
- `hasProfile` lives in `UserDto` (not a separate provider) — auth state is the single source of truth for routing
- `markProfileComplete()` mutates in-memory auth state (no re-fetch needed) — instant router redirect after POST
- Gender `other`/`prefer_not_to_say` uses the female BMR formula (conservative; standard convention)
- Onboarding uses `context.go()` throughout (no back-stack); Back buttons navigate explicitly to previous route
- Prisma transaction for atomic profile creation — all-or-nothing write

**Known issues / gotchas:**
- Backend `dev` script had wrong flag order (`tsx --env-file=.env watch` → fails on tsx v4); fixed to `tsx watch --env-file=.env src/index.ts`
- Backend must be manually restarted after code changes (no hot-reload in current setup); run: `cd apps/backend && node_modules/.bin/tsx --env-file=.env src/index.ts`
- Physical device needs backend at `http://192.168.1.5:3000` (LAN IP); emulator needs `http://10.0.2.2:3000` — update `apps/mobile/.env` when switching

## Last session
**Date:** 2026-04-09
**What was built:**

### Food log screen (full vertical slice)

**Backend**
- `src/repositories/nutrition.repository.ts` — `createFoodLog`, `getFoodLogsByDate` (midnight-bounded date window), `deleteFoodLog` (userId-scoped to prevent cross-user deletion)
- `src/routes/nutrition.routes.ts` — fully implemented `POST /food-logs`, `GET /food-logs?date=YYYY-MM-DD` (returns `{ logs, totals }`), `DELETE /food-logs/:id`; JWT auth + Zod validation on all three; old 501 stubs replaced

**Flutter**
- `features/nutrition/models/food_log.dart` — `FoodLog` + `DayTotals` + `DayLogs` models with `fromJson`
- `features/nutrition/providers/nutrition_provider.dart` — added `FoodLogsNotifier` (AsyncNotifier): `build()` auto-fetches today; `logFood(item, servingG, mealType)` posts then re-fetches; `deleteLog(id)` deletes then re-fetches; `refresh()` for pull-to-refresh
- `features/nutrition/widgets/log_food_sheet.dart` — bottom sheet: amount input (FilteringTextInputFormatter), unit `SegmentedButton` (g / cup / piece), live macro preview box, meal `ChoiceChip` row, "Log X kcal to meal" `FilledButton` with loading state; unit multipliers: g=1, cup=240, piece=100
- `features/nutrition/widgets/meal_section.dart` — per-meal group: emoji header + section kcal total; `Dismissible` log items with swipe-left-to-delete confirmation dialog; name + serving + P/C/F detail row + kcal on the right
- `features/nutrition/screens/nutrition_screen.dart` — `ConsumerWidget`; `_DaySummary` card (total kcal + P/C/F tiles); `CustomScrollView` with all 4 `MealSection`s; pull-to-refresh via `RefreshIndicator`; error view with Retry
- `features/nutrition/screens/food_search_screen.dart` — `_onFoodSelected` now calls `showLogFoodSheet`; pops back to NutritionScreen after successful log
- `features/nutrition/screens/barcode_screen.dart` — "Add to log" button now calls `showLogFoodSheet`; pops back after successful log

**Decisions made:**
- `GET /food-logs` returns both `logs[]` and `totals{}` in one response — avoids a second round trip on screen load
- `deleteFoodLog` uses `deleteMany({ where: { id, userId } })` — implicit 0-count check avoids a separate findFirst; returns 404 if count=0
- Serving unit multipliers kept as simple constants (g=1, cup=240, piece=100) — accurate enough for macro estimation, can be refined per food category later
- After logging, both search and barcode screens `pop()` back to NutritionScreen — the `foodLogsProvider` re-fetches automatically so the list is always fresh

**Known issues:**
- None — full flow verified: search/scan → log sheet → POST → NutritionScreen shows updated totals + meal group

## Previous session
**Date:** 2026-04-09
**What was built:**

### Food search screen
- `features/nutrition/models/food_item.dart` — `FoodItem` model with `fromOpenFoodFactsJson` factory; parses `energy-kcal_100g`, `proteins_100g`, `carbohydrates_100g`, `fat_100g`, `fiber_100g` from Open Food Facts nutriments object
- `core/services/open_food_facts_service.dart` — `OpenFoodFactsService` with `searchByName(query)` (GET `/cgi/search.pl`, 20 results, filters empty product names) and `lookupByBarcode(barcode)` (GET `/api/v0/product/<barcode>.json`, returns null for status≠1); own Dio instance (no auth interceptor); Riverpod `Provider`
- `features/nutrition/providers/nutrition_provider.dart` — `FoodSearchNotifier` (AsyncNotifier: `search` debounced to ≥2 chars, `clear`) and `FoodBarcodeNotifier` (AsyncNotifier: `lookupBarcode`, `reset`)
- `features/nutrition/widgets/food_result_card.dart` — `FoodResultCard`: food image (network + placeholder), name, brand, coloured macro badges (kcal / P / C / F per 100 g), "per 100 g" label
- `features/nutrition/screens/food_search_screen.dart` — `ConsumerStatefulWidget`; AppBar inline search field, 500 ms debounce, clear button, hint/empty/error states, results `ListView`

### Barcode scanner screen
- `features/nutrition/screens/barcode_screen.dart` — `MobileScanner` camera feed; `_ScanOverlay` `CustomPainter` (dim mask + purple corner tick marks); result panel slides up from bottom; torch toggle (local state); `DetectionSpeed.noDuplicates` + `scanner.stop()` on first hit; "Scan again" resets provider and resumes camera; provider reset on `dispose` prevents stale results on re-entry

### Android manifest fixes
- `android/app/src/debug/AndroidManifest.xml` — added `android:usesCleartextTraffic="true"` (required for HTTP to LAN backend in debug), added `CAMERA` permission
- `android/app/src/main/AndroidManifest.xml` — added `INTERNET` and `CAMERA` permissions (were missing entirely from the main manifest)

**End-to-end verified on CPH2401 (OnePlus, Android 14):** login → Nutrition tab → food search (name query returns cards with macros) → barcode scan (physical product found, result card shown, "Scan again" works) ✓

**Decisions made:**
- `OpenFoodFactsService` gets its own Dio instance — it's an unauthenticated third-party API; `ApiClient` is reserved for the FitCore backend only
- Barcode scanner uses `scanner.stop()` on first detect (not just `DetectionSpeed.noDuplicates`) to guarantee no double-lookups after reset
- "Add to log" is a snackbar placeholder on both screens — food-log dialog (serving size → `FoodLog` model → POST backend) deferred to next session as a complete vertical slice
- `CAMERA` permission added to main manifest now so it doesn't need a separate pass before release

**Known issues:**
- Backend must be started manually each session: `cd apps/backend && node_modules/.bin/tsx --env-file=.env src/index.ts`
- "Add to log" on both food search and barcode screens is a placeholder snackbar — food logging not yet wired

## Next session
**Priority task:** Food log dialog (serving size input) + `POST /api/v1/nutrition/logs` backend route + daily macro/calorie summary on NutritionScreen
**Files to look at first:**
- `apps/mobile/lib/features/nutrition/screens/nutrition_screen.dart` — add daily summary (calories consumed vs target, macro bars)
- `apps/mobile/lib/features/nutrition/providers/nutrition_provider.dart` — add `logFood(FoodItem, servingG, mealType)` action
- `apps/backend/src/routes/nutrition.routes.ts` — implement `POST /api/v1/nutrition/logs` and `GET /api/v1/nutrition/logs?date=`

---

## Session history
| Date | Built | Phase |
|---|---|---|
| 2026-04-09 | Bug fixes: swipe-delete persistence (Fastify empty-body parser + confirmDismiss arch), USDA parallel food search for raw foods | Phase 1 |
| 2026-04-09 | Food log screen: LogFoodSheet + MealSection + NutritionScreen + backend POST/GET/DELETE /food-logs | Phase 1 |
| 2026-04-09 | Food search (Open Food Facts), barcode scanner (mobile_scanner), FoodResultCard, Android manifest fixes | Phase 1 |
| 2026-04-09 | Onboarding flow (3 screens + backend profile endpoint + TDEE calc), Settings screen, Logout | Phase 1 |
| 2026-04-08 | Auth flow: signup/login/refresh/logout backend + Flutter screens + GoRouter auth guard | Phase 1 |
| 2026-04-08 | Migration fix: auth columns, seed passwords, TS config, smoke tests | Phase 1 |
| 2026-04-08 | Prisma setup, initial migration, seed data | Phase 1 setup |
| 2026-04-08 | Full monorepo scaffold, all skeleton files | Phase 1 setup |

---

## Previous sessions

### Flutter scaffold session (2026-04-08)

**What was built:**
- `apps/mobile/` Flutter 3.41.3 project created (platforms: Android, iOS)
- `pubspec.yaml` — all locked deps: go_router 14, flutter_riverpod 2, flutter_animate, fl_chart, drift 2, flutter_secure_storage, flutter_form_builder 10, dio 5, mobile_scanner, health 12, firebase_messaging, google_mlkit, logger, flutter_dotenv, image_picker, cached_network_image + all dev/codegen deps
- Full folder structure from CLAUDE.md spec: features/{auth,onboarding,home,nutrition,workout,progress,social,coach,wellness,settings}/{screens,widgets,providers}, core/{api,db,services,theme,widgets,utils}, router/, constants/, test/core/utils/
- `lib/router/app_router.dart` — GoRouter with every route wired: auth (login, signup, forgot-password), onboarding (3 steps), ShellRoute with 5-tab bottom nav (home, nutrition, workout, progress, social) + sub-routes for each, plus coach, wellness, settings as top-level routes
- `lib/router/main_shell.dart` — BottomNavigationBar shell
- `lib/app.dart` — ConsumerWidget MaterialApp.router with AppTheme.dark
- `lib/main.dart` — ProviderScope + dotenv bootstrap
- `lib/core/theme/` — app_theme.dart (dark Material 3 theme), app_colors.dart, app_text_styles.dart
- `lib/constants/app_routes.dart` — all route path constants
- 17 placeholder screens — every route renders a labelled scaffold, buttons navigate to next route
- `lib/core/api/api_client.dart` — Dio instance wired to FLUTTER_API_URL from .env
- `lib/core/api/api_response.dart` — typed ApiResponse<T> envelope
- `lib/core/widgets/` — AppButton (3 variants), AppInput, AppCard
- `lib/core/services/` — HealthService stub, CoachService stub (Riverpod provider)
- `lib/core/utils/calorie_calculator.dart` — Mifflin-St Jeor BMR/TDEE/goal-adjustment (all CLAUDE.md rules)
- `lib/core/utils/macro_calculator.dart` — macro splits by goal
- `lib/core/utils/streak_calculator.dart` — streak + grace-period logic
- `test/core/utils/calorie_calculator_test.dart` — 6 tests, all pass
- `test/core/utils/streak_calculator_test.dart` — 7 tests, all pass
- `flutter analyze` — no issues
- `flutter pub get` — 155 packages resolved

**Decisions made:**
- Flutter 3.41.3 (stable channel) — newer than CLAUDE.md minimum of 3.22+, compatible
- GoRouter ShellRoute for bottom nav tab persistence (sub-routes stay inside shell)
- AppTheme.dark as the single theme for now; light mode can be added later
- health ^12.x.x (bumped from spec's 10.x — intl constraint from flutter_localizations forced it)
- form_builder_validators ^11.1.2 (bumped — same intl conflict)
- flutter_form_builder ^10.3.0 (bumped — same intl conflict)
- BMR formula verified: male 80kg/180cm/30yo = 1780 kcal (corrected test that had wrong expectation)
- Streak grace: grace day is still a qualifying day (increments streak) — preserves chain of 3 qualifying days = streak 3

**What's broken / known issues:**
- Widget smoke test (`test/widget_test.dart`) uses GoRouter which needs a real MaterialApp — currently just checks ProviderScope exists (no navigation tested yet)
- `firebase_core` and `firebase_messaging` need `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) before FCM works
- Drift codegen not run yet (`build_runner`) — no DB tables generated
- No auth state guard on GoRouter yet — all routes are freely accessible (implement after auth screens are built)

## Last session (Flutter auth slice)
**Date:** 2026-04-08

**End-to-end verified:** Signed up on CPH2401 (OnePlus), user appeared in PostgreSQL, JWT stored, GoRouter redirected to tab shell — all tabs visible. ✓

**What was built:**
- `lib/features/auth/models/auth_state.dart` — `UserDto` (mirrors backend DTO) + `AuthState` (user + in-memory access token)
- `lib/core/api/token_store.dart` — `accessTokenProvider` (StateProvider<String?>) — access token lives only in Riverpod memory
- `lib/features/auth/providers/auth_provider.dart` — `AuthNotifier` (AsyncNotifier): `login`, `signup`, `logout`, `refreshSession`, `_tryRestoreSession` (reads refresh token from SecureStorage on startup and auto-refreshes)
- `lib/core/api/api_client.dart` — `ApiClient` upgraded: `_AuthInterceptor` injects Bearer on every request; on 401 calls `refreshSession`, retries original request with new token; on failure calls `logout`
- `lib/router/router_notifier.dart` — `RouterNotifier` (ChangeNotifier): bridges `authProvider` into GoRouter `refreshListenable`; redirect logic: unauthenticated → `/login`, authenticated on auth route → `/home`
- `lib/router/app_router.dart` — replaced static `GoRouter` with `appRouterProvider` (Riverpod `Provider<GoRouter>`), wired `RouterNotifier`
- `lib/app.dart` — now consumes `appRouterProvider` via `ref.watch`
- `lib/features/auth/screens/login_screen.dart` — real form: `FormBuilder` with email + password fields, `FormBuilderValidators`, error snackbar from auth state, calls `authProvider.notifier.login`
- `lib/features/auth/screens/signup_screen.dart` — real form: name + email + password + confirm-password fields, password match validator, calls `authProvider.notifier.signup`
- `flutter analyze` — no issues

**Decisions made:**
- Refresh token stored in `flutter_secure_storage` under key `refresh_token`; access token lives only in `accessTokenProvider` (Riverpod memory, cleared on app restart)
- `RouterNotifier` + `refreshListenable` pattern — GoRouter re-evaluates redirect on every auth state change; no manual `context.go` calls from providers
- `AuthNotifier` uses its own plain `Dio` instance (no auth interceptor) to avoid circular dependency with `ApiClient`

## Last session (Onboarding flow)
**Date:** 2026-04-09

**End-to-end flow:** signup → goal selection → body stats → activity level → POST /api/v1/user/profile → router redirects to /home ✓

**What was built:**

### Shared
- `packages/shared/src/types/index.ts` — added `hasProfile: boolean` to `UserDto`

### Backend
- `src/repositories/user.repository.ts` — all finders now include `profile` relation so `hasProfile` is always accurate; added `upsertProfile`, `createBodyStat`, `updateStats`
- `src/services/auth.service.ts` — `toUserDto` accepts `Prisma.UserGetPayload<{ include: { profile: true } }>`, sets `hasProfile: user.profile !== null`
- `src/routes/user.routes.ts` — implemented `GET /api/v1/user/profile` + `POST /api/v1/user/profile`; server-side Mifflin-St Jeor TDEE calc; Prisma transaction updates User + upserts UserProfile + creates initial BodyStat atomically; Zod validation

### Flutter
- `features/auth/models/auth_state.dart` — `UserDto` gains `hasProfile` field + `copyWith`
- `features/auth/providers/auth_provider.dart` — `markProfileComplete()` flips `hasProfile` in memory and triggers router redirect
- `features/onboarding/models/onboarding_state.dart` — `OnboardingData` accumulates goal + body stats across screens
- `features/onboarding/providers/onboarding_provider.dart` — `OnboardingNotifier`: `setGoal`, `setBodyStats`, `submit(activityLevel)` → POST → `markProfileComplete()`
- `features/onboarding/screens/goal_selection_screen.dart` — 4 animated goal cards; step indicator (1/3)
- `features/onboarding/screens/body_stats_screen.dart` — height/weight text fields, date picker, gender dropdown; full validation
- `features/onboarding/screens/activity_level_screen.dart` — 5 animated level cards; loading state; error display; calls `submit()`
- `router/router_notifier.dart` — redirect logic: unauthenticated → login; authenticated + auth route → onboarding (no profile) or home (has profile); authenticated + no profile + non-onboarding route → goalSelection; authenticated + has profile + onboarding route → home

**Decisions made:**
- `hasProfile` lives in `UserDto` (not a separate provider) — auth state is the single source of truth for routing decisions
- `markProfileComplete()` mutates in-memory auth state (no re-fetch) so the router fires instantly after POST succeeds
- Backend uses Prisma transaction for atomic profile creation (User update + UserProfile upsert + BodyStat create)
- Gender 'other'/'prefer_not_to_say' uses the female BMR formula (conservative; common convention)
- Onboarding uses `context.go()` not `context.push()` — no back-stack; Back buttons use explicit `context.go(prevRoute)`

**What's broken / known issues:**
- None — onboarding flow is complete

## Next session
**Priority task:** Home dashboard (calorie ring, macro bars, steps, water, streak card)
**Files to look at first:**
- `apps/mobile/lib/features/home/screens/home_screen.dart`
- `apps/mobile/lib/router/main_shell.dart`

---

## Mini-session (Settings + Logout)
**Date:** 2026-04-09

**What was built:**
- `features/home/screens/home_screen.dart` — added ⚙ settings icon in AppBar → navigates to `/settings`
- `features/settings/screens/settings_screen.dart` — shows user avatar initial + name + email; Log Out button (red) with confirmation dialog; logout calls `authProvider.notifier.logout()` → `RouterNotifier` redirects to `/login`
- Fixed backend `dev` script: `tsx watch --env-file=.env src/index.ts` (flag order was wrong for tsx v4)
- Root cause of test-14 404: backend was running the old code (no `POST /profile` route) — restarted server fixed it

## Previous session
**Date:** 2026-04-08
**Duration:** Auth flow session

**What was built (auth):**

### Backend
- Prisma schema: added `passwordHash`, `refreshTokenHash`, `refreshTokenExpiresAt` to `User` model
- `src/utils/db.ts` — Prisma singleton
- `src/repositories/user.repository.ts` — `findByEmail`, `findById`, `create`, `setRefreshToken`
- `src/services/auth.service.ts` — scrypt password hashing, opaque refresh token gen/decode/hash, `toUserDto`
- `src/routes/auth.routes.ts` — full `POST /signup`, `/login`, `/refresh`, `/logout` with Zod
- `src/index.ts` — registered `@fastify/jwt` plugin

### Mobile
- `services/auth.service.ts` — `signup`, `login`, `logout`, `initAuth` (SecureStore + Zustand)
- `stores/auth.store.ts` — added `userName`
- `components/ui/Button.tsx` — styled with NativeWind, loading spinner, 3 variants
- `components/ui/Input.tsx` — styled with NativeWind, label + error
- `app/(auth)/signup.tsx` — React Hook Form + Zod, name/email/password
- `app/(auth)/login.tsx` — React Hook Form + Zod, email/password
- `app/_layout.tsx` — `initAuth` on mount, `AuthGuard` redirect logic
- `app/(tabs)/home/index.tsx` — shows `userName` from auth store

**Decisions made:**
- Refresh tokens are opaque random bytes (not JWTs), stored hashed in DB — easier to revoke, no secret leakage
- Refresh token format encodes userId in a base64url prefix (avoid full-table scan on refresh)
- Refresh token rotation on every `/refresh` — old token immediately invalidated
- Node.js built-in `crypto.scrypt` for password hashing (no extra dep, NIST-recommended)

**What's broken / known issues:**
- Must run `yarn workspace @fitcore/backend db:migrate dev` + `db:generate` for new Prisma fields
- `EXPO_PUBLIC_API_URL` must be set in `apps/mobile/.env` (defaults to `http://localhost:3000`)
- `config.ts` requires all env vars — stub `ANTHROPIC_API_KEY=sk-ant-stub`, `STRIPE_SECRET_KEY=sk_test_stub`, etc. for local dev

---

## Previous session
**Date:** 2026-04-08
**Duration:** ~1 hour
**What was built:**
- Prisma 5 connected to PostgreSQL (`fitcore` database at localhost:5432)
- Migration `20260408000000_init` — all 9 tables created (User, UserProfile, FoodLog, WorkoutLog, ExerciseSet, BodyStat, Goal, Subscription, Friendship)
- Seed file at `prisma/seed.ts` — 3 test users, 18 food logs, 3 workout logs, 22 exercise sets
- Fixed: `@types/react-native` removed from mobile (deprecated in RN 0.74+); mobile excluded from root workspace temporarily
- Note: DB password contains `@`, stored URL-encoded as `%40` in `.env`

---

**Previous session built:**
- Full monorepo scaffold (yarn workspaces: apps/mobile, apps/backend, packages/shared)
- Root `package.json`, `.gitignore`
- **Mobile (apps/mobile):**
  - `package.json` with all locked dependencies
  - `tsconfig.json` (strict mode, path aliases)
  - `app.json` (Expo SDK 51, iOS/Android permissions, EAS config)
  - `babel.config.js`, `tailwind.config.js`
  - All Expo Router screen stubs: `(auth)/`, `(tabs)/home|nutrition|workout|progress|social`, `coach/`, `wellness/`, `settings/`
  - All 4 Zustand stores: `auth`, `user`, `nutrition`, `workout`
  - `services/api.ts` — Axios instance with auth + refresh-token interceptors
  - `services/claude.ts`, `health-kit.ts`, `google-fit.ts` stubs
  - `constants/index.ts` — colours, fonts, route constants, enums
  - `utils/calories.ts` — BMR / TDEE / goal adjustment logic
  - `utils/macros.ts` — macro target calculator
  - `utils/streak.ts` — streak + grace-period logic
  - `components/ui/` — Button, Card, Input stubs
  - `components/nutrition/` — FoodCard, MacroBar stubs
  - `components/workout/` — ExerciseCard, SetLogger, RestTimer stubs
  - `components/charts/` — CalorieChart, StrengthCurve stubs
  - `components/social/` — FeedCard stub
  - `db/schema.ts` — WatermelonDB schema (food_logs, workout_logs, exercise_sets, body_stats)
  - `db/index.ts` — Database instance
- **Backend (apps/backend):**
  - `package.json`, `tsconfig.json`
  - `.env.example` with all required vars
  - `src/utils/config.ts` — Zod-validated env config (exits on bad env)
  - `src/index.ts` — Fastify server bootstrap with all route prefixes
  - All 6 route files (501 stubs): auth, user, nutrition, workout, ai, social
  - `prisma/schema.prisma` — full DB schema matching CLAUDE.md spec
  - Empty placeholder dirs: services/, repositories/, jobs/, plugins/, middleware/, migrations/
- **Shared (packages/shared):**
  - `package.json`, `tsconfig.json`
  - `src/types/index.ts` — all DTOs, enums, ApiResponse envelope, CoachContext

**Decisions made:**
- None new — followed CLAUDE.md spec exactly

**What's broken / known issues:**
- No `assets/` folder yet (app.json references icon, splash, notification-icon)
- `expo-env.d.ts` not generated yet (run `expo start` to auto-generate)
- `db/index.ts` has `modelClasses: []` — will be populated as models are built

---

## Last session
**Date:** 2026-04-08
**Duration:** Migration fix session

**What was done:**
- Fixed migration `20260408000000_init` — added `passwordHash`, `refreshTokenHash`, `refreshTokenExpiresAt` columns to User table (were missing from initial SQL)
- Updated `prisma/seed.ts` — imports `hashPassword` from auth.service, pre-computes scrypt hashes for all 3 test users (all use `Password123!`)
- Ran `prisma migrate reset --force` — DB reset, migration re-applied, seed successful (3 users, 18 food logs, 3 workout logs, 22 exercise sets)
- Fixed `tsconfig.json` — changed `rootDir` from `src` to `../..` to allow `@fitcore/shared` imports without TS6059 error
- Removed dead `issueTokens` helper from `auth.routes.ts` (had a wrong type annotation, was never called)
- Fixed `package.json` dev script — added `--env-file=.env` to `tsx` so env vars load in dev
- Full auth flow smoke tested end-to-end: signup (201), login (200), token refresh (200 + rotation), logout (200), duplicate email (409), wrong password (401) — all pass

**Decisions made:**
- `rootDir: "../.."` in backend tsconfig to accommodate monorepo shared package imports
- Seed uses `Password123!` as the test password for all seed users

**What's broken / known issues:**
- None currently — auth flow is fully functional and DB is seeded

## Next session
**Priority task:** Onboarding flow (goal selection, body stats, activity level) — route from signup → onboarding → tabs
**Files to look at first:**
- `apps/mobile/app/(auth)/onboarding.tsx`
- `apps/backend/src/routes/user.routes.ts`
- `apps/backend/prisma/schema.prisma` (UserProfile model)

## Session history
| Date | Built | Phase |
|---|---|---|
| 2026-04-08 | Full monorepo scaffold, all skeleton files | Phase 1 setup |
| 2026-04-08 | Prisma setup, initial migration, seed data | Phase 1 setup |
| 2026-04-08 | Auth flow: signup/login/refresh/logout backend + mobile screens + auth guard | Phase 1 |
| 2026-04-08 | Migration fix: auth columns, seed passwords, TS config, dev script, smoke tests | Phase 1 |
