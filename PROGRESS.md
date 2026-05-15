# Zenfit — Build Progress

## Last session
**Date:** 2026-05-15 (session 35)
**Duration:** ~0.5 hours
**What was built:**

### Launch prep — version bump, iOS permissions, Privacy Policy

- **Version bumped** — `pubspec.yaml` updated from `1.0.0-beta.1+1` → `1.0.0+1`
- **iOS permission strings added** — `Info.plist` now includes all four missing keys required for App Store approval: `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription`. Without these the app is auto-rejected during App Review.
- **`indian_foods.json` audit** — confirmed already deleted from disk in a prior session; only a stale inline comment remained in `indian_food_service.dart` (no code change needed).
- **Breakfast/lunch notification toggles audit** — confirmed already fully implemented (provider, prefs keys, UI, schedule wiring). The known issue in session 34 was resolved before this session.
- **Privacy Policy created** — `docs/privacy-policy.html` covers: account & health data collection, Apple Health / Google Fit data table, AI processing via Gemini, AdMob consent, Firebase/Sentry/Amplitude, Google Cloud infrastructure, GDPR/CCPA rights, data retention (30-day deletion), data security (TLS + AES-256 + Keychain/Keystore). Hosted via GitHub Pages at `https://Easwar03-cmd.github.io/[repo]/privacy-policy.html`.

**Decisions made:**
- Stripe backend code is kept intact for future use; Google Play Billing is the active payment path for launch.
- `docs/` folder serves GitHub Pages — no extra hosting cost; URL to give both stores: `https://Easwar03-cmd.github.io/[repo]/privacy-policy.html` (replace `[repo]` with the actual repo name after enabling Pages in Settings → Pages → Branch: main, Folder: /docs).

**Known issues / next steps:**
- Enable GitHub Pages in the repo settings (Settings → Pages → main branch, /docs folder) to make the privacy policy URL live.
- Create a `privacy@revivefit.app` and `support@revivefit.app` email address (or redirect to your personal email) before going live.
- HealthKit entitlement must be enabled in Xcode under Signing & Capabilities → HealthKit.
- App Store / Play Store screenshots still need to be created.
- Play Store Data Safety form needs to be filled out (mirrors the privacy policy content).

## Previous session
**Date:** 2026-04-24 (session 33)
**Duration:** ~3 hours
**What was built:**

### AI Exercise Form Monitor — major rework & stability pass

The form monitor shipped in session 31 had three critical bugs that were fully fixed and then improved further this session.

**Bug fixes**
- **Skeleton coordinate transform** — ML Kit returns landmarks already in the display-oriented (post-rotation) coordinate space, not raw sensor space. The old code re-applied the rotation on top, double-transforming everything and pushing the skeleton off-screen. Rewrote `PoseOverlayPainter._toScreen` to use the correct per-rotation axis flip (`srcW - lmX` for `rotation270deg`, which is standard for CPH2401 / OPPO front cameras) followed by the FittedBox.cover scale + crop offset so dots land exactly on the user's joints.
- **Always-green badge** — Two root causes: (1) `copyWith(currentPose: null)` silently no-ops because Dart's `??` can't clear to null — fixed with a `clearPose: bool` sentinel. (2) `PoseAnalyzer` was returning `PoseFeedback.good` for every "not-in-position" early exit. Fixed by adding `FeedbackLevel.none` + `PoseFeedback.noPose` / `PoseFeedback.ready` states.
- **Exercise chip text invisible** — `Colors.white12` background with `fontSize: 12` was near-invisible. Changed to `Color(0xFF374151)` background, solid blue selected state, white text, explicit border.

**Stability improvements**
- `PoseSmoother` service (new) — exponential moving average (α=0.5) applied to all 33 landmark positions every frame; eliminates per-frame jitter without adding perceptible lag at 6fps
- 2-frame feedback debouncing in `ExerciseMonitorNotifier` — feedback must be identical for 2 consecutive frames before the UI updates; prevents single-frame glitches from flashing on screen
- Frame rate raised from 4fps (250ms) → 6.7fps (150ms) for smoother real-time tracking
- Full-body skeleton: added nose → shoulder head connections, ankle → foot index leg extensions, dark halo under every bone so skeleton is visible on both light and dark backgrounds

**Phase-based rep counter**
- Replaced fragile "good-frame streak → non-good frame" heuristic with a proper movement phase detector in `ExerciseMonitorNotifier._updateRepCount`
- Each exercise has a `RepThresholds(bottom, top)` in `kRepThresholds`; a rep is only counted when the primary angle crosses the bottom threshold (depth) and then returns past the top threshold (standing)
- Primary angle extracted via `PoseAnalyzer.primaryAngle()` — knee angle for squat/lunge, elbow angle for push-up/OHP/bicep curl/pull-up, shoulder–hip–knee for deadlift/RDL
- Plank has no rep counting (hold exercise)

**Exercise-specific engagement detection**
- Every exercise now has an explicit "are you actually doing this?" check at the top of its analyzer method; returns `PoseFeedback.ready` (gray, "Get into position") when the user is standing idle
- Bicep Curl: arms fully straight (elbow >160°) → "Start curling — bend your elbows"; only analyses elbow drift + ROM when actually curling
- Pull-up: wrists below shoulder level → "Hang from the bar to start"; only analyses swing + chin-above-bar when actually hanging
- Deadlift / Romanian DL: shoulder–hip y-gap too large (upright posture) → "Hinge at the hips to start"; checks flat back only when in the hinge
- Push-up: body too vertical (vertSpan > horizSpan × 1.2) → "Get on the floor — face down"
- Plank: same horizontal body check → "Get into plank position"
- Squat, Lunge, OHP: already had correct engagement gates (knee angle / wrist position)

**Additional form checks added**
- Squat: knee valgus detection ("Push knees out"), depth nudge ("Squat deeper" if knee >130°)
- Bicep curl: full extension check at bottom ("Fully extend arms at the bottom"), full contraction at top
- Pull-up: dead hang extension check
- Deadlift: hip drive cue ("Drive hips forward") when shoulder–hip–knee angle over-acute
- Both sides of the body used wherever both are visible; falls back to more visible side

**Files added / changed**
- `lib/features/workout/services/pose_smoother.dart` — new EMA smoothing service
- `lib/features/workout/services/pose_analyzer.dart` — engagement detection + bilateral angles + improved thresholds
- `lib/features/workout/providers/exercise_monitor_provider.dart` — smoother, debouncing, phase-based rep counter, `clearPose` sentinel
- `lib/features/workout/widgets/pose_overlay_painter.dart` — correct coordinate transform, full skeleton, halo
- `lib/features/workout/widgets/form_feedback_card.dart` — handles `FeedbackLevel.none`
- `lib/features/workout/models/pose_feedback.dart` — added `none` level, `noPose` + `ready` constants
- `lib/features/workout/screens/exercise_monitor_screen.dart` — chip styling, "step into frame" placeholder, 150ms frame rate

**Decisions made**
- EMA α=0.5: fast enough to track real movement at 6fps, smooth enough to eliminate jitter. Could be tuned lower (smoother) if certain phones show landmark noise; do not go above 0.6 or tracking lags behind fast movements.
- FeedbackLevel.none used for both "no person detected" and "person detected but not in position" — same gray styling, different messages. This avoids adding a fourth enum value and keeps the visual language simple (two states: informational gray vs active green/amber).
- Engagement thresholds (e.g. hipMidY − shMidY > shWidth × 1.7 for deadlift) calibrated for a front-facing phone camera. These may need tuning if users report false "Get into position" messages while mid-rep — adjust the multiplier in `pose_analyzer.dart`.
- Per-exercise `RepThresholds` stored as a const map in `pose_analyzer.dart` so they're easy to tune without touching provider logic.

**Known issues**
- Plank and push-up engagement detection relies on the body being horizontal in the camera frame. If the phone is propped directly in front of the user (face-on view), the body appears foreshortened and the horizSpan check may not work well. Works best from a side-profile camera angle.
- Deadlift hip-hinge engagement uses the shoulder–hip y-gap as a proxy for forward lean, which is a front-camera approximation. From a strict front-facing view, forward lean (depth change) is invisible; the y-gap proxy works but the threshold may feel slightly late for users with long torsos. Consider relaxing `1.7` to `1.5` if users report it never entering analysis mode.
- Pull-up wrist-above-shoulder gate is strict: both wrists must be above both shoulders. Users with asymmetric bar grips may see "Hang from the bar" flash on one side. If this is reported, change to "either wrist above either shoulder".

---

## Previous session
**Date:** 2026-04-25 (session 34)
**Duration:** ~2.5 hours
**What was built:**

### Multi-cuisine food database
- Replaced `assets/data/indian_foods.json` with `assets/data/local_foods.json` — ~280 clean-named items across 12 categories: Indian (35), American (20), Italian (15), Chinese (16), Fruits (20), Vegetables (18), Proteins/Meat (10), Dairy & Eggs (11), Grains (9), Beverages (18), Nuts & Seeds (10), Snacks (8)
- All names are consumer-friendly ("Boiled Egg", "Chicken Breast (Cooked)") — no USDA comma-reversal style
- Added `isLiquid` flag to `FoodItem` model and new `fromLocalJson` factory; updated `IndianFoodService` to load the new file
- USDA name normalizer added to `FoodItem.fromUsdaJson`: inverts "Egg, boiled" → "Boiled Egg", strips category prefixes like "Beverages,", caps long descriptions to 2 meaningful parts
- `ml` unit added to `log_food_sheet.dart` for liquids (1ml = 1g for beverage calorie calculation); liquid foods default to `ml` unit + 250 starting amount; solids keep `g/cup/piece`
- Quick-select serving chips now appear for any food with `commonServings` — previously only Indian foods got chips

### Delete logged foods
- Collapsed chip row: added × button on every `_FoodChip` widget (triggers confirm dialog → deleteLog + removeLogLocally)
- Expanded row: added visible trash `IconButton` on every `_LogItem` row, in addition to the existing swipe-to-delete gesture

### Water persistence bug fix
- **Root cause**: in `HomeDashboardNotifier._loadState()`, `_userId` was evaluated via `ref.read(authProvider)` *after* `await profileFuture` — an async gap of ~300ms. During cold start, `authProvider` is still `AsyncLoading` at that point, so `valueOrNull` is `null` → uid falls back to `'anonymous'` → water is read from `water_ml_anonymous_YYYY-MM-DD` (always 0)
- **Fix**: capture `userId` synchronously at the top of `build()` from `ref.watch(authProvider).valueOrNull?.user.id` before any async work begins. Pass it as a parameter to `_loadState(userId:)` so there is no re-read mid-flight

### Breakfast and lunch notifications
- Added `scheduleBreakfastReminder()` (8:00 AM) and `scheduleLunchReminder()` (1:00 PM) to `NotificationService`
- Notification IDs 13 and 14 reserved
- Both wired into `restoreSchedules()` reading prefs keys `notif_breakfast_enabled` (default true) and `notif_lunch_enabled` (default true)
- Breakfast copy: "Good morning! Log your breakfast 🍳"; Lunch copy: "Lunchtime! Don't forget to log 🥗"

**Decisions made**
- Local food database replaces the old 150-item Indian-only JSON. The new file still loads through the same `IndianFoodService` / `openFoodFactsServiceProvider` stack (no provider renaming) to avoid breaking existing call sites. The service class name `IndianFoodService` is now a misnomer but harmless — rename in a future session if it creates confusion.
- `isLiquid` flag on FoodItem is the single source of truth for whether to show ml/cup vs g/cup/piece in the log sheet. Beverages in the local DB all have `isLiquid: true`; items from USDA/OFF never set it (defaults false), so those always show g-based units.
- Water key capture in `build()` rather than inside `_loadState()` is the canonical pattern going forward for any user-scoped prefs that must be read mid-async. Added comment explaining the reason so future contributors don't "simplify" it back.

**Known issues**
- `notif_breakfast_enabled` and `notif_lunch_enabled` prefs are not yet surfaced in the Profile → Notifications settings UI. The notifications fire by default (true) but the user has no in-app toggle to disable them. Add toggles to the notifications settings screen next session.
- The old `assets/data/indian_foods.json` file still exists in the repo (not deleted). It is no longer loaded by any code but wastes ~15 KB in the APK. Safe to delete next session.
- USDA name normalization handles most cases well but some multi-part names still produce awkward output (e.g. "Chicken (Broilers or Fryers, Breast)"). The normalizer is good enough for now; a proper title-case + stopword pass can improve it later.

---

## Session 33
**Date:** 2026-04-24
**Duration:** ~2 hours
**What was built:**

### GCP Cloud Run deployment (infrastructure migration from Railway)

**GCP resources provisioned**
- Cloud Run service `zenfit-api` — `us-central1`, 0–20 instances, auto-scale, WebSocket support
- Cloud SQL PostgreSQL 15 — `zenfit-db`, `db-f1-micro`, 10 GB SSD, daily backups at 03:00
- Upstash Redis — free tier, replaces Railway Redis (no VPC required, connects via URL)
- Artifact Registry — `us-central1-docker.pkg.dev/.../zenfit/zenfit-api`
- Secret Manager — 12 secrets (DATABASE_URL, JWT keys, Stripe, Gemini, Cloudinary, Firebase, USDA)
- Cloud Build trigger — auto-deploys on every push to `main` via `cloudbuild.yaml`

**New files**
- `cloudbuild.yaml` — 4-step pipeline: docker build → push SHA tag → push latest tag → gcloud run deploy
- `.dockerignore` — excludes mobile app, node_modules, env files from build context
- `gcp-setup.sh` — one-time provisioning script (for reference/re-use)

**Fixes made during deployment**
- `apps/backend/package.json` — corrected `start` script path to `dist/apps/backend/src/index.js` (was `dist/index.js`, wrong due to tsconfig `rootDir: ../..`)
- Cloud SQL DATABASE_URL format: needed `@localhost/dbname?host=/cloudsql/CONNECTION_NAME` not `@/dbname?host=...` (Prisma rejects empty host)
- Cloud Build max-instances capped at 20 (free-tier quota limit is 20 CPUs per region)
- Cloud Build trigger uses Compute SA (`122167595419-compute@...`), not Cloud Build SA — granted `artifactregistry.writer`, `run.admin`, `iam.serviceAccountUser` to that SA

**Railway remnants removed**
- `apps/backend/src/routes/payments.routes.ts` — hardcoded `BASE_URL` was Railway URL; updated to GCP URL (affected Stripe checkout success/cancel redirects)
- `apps/mobile/lib/constants/app_constants.dart` — compile-time fallback `defaultValue` was Railway URL; updated to GCP URL
- `apps/mobile/lib/core/api/api_client.dart` — stale comment updated

**Data migration**
- Exported all data from local PostgreSQL 18 (`fitcore` db) via `pg_dump --data-only`
- Imported into Cloud SQL — all 11 users (incl. `easwarnani098@gmail.com`), food logs, workout logs, body stats, goals, subscriptions migrated
- Two tables missing from GCP schema (`MoodLog`, `WearableConnection`) — import errors for those rows only, all core tables clean
- Flutter mobile `.env` and `app_constants.dart` fallback updated to GCP URL so debug builds connect to production

**Decisions made**
- Chose Upstash Redis over GCP Memorystore — free tier available, no VPC connector needed, simpler for solo dev; switch to Memorystore only if Redis latency becomes a bottleneck at scale
- Cloud SQL public IP authorized temporarily for data import, revoked immediately after
- Max instances set to 20 (free-tier quota); request quota increase before launch if traffic warrants it

**Known issues**
- `MoodLog` and `WearableConnection` tables don't exist in GCP schema — these appear to be in local DB only (not in Prisma migrations). If these features are needed, add a migration
- Gemini API key in `.env` is still a placeholder — only matters for local backend dev; production uses Secret Manager
- Stripe keys in `.env` are test keys — fine for now, swap for live keys before App Store launch

---

## Previous session
**Date:** 2026-04-23 (session 31)
**Duration:** ~1.5 hours
**What was built:**

### AI Exercise Form Monitor (Phase 3 — fully on-device)

**New packages**
- `google_mlkit_pose_detection: ^0.13.0` — on-device BlazePose landmark detection (33 body points)
- `camera: ^0.11.0` — live camera feed with `startImageStream` for per-frame processing

**New files**
- `features/workout/models/pose_feedback.dart` — `PoseFeedback` model with `good / warn / error` level enum
- `features/workout/services/pose_analyzer.dart` — static angle-based form rules for 9 exercises; `kMonitorableExercises` and `kMonitorableNames` constants
- `features/workout/widgets/pose_overlay_painter.dart` — `CustomPainter` that draws the skeleton (lines + dots) coloured green/amber based on feedback level; handles image-to-screen coordinate transform accounting for rotation and front-camera mirror
- `features/workout/widgets/form_feedback_card.dart` — animated floating card at screen bottom; green checkmark for good form, amber with cue text for corrections; shows rep count
- `features/workout/providers/exercise_monitor_provider.dart` — `StateNotifier` (`exerciseMonitorProvider`, autoDispose); owns `PoseDetector`; receives ready `InputImage` from screen; runs detection, calls `PoseAnalyzer`, manages rep counter and state
- `features/workout/screens/exercise_monitor_screen.dart` — `ConsumerStatefulWidget`; owns `CameraController`; handles camera init (front-camera default), image format selection, per-frame rotation computation, 250 ms throttle; exercise chip selector; camera switch button

**Modified files (additive only — no existing logic touched)**
- `pubspec.yaml` — two new packages
- `constants/app_routes.dart` — `exerciseMonitor = '/workout/monitor'`
- `router/app_router.dart` — `GoRoute` for `/workout/monitor`
- `features/workout/screens/workout_screen.dart` — "AI Form Monitor" card (green, `Icons.visibility_rounded`)

**Supported exercises and checks**
| Exercise | What is checked |
|---|---|
| Squat | Knee angle + torso lean (>50° = "Keep chest up") |
| Lunge | Front knee angle + torso lean (>20° = "Keep torso upright") |
| Push-Up | Shoulder–hip–ankle body line (<155° = "Keep body straight") |
| Plank | Shoulder–hip–ankle body line (<160° = "Lower/Raise your hips") |
| Deadlift / Romanian DL | Ear–shoulder–hip back angle (<150° = "Keep back straight") |
| Overhead Press | Elbow extension at top (<140° = "Extend arms fully"); torso arch |
| Bicep Curl | Elbow drift vs shoulder width (>60% = "Keep elbows close to sides") |
| Pull-Up | Body vertical lean + elbow angle at top |

**Decisions made**
- Image conversion (CameraImage → InputImage) lives in the screen, not the provider — the screen owns the camera controller and device orientation, both needed for correct rotation maths; the provider receives a ready `InputImage` and stays focused on detection + state
- Android must use `ImageFormatGroup.nv21`; iOS uses `bgra8888` — these are the only two formats ML Kit accepts; YUV_420_888 (the default) is silently rejected, which was the root cause of the initial "always Great form / no skeleton" bug
- Rotation on Android = `(sensorOrientation + deviceOrientationDeg) % 360` for front camera, `(sensorOrientation - deviceOrientationDeg + 360) % 360` for back — raw sensor orientation alone was the second bug
- Rep counter: increments when transitioning from ≥5 consecutive good-form frames back to a correction frame (one full range of motion ≈ one rep)
- No subscription gate — feature is free to all tiers; it runs fully on-device with zero API cost

**Known issues**
- Detection quality degrades in low light or against a cluttered background (ML Kit limitation)
- Skeleton overlay alignment can be slightly off on devices with unusual sensor orientations — cosmetic only, feedback logic is unaffected
- Exercises performed at an angle to the camera (e.g. side-on deadlift) will have lower landmark confidence and may produce less accurate cues

---

## Previous session
**Date:** 2026-04-22 (session 30)
**Duration:** ~2 hours
**What was built:**

### Stripe subscription integration (Phase 4)

**Backend — `payments.routes.ts`**
- `GET /api/v1/payments/subscription` — returns current tier + validUntil for the authenticated user
- `POST /api/v1/payments/checkout` — creates a Stripe Checkout Session for `pro` or `coach` tier; creates a Stripe Customer on first checkout and stores `stripeCustomerId` on the Subscription row
- `POST /api/v1/payments/portal` — creates a Stripe Billing Portal session so paid users can change plan, update payment method, or cancel
- `POST /api/v1/payments/webhook` — verifies Stripe signature using raw body (saved in global content-type parser); handles `checkout.session.completed`, `customer.subscription.updated`, `customer.subscription.deleted`, `invoice.payment_failed`
- `/payment/success` and `/payment/cancel` — HTML landing pages served from Railway so Stripe has valid redirect URLs after checkout
- `GET /ai/analyze-food-photo` now returns `403 UPGRADE_REQUIRED` for free-tier users (was open to all)

**Prisma**
- Added `stripeCustomerId String? @unique` and `stripePriceId String?` to `Subscription` model
- Migration `20260421000000_add_stripe_subscription_fields` runs on Railway deploy via `prisma migrate deploy`
- `config.ts` accepts optional `STRIPE_PRO_PRICE_ID` and `STRIPE_COACH_PRICE_ID` env vars

**Flutter**
- `SubscriptionInfo` model with `isPro`, `isCoach`, `isPaid` helpers and `validUntil` expiry check
- `SubscriptionNotifier` (Riverpod `AsyncNotifier`) — fetches status on build, exposes `createCheckoutUrl`, `createPortalUrl`, `refresh`; rebuilds on auth change
- `PaywallScreen` — Free / Pro / Coach tier cards with feature comparison list and upgrade CTAs; shows locked-feature banner when navigated to from a gated screen
- `SubscriptionScreen` — current plan badge, renews/expires date, "Manage billing" button (opens Stripe portal); `WidgetsBindingObserver` refreshes subscription when user returns from browser; free users see upgrade CTA
- Profile screen Subscription tile now navigates to `SubscriptionScreen` (was "Coming soon")
- `FoodPhotoScreen` shows an inline paywall with upgrade CTA for free-tier users instead of loading the camera
- Routes: `/profile/subscription` and `/paywall` added to `AppRoutes` and `app_router.dart`

### Bug fixes during deployment
- **TS2769** — four `request.log.error(msg, err)` calls in payments routes used wrong Pino argument order; fixed to `({ err }, msg)`
- **FST_ERR_CTP_ALREADY_PRESENT** — Fastify v5 rejects re-registering `application/json` in a child plugin; fixed by saving `rawBody` in the global parser in `index.ts` and removing the override from the payments plugin
- **TS2352** — `_req as Record<string, unknown>` needed `as unknown` intermediary; fixed
- **Prisma client stale** — local client didn't know about new fields until `yarn prisma generate` was run; Dockerfile already runs this so Railway was fine
- **`canLaunchUrl` always false on Android API 30+** — `<queries>` block in `AndroidManifest.xml` was missing `https`/`http` scheme intents; added them; also removed the `canLaunchUrl` gate from paywall screen (calls `launchUrl` directly, surfaces real error on failure)

**Decisions made:**
- Raw body for Stripe webhook is captured in the global content-type parser (`rawBody` property on request) rather than registering a separate buffer parser — avoids Fastify v5 plugin scoping restriction
- `canLaunchUrl` is not used as a gate for Stripe checkout/portal URLs — it is unreliable for https on Android without `QUERY_ALL_PACKAGES` and would silently block the redirect
- Subscription status is re-fetched on `AppLifecycleState.resumed` in `SubscriptionScreen` so no deep link or webhook polling is needed to reflect a completed payment

**Known issues:**
- None observed after install

**What to tackle next session:**
- Phase 4 remaining social features: user search + friend system, activity feed, 30-day challenges, leaderboards, XP + level system, badges, streak shields
- Coach marketplace (basic listing)
- Grocery list from meal plan (one remaining Phase 3 item, low priority)

---

## Previous session
**Date:** 2026-04-21 (session 29)
**Duration:** ~2 hours
**What was built:**

### Data isolation — per-user SharedPreferences scoping
- All SharedPreferences keys that stored user-specific data (streak count, streak last date, streak grace flag, daily water ml, daily burned kcal, weekly meal plan cache) were global strings — any new account signing in on the same device silently inherited the previous user's data
- Every key now includes the userId as part of the key: `streak_count_{uid}`, `water_ml_{uid}_{date}`, `meal_plan_v1_{uid}`, etc.
- `homeProvider` and `mealPlanProvider` now call `ref.watch(authProvider)` inside `build()` so they automatically rebuild whenever the logged-in user changes (login, logout, or account switch); action methods use `ref.read` (correct Riverpod pattern)
- Coach history was already userId-scoped from a previous session; no change needed there

### Personalised calorie target — TDEE parsing bug fixed
- `UserProfileDto.fromJson` was called with the full `{ user, profile }` envelope from `GET /api/v1/user/profile` but read `tdee` at the top level, where it doesn't exist — so every user always saw 2,000 kcal regardless of their stats
- Parser now reads from the nested `profile` sub-object first, with a top-level fallback for safety
- Backend `POST /user/profile` (onboarding save) was also constructing `UserProfileDto` without the new `currentWeightKg` and `heightCm` fields — caused a TypeScript TS2739 compile error that broke the Railway deployment; fixed by passing the values already in scope from the request body

### Personalised step goal
- `StepCounterCard` always showed 10,000 as the goal (hardcoded default, never overridden by the caller)
- Added `stepGoal` computed getter to `HomeDashboardState` using WHO/ACSM evidence-based tiers by activity level: sedentary 7,000 · light 8,500 · moderate 10,000 · active 12,000 · very_active 15,000; plus goal adjustment: +2,000 for lose_weight (extra NEAT accelerates fat loss), +3,000 for endurance (zone-2 volume), 0 for build_muscle (excessive steps impair hypertrophy recovery), clamped 5,000–20,000
- `home_screen.dart` now passes `stepGoal: home.stepGoal` to `StepCounterCard`

### Personalised water target
- Water target was fixed activity-level buckets (2,000–3,000 ml) with no weight consideration
- Replaced with `weightKg × ml_per_kg` where ml_per_kg varies by activity: sedentary 30 · light 33 · moderate 35 · active 38 · very_active 40; result rounded to nearest 50 ml, clamped 1,500–5,000 ml
- Falls back to activity-level buckets gracefully when `weightKg` is null (e.g. profile fetch failed)
- Backend `GET /user/profile` now fetches the latest `BodyStat` in parallel and returns `currentWeightKg` and `heightCm` alongside the existing profile fields; `UserProfileDto` in shared types updated to include both fields

### Deploy
- Committed 48-file changeset (all previous session work + today's fixes) and pushed to `main`
- Railway backend redeployed successfully (after fixing the TS2739 error in a follow-up push)
- Flutter release APK built (`app-release.apk`, 105 MB, arm64) and installed on CPH2401 (Android 14) via wireless ADB

**Decisions made:**
- Step goals are activity + goal adjusted, not flat 10,000 — a sedentary user targeting weight loss gets 9,000 (achievable), a very-active endurance athlete gets 18,000 (appropriate); build_muscle gets no bonus because high step counts cut into recovery
- Water formula is weight-based (35 ml/kg range) rather than fixed buckets because body size is the dominant driver of hydration needs, not just activity
- `ref.watch(authProvider)` only in `build()`, `ref.read` in action methods — strict Riverpod convention to avoid spurious subscriptions from outside the reactive graph

**Known issues:**
- None observed after install; backend healthy on Railway

**What to tackle next session:**
- Phase 3 remaining: Grocery list generated from the weekly meal plan (one `[ ]` left in Phase 3)
- Phase 4 start: User search + friend system (Prisma Friendship model already exists; need `/social/search` and `/social/friends` routes + Flutter FriendSearchScreen)
- Activity feed (post events when workout/food/weight milestones are logged)
- Stripe subscription integration — paywall for Pro/Coach features

---

## Previous session
**Date:** 2026-04-21 (session 28)
**Duration:** ~3 hours
**What was built:**

### AI Coach — full rebuild
- Removed 5/day rate limit entirely from `/ai/chat` and `/ai/coach` routes
- Upgraded model from `gemini-2.0-flash` → `gemini-2.5-flash`
- Greeting message injected locally on first open: "Hey {firstName}! How can I help you today?" — uses `isLocal: bool` flag on `ChatMessage` so it never gets sent to Gemini as history
- Suggestion chips and rate-limit banner removed from coach UI
- `CoachInputBar` simplified — `isRateLimited` param removed
- Silent retry: 503 from backend triggers a 4 s wait then one automatic retry, typing indicator stays visible throughout; only shows error (with Retry snackbar that restores the typed message) if both attempts fail
- `_callWithRetry` in provider always converts all `DioException` paths to `CoachUnavailableException` so nothing can be silently swallowed
- Added `console.log` before/after every Gemini chat call → Railway logs now show model, turn count, reply length, and full error on failure

### Gemini rate-limit fix — server-side queue
- `GeminiQueue` class in `ai.service.ts` serialises all Gemini API calls with a 4.5 s minimum gap between requests, staying well under the 15 RPM free-tier limit (and effective on paid tiers too)
- All four call sites (chat, food photo, meal plan, workout recommendation) go through the queue
- `workoutRecommendationProvider.keepAlive()` prevents re-fetching on every WorkoutScreen navigation (was the primary source of concurrent burst calls)

### Gym vs Home AI workout recommendations — fully split
- `GET /ai/workout-recommendation?type=gym|home` — backend reads `?type` query param
- Gym prompt: enforces barbell/dumbbell/cable/machine exercises
- Home prompt: `CRITICAL` — forbids all equipment, bodyweight-only exercises only
- `workoutRecommendationProvider` converted to a Riverpod `AsyncNotifierProvider.family<..., WorkoutType>` — `WorkoutType.gym` and `WorkoutType.home` have completely independent state and keepAlive
- New **`GymWorkoutScreen`** at `/workout/gym`: "Get AI Gym Recommendation" button → generates gym-specific plan; "Browse Exercises" card → exercise picker → active workout
- **`HomeWorkoutListScreen`**: AI home recommendation tile added at the top (hidden in pickMode); shows loading card, generated `RecommendationCard`, or retry tile
- **`WorkoutScreen`**: "Gym Workout" card now navigates to `/workout/gym` instead of directly to exercise picker; subtitles updated to mention AI; standalone recommendation removed from this screen entirely
- New route `/workout/gym` registered in `app_router.dart` and `AppRoutes`

### Back navigation fix
- `PopScope` wraps `MainShell` scaffold
- Back press on any non-Home tab → `context.go(AppRoutes.home)`
- Back press on Home tab → `canPop: true`, system exits the app

**Decisions made:**
- Coach rate limit removed permanently — billing is enabled on the Gemini API key, free-tier 5/day cap no longer makes sense
- Workout recommendation is manual-only (no auto-fetch on build) — prevents startup Gemini bursts; user taps when they want a suggestion
- Gemini calls are serialised server-side (queue) rather than client-side — single source of truth, works across all features not just chat

**Known issues:**
- None observed during testing session

**What to tackle next session:**
- Phase 4: User search + friend system (backend Friendship model + `/social/*` routes + Flutter FriendSearchScreen)
- Activity feed (social posts when workout/food milestones hit)
- Grocery list generated from the weekly meal plan (Phase 3 remaining item)
- Stripe subscription integration — paywall screens for Pro/Coach features

---

## Previous session
**Date:** 2026-04-20 (session 27)
**What was built:**

### Theme System — Light / Dark / Auto (pre-Phase 4 infrastructure)

**New files:**
- `apps/mobile/lib/core/theme/theme_provider.dart` — `ThemePreference` enum (auto/light/dark); `ThemeNotifier` (Riverpod `NotifierProvider`) persists choice in SharedPreferences, defaults to `auto`; `effectiveThemeModeProvider` computes `ThemeMode` from preference + current time, schedules a `Timer` that fires at the next 6 AM / 6 PM boundary and calls `ref.invalidateSelf()` so the switch happens without polling

**Modified files:**
- `app_colors.dart` — added 6 light-theme neutral constants (`lightBackground`, `lightSurface`, `lightSurfaceVariant`, `lightOnBackground`, `lightOnSurface`, `lightOnSurfaceVariant`); brand + semantic colors unchanged
- `app_theme.dart` — added `AppTheme.light`; extracted shared `_textTheme` + `_buttonShape`; both themes now expose `surfaceContainerHighest` and `outline` in `ColorScheme`
- `app.dart` — `MaterialApp.router` now uses `theme: AppTheme.light`, `darkTheme: AppTheme.dark`, `themeMode` from `effectiveThemeModeProvider`, `themeAnimationDuration: 400ms`, `themeAnimationCurve: Curves.easeInOut`
- `profile_screen.dart` — new "Appearance" settings group with `_ThemeToggleCard` (`SegmentedButton` with Auto ✦ / Light ☀ / Dark ☾ icons); `_SettingsCard`, `_SettingsTile`, `_GroupLabel` migrated to `Theme.of(context).colorScheme.*`

**Light-mode text visibility fix:**
- 209 hardcoded `AppColors.onSurface / onBackground / onSurfaceVariant / surface / surfaceVariant / background` references across 40 widget files replaced with `Theme.of(context).colorScheme.*` via PowerShell bulk replace
- `const` conflicts (widgets implicitly const that now contained non-const `Theme.of(context)` calls) resolved by a Python paren-balancing script run twice — first pass removed innermost `const`, second pass removed outer propagated `const`
- Custom painters (`_RingPainter` in `calorie_ring.dart`, `_ReadinessRingPainter` in `readiness_ring.dart`) don't have BuildContext; fixed by adding a `trackColor` constructor param, passed from the parent `build()` method
- `_placeholder()` in `food_result_card.dart` and `_deltaColor()` in `weekly_summary_card.dart` updated to accept `BuildContext` as a parameter
- `_kMoodColors` top-level const list in `mood_logger_card.dart` reverted the neutral slot back to `AppColors.onSurfaceVariant` (it's a chart data color, not text)

**Decisions made:**
- 6 AM = light on, 6 PM = dark on — matches typical usage pattern (fresh morning, relaxed evening)
- Auto-switch uses a `Timer` in `effectiveThemeModeProvider` that fires at the exact boundary and invalidates the provider; no polling, no `AppLifecycleObserver` needed
- `const` removal done with a Python script (paren-balancing + statement-boundary detection) rather than 155+ manual edits
- Track colors in custom painters passed as constructor params — painters are const-friendly, context-free; this is the Flutter-idiomatic pattern
- `AppColors.onSurfaceVariant` kept as a static constant for the mood chart neutral color (chart data colors are intentionally fixed, not theme-reactive)

**What's broken / known issues:**
- Some `prefer_const_constructors` linter *warnings* (not errors) remain in files where enclosing `const` was stripped — performance hints only, no functional impact
- Card/container widgets in screens not touched this session that still use `AppColors.surface` or `AppColors.surfaceVariant` as explicit `color:` arguments may render with dark card backgrounds in light mode — text is now fully readable; card backgrounds are a lower-priority follow-up

## Next session
**Priority task:** Grocery list from meal plan (Phase 3) — extract all ingredients from cached `WeeklyMealPlan`, deduplicate and group by category, render checklist at `/nutrition/meal-plan/grocery`
**Files to look at first:**
- `apps/mobile/lib/features/nutrition/models/meal_plan.dart`
- `apps/mobile/lib/features/nutrition/screens/meal_plan_screen.dart`
- `apps/mobile/lib/features/nutrition/providers/meal_plan_provider.dart`

---

## Last session (archived)
**Date:** 2026-04-20 (session 26)
**What was built:**

### AI Coach Fix + Recovery Score + Deload Week Detection (Phase 3)

**Root cause investigation — AI coach failures:**
Three bugs found and fixed:
1. `withGeminiRetry` backoff was 1s/2s — nowhere near Gemini's 60-second rate limit window. After 3 quick retries all hitting 429, it still failed with 503. Changed to 3s/6s/12s backoff (4 total attempts, up to 21s extra wait).
2. `sendCoachMessage` created the Gemini `model` + `chat` once outside the retry lambda. A failed `sendMessage` can corrupt the chat's internal pending history. Moved model+chat creation inside each retry attempt so every attempt starts fresh.
3. `coach_provider.dart` sent `{message}` only — no conversation history. Multi-turn conversation was completely broken. Now captures pre-send history and includes last 10 messages with each request.
4. Dio `receiveTimeout` increased 30s → 90s to cover worst-case retry wait plus Gemini's own response time.
5. Deployment had been broken due to `getFourWeekWorkoutSummary` missing from the committed `ai.repository.ts` — that was the root cause of ALL AI features failing on Railway.

**Backend — `apps/backend/src/services/ai.service.ts`:**
- `withGeminiRetry`: delays changed to `[3000, 6000, 12000]` ms; 4 total attempts; last error is always re-thrown correctly
- `sendCoachMessage`: `model` + `chat` creation moved inside retry lambda; `history` renamed to `geminiHistory` for clarity

**Backend — `apps/backend/src/repositories/ai.repository.ts`:**
- `getFourWeekWorkoutSummary(userId)` was added in previous session but never committed; committed now (was the root TypeScript build failure on Railway)

**Flutter — `apps/mobile/lib/core/api/api_client.dart`:**
- `receiveTimeout` increased from 30s to 90s

**Flutter — `apps/mobile/lib/features/coach/providers/coach_provider.dart`:**
- History snapshot captured before optimistic insert; sent as `history: [...]` (capped at 10 items) with every `/ai/chat` POST
- Multi-turn conversation now works correctly

**Recovery Score (Wellness screen):**
- `health_service.dart`: Added `_kHrvTypes`, best-effort HRV permission request, `getTodayHRV()` returning `double?` (null when no wearable)
- `wellness_state.dart`: Added `final double? hrv` field; `copyWithMood` preserves it
- `wellness_provider.dart`: `getTodayHRV()` fetched concurrently with other health data; `_computeReadiness` signature extended with `double? hrv`; HRV 10–100ms → 0–100 score takes precedence over RHR fallback
- `wellness_screen.dart`: Card title renamed "Recovery Score"; breakdown switched to `Wrap` with 4 pills (Sleep · HRV · HR · Load)

**Deload Week Detection (Workout screen):**
- `ai.repository.ts`: `getFourWeekWorkoutSummary` — 28-day workout logs with set counts
- `ai.service.ts`: `getDeloadCheck(userId)` — pure algorithmic (no Gemini); buckets logs into 4 weekly slots; flags if ≥3 consecutive weeks ≥40 sets OR 4-week avg >60 sets
- `ai.routes.ts`: `GET /api/v1/ai/deload-check` (all tiers, JWT auth)
- `deload_check.dart`: Dart model with `fromJson`
- `deload_check_provider.dart`: `AsyncNotifierProvider<DeloadCheckNotifier, DeloadCheck?>` — fetches on build, `refresh()`
- `deload_banner_card.dart`: amber warning card (deload recommended) or green OK card shown at top of WorkoutScreen

**Decisions made:**
- Deload detection is purely algorithmic (no Gemini) — deterministic, instant, no rate-limit risk
- HRV degrades gracefully: when unavailable (most Android devices without wearable), falls back to resting HR in the formula; shows "—" in the HRV pill
- Retry backoff of 3s/6s/12s chosen as a practical balance — longer than typical Gemini burst windows, short enough for acceptable UX (~21s worst case)
- History capped at last 10 messages before sending to server (matches server Zod schema `max(10)`)
- `receiveTimeout: 90s` is intentionally high only because AI routes need it; regular endpoints finish in <2s so no real UX impact

**What's broken / known issues:**
- If Gemini free-tier quota (1500 req/day) is fully exhausted, the app returns "AI service temporarily unavailable" regardless of retries — no fix possible without upgrading the API key
- Workout recommendation still auto-loads Gemini on tab open; if the coach is used at the same time, they compete for the 15 RPM slot (both will succeed eventually via retries, but one will be slow)

---

## Last session (archived)
**Date:** 2026-04-20 (session 25)
**What was built:**

### Workout Recommendation Engine + Home Workout Page (Phase 3)

**Backend — `apps/backend/src/repositories/ai.repository.ts`**:
- Added `getWeeklyWorkoutSummary(userId)` — fetches last 7 days of workout logs with exercise names and set counts

**Backend — `apps/backend/src/services/ai.service.ts`**:
- Added `getWorkoutRecommendation(userId)` — builds training history summary, sends to `gemini-2.0-flash` with JSON responseSchema; returns `WorkoutRecommendation` (workoutName, reasoning, targetMuscleGroups, suggestedExercises [{name, sets, reps, restSec}], estimatedDurationMin, intensity)
- Considers: days since last trained, muscle group balance, user goal, whether already trained today

**Backend — `apps/backend/src/routes/ai.routes.ts`**:
- Added `GET /api/v1/ai/workout-recommendation` — JWT auth → `getWorkoutRecommendation` → returns recommendation; available to all tiers

**Flutter — `features/workout/models/exercise.dart`**:
- Added `isBodyweight: bool` and `timedOnly: bool` optional fields to `Exercise` (both default false); controls how the set logger renders

**Flutter — `features/workout/models/home_exercise.dart`** (new):
- `HomeWorkoutCategory` enum (push/pull/legs/core/fullBody/skill) with icon, label, color
- `HomeDifficulty` enum (beginner/intermediate/advanced) with color coding
- `HomeExercise` class with category, difficulty, description, cues, timedOnly; `toExercise()` converts to `Exercise(isBodyweight: true)`
- `kHomeExerciseLibrary` — 40 exercises: 8 push, 6 pull, 9 legs, 10 core, 3 full body, 4 skill movements

**Flutter — `features/workout/models/workout_recommendation.dart`** (new):
- `SuggestedExercise` and `WorkoutRecommendation` models with `fromJson` factories

**Flutter — `features/workout/widgets/set_logger.dart`**:
- Added `SetInputMode` enum (repsAndWeight / repsOnly / durationOnly)
- `repsOnly` — bodyweight exercises: single reps field, no weight; validates reps > 0
- `durationOnly` — timed exercises (plank, wall sit…): single "Duration (sec)" field
- Updated `onLog` callback signature to `(int? reps, double? weightKg, int? durationSec)`

**Flutter — `features/workout/screens/active_workout_screen.dart`**:
- Added `_inputModeFor(exercise)` helper — maps `timedOnly`/`isBodyweight` → `SetInputMode`
- Updated `_WorkoutBody.onLogSet` to 3-param signature; passes `inputMode` and `lastDurationSec` to `SetLogger`

**Flutter — `features/workout/providers/workout_recommendation_provider.dart`** (new):
- `WorkoutRecommendationNotifier extends AsyncNotifier<WorkoutRecommendation?>` — auto-fetches on load, `refresh()` method for manual reload; errors are caught and return null (no crash)

**Flutter — `features/workout/widgets/recommendation_card.dart`** (new):
- Displays AI recommendation: workout name, intensity badge (color-coded light/moderate/hard), ~duration, target muscles, reasoning (2-line ellipsis), exercise list with sets × reps, refresh button

**Flutter — `features/workout/screens/home_workout_list_screen.dart`** (new):
- Search bar in AppBar bottom
- Category filter chips (Push/Pull/Legs/Core/Full Body/Skill) — single select, tap to deselect
- Difficulty ChoiceChips (Beginner/Intermediate/Advanced)
- Animated exercise cards with color icon, name, description, difficulty badge, muscle chip, timer icon for timed exercises; tap → `startWorkout(exercise.toExercise())` → pushes to activeWorkout

**Flutter — `features/workout/screens/workout_screen.dart`**:
- Redesigned: Resume card (shown when session active) → AI recommendation card (with loading shimmer) → "Start a workout" header → Gym Workout card → Home Workout card
- Gym card: existing exercise picker flow; Home card: navigates to `/workout/home`

**Flutter — routing**:
- `app_routes.dart`: added `homeWorkouts = '/workout/home'`
- `app_router.dart`: added `home-workouts` sub-route under `/workout`

**Decisions made:**
- `isBodyweight` / `timedOnly` on `Exercise` (not a separate type) — avoids type duplication; `HomeExercise.toExercise()` converts at start-workout time
- Recommendation available to all tiers (no paywall) — value-add for retention, cheap to generate
- Recommendation errors fail silently (null) so WorkoutScreen always loads
- `flutter analyze`: 0 issues

**What's broken / known issues:**
- None

## Next session
**Priority task:** Grocery list from meal plan (Phase 3) — extract all ingredients from cached `WeeklyMealPlan`, deduplicate and group by category, render checklist at `/nutrition/meal-plan/grocery`
**Files to look at first:**
- `apps/mobile/lib/features/nutrition/models/meal_plan.dart`
- `apps/mobile/lib/features/nutrition/screens/meal_plan_screen.dart`

---

## Last session (archived)
**Date:** 2026-04-20 (session 24)
**What was built:**

### Food Photo Logging (Phase 3)

**Backend — `apps/backend/src/services/ai.service.ts`**:
- Added `analyzeFoodPhoto(base64Image, mimeType)` — Gemini Vision multimodal call with `FOOD_PHOTO_SYSTEM_PROMPT` (nutritionist persona), detailed food detection prompt, and strict JSON `responseSchema`; identifies every food item including mixed dishes (biryani, curry, thali), estimates portion grams, returns calories/protein/carbs/fat/fiber per item with confidence (high/medium/low)

**Backend — `apps/backend/src/routes/ai.routes.ts`**:
- Added `POST /api/v1/ai/analyze-food-photo` — JWT auth → Zod validation (base64 + mimeType enum) → `analyzeFoodPhoto` → returns `FoodPhotoAnalysis`; no subscription gate (available to all tiers)

**Flutter — `features/nutrition/models/food_analysis.dart`** (new):
- `DetectedFoodItem` — mutable model; `updateServing(newG)` recalculates all macros proportionally from base values; `isSelected` toggle; `confidence` badge
- `FoodPhotoAnalysis` — wraps detected list + totalCalories + AI notes

**Flutter — `features/nutrition/providers/food_photo_provider.dart`** (new):
- `FoodPhotoState` — image path, detected foods, isAnalyzing, isLogging, mealType, loggedCount
- `FoodPhotoNotifier` — `pickAndAnalyze(source)`: picks image (75% quality, max 1280px), base64-encodes, calls API (60s timeout); `toggleItem`, `updateServing`, `removeItem`, `setMealType`; `logSelected()` POSTs all selected items to `/nutrition/food-logs` in parallel; `_guessMealType()` auto-selects by time of day

**Flutter — `features/nutrition/widgets/detected_food_card.dart`** (new):
- Checkbox toggle, food name, confidence badge (green/amber/red), macro chips, serving adjuster (−10/+10 stepper + editable text field with max 2000g guard, proportional macro recalc), remove button; flutter_animate entry slide/fade

**Flutter — `features/nutrition/screens/food_photo_screen.dart`** (new):
- Picker view: camera + gallery buttons, AI capability hints
- Analyzing view: image preview with gradient overlay + spinner + status text
- Results view: thumbnail header with item count + total kcal, AI notes, meal type selector (4 tabs, auto-selected by time), `DetectedFoodCard` list
- Bottom bar: "Log N items · X kcal" FilledButton → logs and pops back; logging spinner bar while saving

**Flutter — routing + entry point**:
- `app_routes.dart`: added `foodPhoto = '/nutrition/food-photo'`
- `app_router.dart`: added `food-photo` sub-route under `/nutrition`
- `nutrition_screen.dart`: added camera FAB (primary colour, heroTag `food_photo_fab`) → pushes to `/nutrition/food-photo`
- `AndroidManifest.xml`: added `READ_MEDIA_IMAGES` permission (Android 13+ gallery)

**Decisions made:**
- Gemini Vision (not ML Kit alone) — handles mixed dishes, composite meals, Indian food; returns nutrition estimates directly without a separate DB lookup step
- No subscription gate on photo logging — available to all tiers (matches CLAUDE.md feature table)
- Proportional macro scaling on serving edit — client-side, instant, no extra API call
- 60s receive timeout on analysis call — Gemini Vision with large images can take 15–30s

**What's broken / known issues:**
- None — `flutter analyze` 0 issues; release APK 144.7 MB installed on CPH2401

## Next session
**Priority task:** Workout recommendation engine (Phase 3) — suggest next workout based on muscle group volume (weekly sets tracked), recovery status, and user goal
**Files to look at first:**
- `apps/backend/src/routes/ai.routes.ts`
- `apps/mobile/lib/features/workout/`

---

## Last session (archived)
**Date:** 2026-04-20 (session 23)
**What was built:**

### AI Meal Plan Generator (Phase 3)

**Backend — `apps/backend/src/services/ai.service.ts`**:
- Added `generateMealPlan(userId)`: fetches user profile + latest body stat, computes daily calorie target and macro grams (using same Mifflin-St Jeor + goal-adjustment formula as CLAUDE.md), sends structured prompt to Gemini `gemini-2.0-flash` with `responseMimeType: 'application/json'` + `responseSchema` (SchemaType enums) for deterministic JSON output
- Returns `WeeklyMealPlan` (7 `DayMealPlan` objects, each with 3–4 `PlannedMeal` items)

**Backend — `apps/backend/src/routes/ai.routes.ts`**:
- Replaced 501 stub with full `POST /api/v1/ai/meal-plan` implementation: JWT auth → subscription check → Pro/Coach gate (free tier → 403 `UPGRADE_REQUIRED`) → `generateMealPlan` call

**Flutter — `features/nutrition/models/meal_plan.dart`** (new):
- `PlannedMeal`, `DayMealPlan`, `WeeklyMealPlan` with `fromJson`/`toJson` factories; fully typed, no `dynamic`

**Flutter — `features/nutrition/providers/meal_plan_provider.dart`** (new):
- `MealPlanNotifier extends AsyncNotifier<WeeklyMealPlan?>` — rehydrates from SharedPreferences on startup; `generate()` calls backend, caches result as JSON; handles 403 via separate `mealPlanUpgradeRequiredProvider` (StateProvider<bool>) — free tier shows paywall without error state

**Flutter — `features/nutrition/widgets/planned_meal_card.dart`** (new):
- Expandable card per meal: meal-type chip (colour-coded), name, macro chips (kcal/P/C/F), prep time, collapsible ingredients list; flutter_animate entry slide/fade; uses `withValues(alpha:)` not deprecated `withOpacity`

**Flutter — `features/nutrition/screens/meal_plan_screen.dart`** (new):
- Empty state → Generate button; loading state with spinner + message; 7-day `TabBar`/`TabBarView` layout; per-day summary card (day totals); `PlannedMealCard` list; Regenerate icon in AppBar; Pro paywall view for free-tier users

**Flutter — routing + entry point**:
- `app_routes.dart`: added `mealPlan = '/nutrition/meal-plan'`
- `app_router.dart`: added `meal-plan` sub-route under `/nutrition`
- `nutrition_screen.dart`: added `restaurant_menu_outlined` AppBar icon → pushes to `/nutrition/meal-plan`

**Decisions made:**
- JSON schema-constrained Gemini call (not string parsing) — eliminates hallucinated structure
- No DB storage — plan cached in SharedPreferences device-side; one plan at a time; regenerate overwrites
- Paywall handled client-side via separate `mealPlanUpgradeRequiredProvider` — avoids error state for a normal business condition
- `flutter analyze`: 0 issues; release APK built (144 MB) and installed on CPH2401

**What's broken / known issues:**
- None

## Next session
**Priority task:** Grocery list from meal plan (Phase 3) — extract all ingredients from the cached `WeeklyMealPlan`, deduplicate and group by category, render in a checklist screen at `/nutrition/meal-plan/grocery`
**Files to look at first:**
- `apps/mobile/lib/features/nutrition/models/meal_plan.dart`
- `apps/mobile/lib/features/nutrition/screens/meal_plan_screen.dart`
- `apps/mobile/lib/features/nutrition/providers/meal_plan_provider.dart`

---

## Last session (archived)
**Date:** 2026-04-20 (session 22)
**What was built:**

### Adaptive calorie + water targets (bug fixes)

**Flutter — `features/home/models/home_state.dart`**:
- `adaptiveTarget` now applies goal adjustment via `CalorieCalculator.dailyTarget()` before adding burned kcal — previously raw TDEE was used, ignoring −500/+300 adjustments
- Added `waterTargetMl` getter computed from `activityLevel` (sedentary 2000 → very_active 3000 ml)
- Added `activityLevel` field (from backend profile); added `weightKg` to `UserProfileDto` for future weight-based water calc

**Flutter — `features/home/providers/home_provider.dart`**:
- Passes `activityLevel` from profile into `HomeDashboardState`

**Flutter — `features/home/widgets/water_tracker_card.dart`**:
- Removed hardcoded `_goalMl = 2000`; now accepts `waterTargetMl` as a required param

**Flutter — `features/home/screens/home_screen.dart`**:
- Passes `home.waterTargetMl` to `WaterTrackerCard`

**Flutter — `features/nutrition/screens/nutrition_screen.dart`**:
- "Today's calories" summary now uses `adaptiveTarget` (goal-adjusted + burned) instead of raw TDEE

### AI coach debug + error handling

- Diagnosed `401` failure: wrong key type (`sk-admin-` is a Console admin key, not a Messages API key)
- Diagnosed `400` failure after key fix: Anthropic account had $0 credits
- Backend: added `Anthropic.BadRequestError` catch for billing errors → returns `503 AI_BILLING` instead of swallowing as 500
- Flutter: added `CoachUnavailableException` for 503 responses; surfaces backend message in SnackBar

### Anthropic → Google Gemini migration

**Backend — `apps/backend/src/services/ai.service.ts`**:
- Replaced `@anthropic-ai/sdk` with `@google/generative-ai@0.24.1`
- `sendCoachMessage` rewritten: `GoogleGenerativeAI` client, `gemini-2.0-flash` model, `systemInstruction` for system prompt, `startChat({ history })` + `sendMessage` for multi-turn; role mapping `assistant → model`

**Backend — `apps/backend/src/routes/ai.routes.ts`**:
- Removed Anthropic import; error handling uses `GoogleGenerativeAIFetchError` (status 429 → 503)
- `/chat` route simplified: removed duplicate inline AI call, now delegates to `sendCoachMessage` (which already handles context injection via `buildContext`)
- Extracted `handleAiError()` helper used by both `/coach` and `/chat`

**Backend — `apps/backend/src/utils/config.ts`**:
- `ANTHROPIC_API_KEY` → `GEMINI_API_KEY`

**Decisions made:**
- `gemini-2.0-flash` chosen over `gemini-1.5-pro`: faster, cheaper, generous free tier (1,500 req/day) vs Anthropic's pay-per-token with no free tier
- `/chat` route now fully delegates to `sendCoachMessage` — removes duplicated system prompt and context injection that existed in both the route and the service

**What's broken / known issues:**
- `GEMINI_API_KEY` must be set in Railway dashboard before the deployed coach works — placeholder value is in local `.env`; key available at aistudio.google.com/apikey

## Next session
**Priority task:** AI meal plan generator (Phase 3) — `POST /api/v1/ai/meal-plan` stub already exists; build the full flow: weekly plan generation with Gemini, meal plan model, and a plan screen inside `features/nutrition/`
**Files to look at first:**
- `apps/backend/src/routes/ai.routes.ts` (meal-plan stub at bottom)
- `apps/backend/src/services/ai.service.ts` (pattern to follow for Gemini call)
- `apps/mobile/lib/features/nutrition/` (meal plan screen lives here)

---

### Previous session (2026-04-16, session 21)
**What was built:**

### Coach screen rebuild + bug fix

**Flutter — `features/coach/screens/coach_screen.dart`** (rebuilt):
- `reverse: true` on the message `ListView` — newest messages anchor to bottom without manual scroll logic
- Replaced inline error banner with `ScaffoldMessenger` SnackBar for rate-limit and generic errors
- Amber `_RateLimitBanner` stripe at top of body (free tier only, shown when `used > 0`)
- Removed `_scrollController` and all `_scrollToBottom()` plumbing (no longer needed with `reverse: true`)
- File trimmed to ~200 lines

**Flutter — `features/coach/widgets/coach_input_bar.dart`** (new):
- `CoachInputBar` extracted from coach screen; pure `StatelessWidget`
- Handles enabled/disabled state, loading spinner in send button, rate-limited hint text

**Flutter — `features/coach/widgets/chat_bubble.dart`** (updated):
- Coach bubbles now render in a `Row` with a 28×28 `psychology_outlined` avatar circle on the left
- `TypingIndicator` also gained the matching avatar so it looks consistent

**Flutter — `features/coach/providers/coach_provider.dart`** (bug fix):
- 429 response: rate-limit counters (`messagesUsedToday`, `limit`) were being read from `body['data']` — the backend actually puts them inside `body['error']`; corrected to `body?['error']`

### Adaptive daily calorie target (Phase 3 — ✓ complete)

**Flutter — `features/home/models/home_state.dart`**:
- Added `caloriesBurnedToday` field (default 0)
- Added `adaptiveTarget` computed getter: `tdee + caloriesBurnedToday`
- `copyWith` updated

**Flutter — `features/home/providers/home_provider.dart`**:
- `_loadState` reads `calories_burned_YYYY-MM-DD` from SharedPreferences on startup
- New `addBurnedCalories(int kcal)` method: accumulates into `caloriesBurnedToday`, persists to prefs
- `_dateStr` replaced with `_todayStr()` + `_dateStr(DateTime)` separation; `_burnedKey()` helper added

**Flutter — `features/workout/providers/workout_provider.dart`**:
- `finishWorkout` calls `homeProvider.notifier.addBurnedCalories(caloriesBurned)` after both: successful API POST and offline sync-queue enqueue (so calories are credited even when offline)

**Flutter — `features/home/screens/home_screen.dart`**:
- `CalorieRing` target: `home.adaptiveTarget` (was `home.tdee`)
- `MacroBars` tdee param: `home.adaptiveTarget` — macro gram targets scale up with workout
- "Daily target · X kcal" label uses `adaptiveTarget`
- "+X kcal from workout" amber pill chip shown under the ring when `caloriesBurnedToday > 0`

**Decisions made:**
- Adaptive target is purely client-side (SharedPreferences) — no backend round-trip needed; daily key resets naturally at midnight
- Burned calories credited on offline enqueue, not just successful POST — better UX when the user has no signal
- `MacroBars` receives `adaptiveTarget` (not raw TDEE) so protein/carb gram targets also reflect the extra budget from exercise

**What's broken / known issues:**
- None — `flutter analyze` 0 issues, `flutter test` 14/14 passed, release APK installed on CPH2401

## Next session
**Priority task:** AI meal plan generator (Phase 3) — `POST /api/v1/ai/meal-plan` backend (stub already exists), weekly meal plan model, and a basic meal plan screen
**Files to look at first:**
- `apps/backend/src/routes/ai.routes.ts` (meal-plan stub at bottom)
- `apps/mobile/lib/features/nutrition/` (meal plan screen lives here)
- `apps/mobile/lib/features/coach/providers/coach_provider.dart` (pattern to follow for AI calls)

---

### Previous session (2026-04-16, session 20)
**What was built:**

### AI Coach Chat (Phase 3 — first feature)

**Backend — `src/repositories/ai.repository.ts`** (new):
- `getTodayNutrition` — sums calories/protein/carbs/fat for today's food logs
- `getTodayWorkout`, `getWeekWorkoutCount`, `getLatestBodyStat`, `getUserWithProfile` — all run in parallel to build coach context

**Backend — `src/services/ai.service.ts`** (new):
- `checkCoachRateLimit` — Redis key `coach:limit:{userId}`, incr + 24h TTL, 5 msg/day free; fails open if Redis unavailable; unlimited for pro/coach tiers
- `buildContext` — assembles `<user_context>` block with goal, TDEE, today's macros, workout, weekly count, body weight
- `sendCoachMessage` — streams `claude-sonnet-4-6` with system prompt from CLAUDE.md spec + context injected; returns `finalMessage()` text

**Backend — `src/routes/ai.routes.ts`** (updated):
- `POST /api/v1/ai/coach` — auth → subscription lookup → rate limit check → Claude call
- Returns `{ message, remainingMessages }` (null remaining = unlimited)
- Typed error code `RATE_LIMITED_COACH` (429) for free-tier exhaustion

**Flutter — `features/coach/models/chat_message.dart`** (new):
- `ChatMessage` with `role`, `content`, `createdAt`; `toJson()` for API payload

**Flutter — `features/coach/providers/coach_provider.dart`** (new):
- `CoachState` — `messages`, `isLoading`, `error`, `remainingMessages`, `isRateLimited`
- `CoachNotifier` — sends full history each call; handles `RATE_LIMITED_COACH` code distinctly

**Flutter — `features/coach/widgets/chat_bubble.dart`** (new):
- User bubble (right, primary colour) + assistant bubble (left, surface variant)
- `flutter_animate` entry slide/fade; animated `TypingIndicator` with 3-dot bounce loop

**Flutter — `features/coach/screens/coach_screen.dart`** (rebuilt):
- Full chat UI: empty state with 3 suggestion chips, message list with auto-scroll
- AppBar shows remaining messages for free tier
- Error/rate-limit banner with dismiss; multiline input bar with send button

**Decisions made:**
- Model: `claude-sonnet-4-6` (per CLAUDE.md spec for the coach chatbot)
- Rate limit fails open when Redis is unavailable (better UX than blocking)
- Full conversation history sent each API call (stateless backend, Claude has context)

**What's broken / known issues:**
- None

---

### Previous session (2026-04-15, session 19) — Production hardening

**Flutter — `main.dart`:**
- `SentryFlutter.init` wraps `runApp`; reads `FLUTTER_SENTRY_DSN` from dotenv; `tracesSampleRate` 0.2 in release, 0 in debug; `sendDefaultPii = false`
- `dotenv.load` selects `.env.production` in `kReleaseMode`, falls back to `.env` if file missing (e.g. local release test)
- `envFile` promoted to `const` (satisfies `prefer_const_declarations`)

**Flutter — `app.dart`:**
- `MaterialApp.router.builder` wraps non-production builds with a red `Banner('DEBUG', BannerLocation.topEnd)`; controlled by `kReleaseMode || dotenv['FLUTTER_ENV'] == 'production'`; dotenv access guarded against `NotInitializedError` in test environments

**Flutter — `android/app/build.gradle.kts`:**
- `isMinifyEnabled = true`, `isShrinkResources = true` in the release build type
- Explicit `debug` block with both set to `false`

**Flutter — `android/app/proguard-rules.pro`:**
- Added keep rules for Dio/OkHttp, Riverpod, Drift/SQLite, Sentry, Firebase/FCM, Kotlin coroutines, and `GeneratedPluginRegistrant`

**Flutter — `pubspec.yaml`:**
- `sentry_flutter: ^8.4.0` added under dependencies
- `.env.production` added to assets (stub file committed; real values injected by CI/CD)

**Flutter — `lib/core/db/app_database.dart`:**
- Added `AppDatabase.forTesting(super.executor)` named constructor for use in widget tests

**Flutter — `test/widget_test.dart`:**
- Override `appDatabaseProvider` with `NativeDatabase.memory()` via `AppDatabase.forTesting` to avoid background isolate timers in tests

**Flutter — Bug fixes from `flutter analyze` (0 issues remaining):**
- `app_database.dart` — `issueCustomQuery` → `m.database.customStatement` (deprecated API)
- `notification_service.dart` — removed unused `token_store.dart` import
- `sync_queue_service.dart` — `notifier.state.isSyncing` → `_ref.read(syncStatusProvider).isSyncing` (protected member access)
- `water_tracker_card.dart` — added `const` to `Icon` and `AlwaysStoppedAnimation` constructors

**Backend — `src/index.ts`:**
- `@sentry/node` initialised at startup (when `SENTRY_DSN` is set); captures unhandled errors and startup crashes
- `@fastify/rate-limit` registered globally (100 req/min per IP); custom `errorResponseBuilder` returns `{ success: false, error: { code: 'RATE_LIMITED' } }`
- `bodyLimit: 10 * 1024` (10 kb) added to Fastify constructor to block oversized payloads
- Global `setErrorHandler` — 4xx errors relay message; 5xx errors return a generic message in production and never include stack traces

**Backend — `src/routes/auth.routes.ts`:**
- `authRateLimit` config object (10 req/min) applied to all four auth endpoints: `/signup`, `/login`, `/refresh`, `/logout`

**Backend — `package.json`:**
- `"@sentry/node": "^8.0.0"` added to dependencies

**Test results:** `flutter analyze` — 0 issues; `flutter test` — 14/14 passed

**Decisions made:**
- Used `kReleaseMode` (not just `FLUTTER_ENV`) as the primary banner guard so release APKs are always clean even if the env var is missing
- `@sentry/node` config.SENTRY_DSN is optional — Sentry is silently skipped if DSN not set, preventing startup failures on dev machines
- Rate-limit `keyGenerator` reads `x-forwarded-for` first so Railway's reverse proxy doesn't make all clients share one bucket

**Known issues:**
- Pre-existing: `RAILWAY_DEPLOY_WEBHOOK_URL` secret not set; Redis not on Railway (BullMQ jobs disabled); iOS push notifications deferred
- `.env.production` committed as a stub template — CI/CD must overwrite it with real values at build time; add to `.gitignore` before first real release build

---

## Next session
**Priority task:** Phase 3 — AI coach chat (Claude API integration)

---

## Previous session
**Date:** 2026-04-15 (session 18)
**What was built:**

### Ad placeholder slots — home screen (AdMob prep)

**New: `features/home/providers/ad_providers.dart`:**
- `adBannerDismissedProvider` (`StateProvider<bool>`, init `false`) — tracks banner dismissal this session
- `adPopupDismissedProvider` (`StateProvider<bool>`, init `false`) — tracks popup dismissal this session
- Both reset automatically on cold start (Riverpod in-memory only; no persistence)

**New: `features/home/widgets/ad_placeholders.dart`:**
- `AdBannerPlaceholder` (`ConsumerWidget`) — `h=60`, `borderRadius=12`, surfaceVariant gradient, orange "Ad" pill badge top-left, X close button top-right, centred icon + "Advertisement" label; returns `SizedBox.shrink()` when dismissed
- `AdPopupPlaceholder` (`ConsumerWidget`) — `w=180, h=100`, drop shadow, same badge/close pattern, same dismiss behaviour
- Shared private `_AdBadge` and `_CloseButton` helpers

**Modified: `features/home/screens/home_screen.dart`:**
- `_HomeScreenState` gains `bool _popupVisible = false`; `initState` schedules `Future.delayed(2s)` to flip it → triggers popup appearance on cold start
- Body wrapped in `Stack`; `Positioned(bottom: 16, left: 16)` renders `AdPopupPlaceholder` when `_popupVisible`
- `_Dashboard` Column gets `const AdBannerPlaceholder()` as first child, between AppBar and CalorieRing card
- `TODO(admob)` comments at both slots mark the exact swap points for `AdWidget` from `google_mobile_ads`

**Decisions made:**
- Used `StateProvider<bool>` (not `SharedPreferences`) so both ads reappear on every cold start without any persistence code — intentional for pre-launch placeholder behaviour; real AdMob integration can decide its own frequency-capping strategy
- Providers in `providers/ad_providers.dart` (not inline in the widget file) to follow project convention; both will be deleted once AdMob widgets replace the placeholders
- Popup delay logic lives in `_HomeScreenState` (local `setState`) rather than a provider — it's UI-only timing with no state worth persisting

**Known issues:**
- None introduced today
- Pre-existing: `RAILWAY_DEPLOY_WEBHOOK_URL` secret not set; Redis not on Railway (BullMQ jobs disabled); `settings_screen.dart` orphaned; iOS push notifications deferred

---

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
**Date:** 2026-04-14 (session 17)
**What was built:**

### Nutrition screen — meal card redesign

**`meal_section.dart` — complete rewrite as `MealCard`:**
- `MealSection` replaced by `MealCard` (`ConsumerStatefulWidget`), exported from the same file
- `_MealHeader`: emoji + meal name + kcal total (in `AppColors.calories`) + `+` `IconButton` (always navigates to `FoodSearchScreen` with `mealType` as GoRouter `extra`)
- Empty state (`_EmptyPlaceholder`): italic muted "Tap + to add breakfast/lunch/…" text; entire `Card` is tappable via `InkWell.onTap` → `FoodSearchScreen`
- Collapsed state (`_LoggedBody`): `_FoodChipRow` — horizontal `ListView` of `_FoodChip` pill widgets (food name capped at 110px + kcal in calories colour); "See all (N)" underline link
- Expanded state: full `_LogItem` list (swipe-to-delete with confirm dialog preserved from old `MealSection`); "Collapse" underline link
- Animations via `flutter_animate`: chip row re-animates on `ValueKey(logs.length)` (fade + slight slideX); expanded list items stagger with 40ms delay per item (fade + slideY)
- `ClipRRect` ensures Dismissible delete background is clipped cleanly to card corners

**`log_food_sheet.dart`:**
- `showLogFoodSheet` gains optional `initialMealType` param
- `_LogFoodSheet` stores `initialMealType`; `_mealType` initialised in `initState` (defaults to `'lunch'` if null)

**`food_search_screen.dart`:**
- `FoodSearchScreen` gains optional `initialMealType` constructor param
- Forwarded to `showLogFoodSheet` so the bottom sheet opens with the correct meal pre-selected

**`app_router.dart`:**
- `food-search` route builder reads `state.extra as String?` and passes to `FoodSearchScreen`

**`nutrition_screen.dart`:**
- `MealSection` → `MealCard` (import and widget call updated)

**Decisions made:**
- Kept `meal_section.dart` filename (avoids router/import churn); only the exported class name changed to `MealCard`
- Swipe-to-delete lives only in the expanded view — chips are read-only; avoids accidental deletions from the compact view
- `mealType` is passed as GoRouter `extra` (not a query param) to avoid polluting the URL with transient UI state

**Known issues:**
- None introduced today
- Pre-existing: `RAILWAY_DEPLOY_WEBHOOK_URL` secret not set; Redis not on Railway (BullMQ jobs disabled); `settings_screen.dart` orphaned; iOS push notifications deferred

---

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
**Date:** 2026-04-14 (session 16)
**What was built:**

### Indian food database + nutrition search improvements

**New asset — `apps/mobile/assets/data/indian_foods.json`:**
- 150 curated Indian foods with accurate IFCT-referenced macros per 100g
- Coverage: grains (rice cooked/raw, basmati, brown rice, atta, maida, besan, rava, poha, jowar/bajra/ragi rotis), dals (toor, moong, chana, masoor — cooked), breakfast items (idli, dosa, masala dosa, rava dosa, uttapam, poha, upma, pongal, medu vada, dhokla), Indian breads (chapati, paratha, aloo paratha, puri, naan, bhatura, kulcha, methi thepla), curries and gravies (sambar, rasam, dal makhani, dal tadka, rajma, chole, butter chicken, palak paneer, paneer butter masala, kadai paneer, paneer tikka masala, aloo gobhi, aloo palak, mixed veg, kadhi, baingan bharta), non-veg (chicken/mutton/fish curry, butter chicken, tandoori chicken, egg curry, fish fry, prawn curry, seekh kebab), dairy (paneer, curd, all three milk types, lassi, buttermilk), fruits (banana, apple, mango, orange, papaya, guava, amla, chiku, watermelon, pomegranate, grapes, dates), vegetables (potato, onion, tomato, spinach, cauliflower, cabbage, beans, okra, karela, lauki, brinjal, methi, peas, cucumber, mooli, carrot, pumpkin, sweet potato, drumstick, jackfruit), beverages (tea, coffee, coconut water, turmeric milk, nimbu pani, aamras), fats/oils (ghee, butter, coconut oil, mustard oil), sweeteners (sugar, jaggery), nuts/seeds (cashew, almonds, peanuts, sesame, flaxseeds, coconut), snacks (murukku, bhel puri, puffed rice, papad), sweets (gulab jamun, rasgulla, jalebi, besan ladoo, kheer, gajar halwa, suji halwa), and other staples (sattu, vermicelli, moong sprouts)
- Each food has `commonServings` with realistic portion labels (katori, roti, cup, piece) and gram weights

**New service — `apps/mobile/lib/core/services/indian_food_service.dart`:**
- Loads JSON asset lazily on first call; subsequent calls use in-memory cache
- `search(query)` matches case-insensitively on both English name and Hindi (`nameHindi`)
- Riverpod `Provider<IndianFoodService>` — injected into `OpenFoodFactsService`

**Updated `FoodItem` model (`features/nutrition/models/food_item.dart`):**
- Added `ServingOption` class (`label`, `grams`)
- Added `nameHindi`, `commonServings`, `isIndian` fields to `FoodItem`
- New `FoodItem.fromIndianJson` factory

**Updated `open_food_facts_service.dart`:**
- `searchByName` now runs three parallel searches: `IndianFoodService.search` + USDA + OFF
- Merge order: Indian → USDA → OFF — Indian results always appear first when the query matches
- `OpenFoodFactsService` now takes `IndianFoodService` via constructor (injected by Riverpod)

**Updated `log_food_sheet.dart`:**
- Indian foods (`isIndian == true`) show a "Quick select" chip row above the gram input
- Chips are built from `commonServings` (e.g. "1 katori (~150g)", "1 medium roti (~35g)")
- Tapping a chip sets the gram value directly and updates the text field
- Manual text-field edits or unit-picker changes clear the chip lock — power users aren't blocked
- Hindi name shown in the subtitle when present (instead of brand)

**`pubspec.yaml`:** added `assets/data/` to bundle the JSON

**Decisions made:**
- Indian food results are prepended before USDA/OFF (not interleaved) — simpler dedup logic, and for an Indian user a local search miss is more likely than OFF/USDA knowing "idli" or "toor dal cooked"
- Serving chips are shown in addition to (not instead of) the gram input — advanced users who want 73g of dal aren't blocked
- `IndianFoodService` is a plain class with a lazy `List<FoodItem>` cache; no Riverpod `AsyncNotifier` needed because the asset load is fast and errors just set cache to `[]`

**Known issues:**
- None introduced today
- Pre-existing: `RAILWAY_DEPLOY_WEBHOOK_URL` GitHub Actions secret not set; Redis not on Railway (weekly push + BullMQ jobs disabled); `settings_screen.dart` orphaned

---

## Previous session
**Date:** 2026-04-14 (session 15)

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
| 2026-04-23 (s31) | AI exercise form monitor — on-device ML Kit pose detection, 9 exercises, green skeleton overlay, rep counter, NV21 format + rotation bug fixed | 3 ✅ |
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
