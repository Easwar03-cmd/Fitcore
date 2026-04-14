# Graph Report - .  (2026-04-14)

## Corpus Check
- 155 files · ~57,604 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 993 nodes · 1171 edges · 77 communities detected
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 13 edges (avg confidence: 0.83)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Riverpod State Providers|Riverpod State Providers]]
- [[_COMMUNITY_Onboarding Flow|Onboarding Flow]]
- [[_COMMUNITY_UI Widgets & Theme|UI Widgets & Theme]]
- [[_COMMUNITY_Architecture & Data Models|Architecture & Data Models]]
- [[_COMMUNITY_Material UI Components|Material UI Components]]
- [[_COMMUNITY_Nutrition & Food Logging|Nutrition & Food Logging]]
- [[_COMMUNITY_Workout Tracking|Workout Tracking]]
- [[_COMMUNITY_Home Dashboard|Home Dashboard]]
- [[_COMMUNITY_Auth & Notifications|Auth & Notifications]]
- [[_COMMUNITY_Sleep & Wellness Data|Sleep & Wellness Data]]
- [[_COMMUNITY_Wellness & Progress Screens|Wellness & Progress Screens]]
- [[_COMMUNITY_GPS Workout Session|GPS Workout Session]]
- [[_COMMUNITY_Navigation & Routing|Navigation & Routing]]
- [[_COMMUNITY_Progress Charts|Progress Charts]]
- [[_COMMUNITY_Body Stats & Set Logger|Body Stats & Set Logger]]
- [[_COMMUNITY_Workout History & Picker|Workout History & Picker]]
- [[_COMMUNITY_Food Log Sheet|Food Log Sheet]]
- [[_COMMUNITY_Offline Sync & AI Coach|Offline Sync & AI Coach]]
- [[_COMMUNITY_Nutrition Screen|Nutrition Screen]]
- [[_COMMUNITY_Drift DB Utilities|Drift DB Utilities]]
- [[_COMMUNITY_Backend Auth Service|Backend Auth Service]]
- [[_COMMUNITY_Unit Tests|Unit Tests]]
- [[_COMMUNITY_Weekly Summary Job|Weekly Summary Job]]
- [[_COMMUNITY_iOS App Delegate|iOS App Delegate]]
- [[_COMMUNITY_Progress Data Models|Progress Data Models]]
- [[_COMMUNITY_App Icons & Branding|App Icons & Branding]]
- [[_COMMUNITY_Plugin Registrants|Plugin Registrants]]
- [[_COMMUNITY_API Response Models|API Response Models]]
- [[_COMMUNITY_Calorie Calculator|Calorie Calculator]]
- [[_COMMUNITY_Food Log Models|Food Log Models]]
- [[_COMMUNITY_DB Seed Script|DB Seed Script]]
- [[_COMMUNITY_User Routes & TDEE|User Routes & TDEE]]
- [[_COMMUNITY_Flutter LLDB Debug Helper|Flutter LLDB Debug Helper]]
- [[_COMMUNITY_iOS Runner Tests|iOS Runner Tests]]
- [[_COMMUNITY_Macro Calculator|Macro Calculator]]
- [[_COMMUNITY_Auth State Models|Auth State Models]]
- [[_COMMUNITY_Food Item Models|Food Item Models]]
- [[_COMMUNITY_Firebase Push Service|Firebase Push Service]]
- [[_COMMUNITY_iOS Scene Delegate|iOS Scene Delegate]]
- [[_COMMUNITY_Streak Calculator|Streak Calculator]]
- [[_COMMUNITY_Onboarding State|Onboarding State]]
- [[_COMMUNITY_Workout Log Models|Workout Log Models]]
- [[_COMMUNITY_Backend Entry Point|Backend Entry Point]]
- [[_COMMUNITY_AI Routes|AI Routes]]
- [[_COMMUNITY_Auth Routes|Auth Routes]]
- [[_COMMUNITY_Body Routes|Body Routes]]
- [[_COMMUNITY_Nutrition Routes|Nutrition Routes]]
- [[_COMMUNITY_Social Routes|Social Routes]]
- [[_COMMUNITY_Wellness Routes|Wellness Routes]]
- [[_COMMUNITY_Workout Routes|Workout Routes]]
- [[_COMMUNITY_Android MainActivity|Android MainActivity]]
- [[_COMMUNITY_Drift Sync DAO|Drift Sync DAO]]
- [[_COMMUNITY_Body Stat Model|Body Stat Model]]
- [[_COMMUNITY_OpenAI Embeddings & Pinecone|OpenAI Embeddings & Pinecone]]
- [[_COMMUNITY_Health Plugin Bridge|Health Plugin Bridge]]
- [[_COMMUNITY_Body Repository|Body Repository]]
- [[_COMMUNITY_Nutrition Repository|Nutrition Repository]]
- [[_COMMUNITY_User Repository|User Repository]]
- [[_COMMUNITY_Wellness Repository|Wellness Repository]]
- [[_COMMUNITY_Workout Repository|Workout Repository]]
- [[_COMMUNITY_Backend Config|Backend Config]]
- [[_COMMUNITY_DB Connection|DB Connection]]
- [[_COMMUNITY_Android Build Config|Android Build Config]]
- [[_COMMUNITY_Android Settings|Android Settings]]
- [[_COMMUNITY_App Build Gradle|App Build Gradle]]
- [[_COMMUNITY_iOS Plugin Header|iOS Plugin Header]]
- [[_COMMUNITY_iOS Bridging Header|iOS Bridging Header]]
- [[_COMMUNITY_App Routes Constants|App Routes Constants]]
- [[_COMMUNITY_Backend Index|Backend Index]]
- [[_COMMUNITY_TypeScript Backend|TypeScript Backend]]
- [[_COMMUNITY_Socket.io Real-time|Socket.io Real-time]]
- [[_COMMUNITY_Cloudinary Storage|Cloudinary Storage]]
- [[_COMMUNITY_AWS Infrastructure|AWS Infrastructure]]
- [[_COMMUNITY_GitHub Actions CICD|GitHub Actions CI/CD]]
- [[_COMMUNITY_Open Food Facts API|Open Food Facts API]]
- [[_COMMUNITY_USDA Food API|USDA Food API]]
- [[_COMMUNITY_API Response Envelope|API Response Envelope]]

## God Nodes (most connected - your core abstractions)
1. `package:flutter/material.dart` - 55 edges
2. `package:flutter_riverpod/flutter_riverpod.dart` - 44 edges
3. `../../../core/theme/app_colors.dart` - 30 edges
4. `package:go_router/go_router.dart` - 17 edges
5. `FitCore Fitness App` - 17 edges
6. `../constants/app_routes.dart` - 16 edges
7. `package:logger/logger.dart` - 13 edges
8. `_` - 13 edges
9. `package:dio/dio.dart` - 11 edges
10. `../../../core/theme/app_text_styles.dart` - 11 edges

## Surprising Connections (you probably didn't know these)
- `ADR-001: Expo Router over React Navigation` --semantically_similar_to--> `ADR-002 Rationale: GoRouter over Navigator 2.0`  [INFERRED] [semantically similar]
  DECISIONS.md → CLAUDE.md
- `ADR-002: WatermelonDB over SQLite directly` --semantically_similar_to--> `ADR-003 Rationale: Drift over Hive or Isar`  [INFERRED] [semantically similar]
  DECISIONS.md → CLAUDE.md
- `FitCore iOS Launch Screen (Blank/White)` --conceptually_related_to--> `FitCore Mobile App`  [INFERRED]
  apps/mobile/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png → apps/mobile/lib/main.dart
- `FitCore App Icon (Flutter Default)` --conceptually_related_to--> `FitCore Mobile App`  [INFERRED]
  apps/mobile/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png → apps/mobile/lib/main.dart
- `FitCore Flutter Mobile App README` --references--> `Flutter 3.22+ Framework`  [EXTRACTED]
  apps/mobile/README.md → CLAUDE.md

## Hyperedges (group relationships)
- **AI Coach Pipeline: Context + System Prompt + Claude API + Rate Limit** — claudemd_coach_context, claudemd_coach_system_prompt, claudemd_claude_api, claudemd_coach_ratelimit [EXTRACTED 0.95]
- **Auth Token Security: JWT + flutter_secure_storage + Refresh Flow** — claudemd_jwt_auth, claudemd_flutter_secure_storage, claudemd_auth_flow [EXTRACTED 0.95]
- **Push Notifications Stack: FCM + Firebase Admin + BullMQ + notification_service.dart** — claudemd_fcm, progress_firebase_admin, progress_weekly_summary_job, progress_notification_service [EXTRACTED 0.90]

## Communities

### Community 0 - "Riverpod State Providers"
Cohesion: 0.03
Nodes (75): build, FitCoreApp, _FitCoreAppState, initState, AppDatabase, PendingSyncItems, DateTime, HealthService (+67 more)

### Community 1 - "Onboarding Flow"
Cohesion: 0.03
Nodes (74): build, LoginScreen, _LoginScreenState, Scaffold, SizedBox, _submit, build, Scaffold (+66 more)

### Community 2 - "UI Widgets & Theme"
Cohesion: 0.03
Nodes (74): AnimatedBuilder, build, CalorieRing, _CalorieRingState, didUpdateWidget, dispose, initState, paint (+66 more)

### Community 3 - "Architecture & Data Models"
Cohesion: 0.04
Nodes (61): ADR-001 Rationale: Flutter over React Native, ADR-002 Rationale: GoRouter over Navigator 2.0, ADR-003 Rationale: Drift over Hive or Isar, api_client.dart (Dio + Auth Interceptor), app_database.dart (Drift), Auth Flow (JWT + Refresh Tokens), Prisma BodyStat Model, BullMQ Job Queue (+53 more)

### Community 4 - "Material UI Components"
Cohesion: 0.03
Nodes (46): app_colors.dart, app_text_styles.dart, ThemeData, AppButton, build, AppCard, build, Card (+38 more)

### Community 5 - "Nutrition & Food Logging"
Cohesion: 0.04
Nodes (48): BarcodeScreen, _BarcodeScreenState, build, corner, CustomPaint, dispose, Icon, _onDetect (+40 more)

### Community 6 - "Workout Tracking"
Cohesion: 0.05
Nodes (41): build, logSet, _onGpsUpdate, resetSession, setExercise, skipRest, _startRestTimer, startWorkout (+33 more)

### Community 7 - "Home Dashboard"
Cohesion: 0.05
Nodes (38): copyWith, HomeDashboardState, UserProfileDto, AlertDialog, build, Center, _Dashboard, _ErrorView (+30 more)

### Community 8 - "Auth & Notifications"
Cohesion: 0.05
Nodes (35): app.dart, ApiClient, _AuthInterceptor, onRequest, AuthNotifier, AuthState, _clearSession, Exception (+27 more)

### Community 9 - "Sleep & Wellness Data"
Cohesion: 0.06
Nodes (32): ../api/token_store.dart, InitializationSettings, NotificationDetails, NotificationService, _onForegroundMessage, _postToken, showSyncFailedNotification, copyWithMood (+24 more)

### Community 10 - "Wellness & Progress Screens"
Cohesion: 0.06
Nodes (32): build, Column, ProgressScreen, Scaffold, _SectionHeader, SizedBox, build, Center (+24 more)

### Community 11 - "GPS Workout Session"
Cohesion: 0.06
Nodes (31): dispose, _encodeChunk, encodePolyline, GpsService, GpsUpdate, _haversineKm, _onPosition, outdoorCaloriesForExercise (+23 more)

### Community 12 - "Navigation & Routing"
Cohesion: 0.06
Nodes (32): build, _ErrorScreen, GoRouter, NotificationPreferencesScreen, Scaffold, ../features/auth/screens/forgot_password_screen.dart, ../features/auth/screens/login_screen.dart, ../features/auth/screens/signup_screen.dart (+24 more)

### Community 13 - "Progress Charts"
Cohesion: 0.07
Nodes (26): BarChart, BarChartGroupData, build, CalorieTrendChart, _dayAbbr, SideTitleWidget, SizedBox, build (+18 more)

### Community 14 - "Body Stats & Set Logger"
Cohesion: 0.07
Nodes (25): BodyLogScreen, _BodyLogScreenState, build, Column, dispose, Divider, _formatDate, _formatWeight (+17 more)

### Community 15 - "Workout History & Picker"
Cohesion: 0.07
Nodes (25): build, Column, ExercisePickerScreen, _ExercisePickerScreenState, Function, _MuscleGroupSection, Scaffold, SizedBox (+17 more)

### Community 16 - "Food Log Sheet"
Cohesion: 0.08
Nodes (23): _Badge, build, Card, ClipRRect, Container, _FoodImage, FoodResultCard, _MacroRow (+15 more)

### Community 17 - "Offline Sync & AI Coach"
Cohesion: 0.08
Nodes (21): ../api/api_client.dart, CoachMessage, CoachService, UnimplementedError, dispose, _setupConnectivityListener, _setupLifecycleListener, SyncService (+13 more)

### Community 18 - "Nutrition Screen"
Cohesion: 0.12
Nodes (15): build, Center, Column, Container, _DaySummary, _ErrorView, Icon, _MacroTile (+7 more)

### Community 19 - "Drift DB Utilities"
Cohesion: 0.18
Nodes (12): _, copyWith, copyWithCompanion, Function, map, PendingSyncItem, PendingSyncItemsCompanion, RawValuesInsertable (+4 more)

### Community 20 - "Backend Auth Service"
Cohesion: 0.29
Nodes (0): 

### Community 21 - "Unit Tests"
Cohesion: 0.29
Nodes (5): main, main, package:fitcore/core/utils/calorie_calculator.dart, package:fitcore/core/utils/streak_calculator.dart, package:flutter_test/flutter_test.dart

### Community 22 - "Weekly Summary Job"
Cohesion: 0.53
Nodes (5): getConnection(), getWeekBounds(), getWeeklyStats(), scheduleWeeklySummaryJob(), startWeeklySummaryWorker()

### Community 23 - "iOS App Delegate"
Cohesion: 0.33
Nodes (3): AppDelegate, FlutterAppDelegate, FlutterImplicitEngineDelegate

### Community 24 - "Progress Data Models"
Cohesion: 0.33
Nodes (5): DayCalories, ExerciseWeekPoint, ProgressData, WeeklySummary, body_stat.dart

### Community 25 - "App Icons & Branding"
Cohesion: 0.6
Nodes (6): FitCore App Icon (Flutter Default), FitCore iOS Launch Screen (Blank/White), FitCore Mobile App, Flutter Framework, Android Platform, iOS Platform

### Community 26 - "Plugin Registrants"
Cohesion: 0.4
Nodes (2): GeneratedPluginRegistrant, -registerWithRegistry

### Community 27 - "API Response Models"
Cohesion: 0.4
Nodes (4): ApiError, ApiMeta, ApiResponse, Function

### Community 28 - "Calorie Calculator"
Cohesion: 0.4
Nodes (4): ActivityLevel, bmr, dailyTarget, tdee

### Community 29 - "Food Log Models"
Cohesion: 0.4
Nodes (4): DayLogs, DayTotals, FoodLog, _toDouble

### Community 30 - "DB Seed Script"
Cohesion: 0.83
Nodes (3): daysAgo(), hoursAgo(), main()

### Community 31 - "User Routes & TDEE"
Cohesion: 0.5
Nodes (0): 

### Community 32 - "Flutter LLDB Debug Helper"
Cohesion: 0.5
Nodes (2): handle_new_rx_page(), Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.

### Community 33 - "iOS Runner Tests"
Cohesion: 0.5
Nodes (2): RunnerTests, XCTestCase

### Community 34 - "Macro Calculator"
Cohesion: 0.5
Nodes (3): forGoal, MacroTargets, calorie_calculator.dart

### Community 35 - "Auth State Models"
Cohesion: 0.5
Nodes (3): AuthState, copyWith, UserDto

### Community 36 - "Food Item Models"
Cohesion: 0.5
Nodes (3): FoodItem, getNutrient, _toDouble

### Community 37 - "Firebase Push Service"
Cohesion: 1.0
Nodes (2): getFirebaseMessaging(), sendPush()

### Community 38 - "iOS Scene Delegate"
Cohesion: 0.67
Nodes (2): FlutterSceneDelegate, SceneDelegate

### Community 39 - "Streak Calculator"
Cohesion: 0.67
Nodes (2): _dateOnly, dayQualifies

### Community 40 - "Onboarding State"
Cohesion: 0.67
Nodes (2): copyWith, OnboardingData

### Community 41 - "Workout Log Models"
Cohesion: 0.67
Nodes (2): ExerciseSetLog, WorkoutLog

### Community 42 - "Backend Entry Point"
Cohesion: 1.0
Nodes (0): 

### Community 43 - "AI Routes"
Cohesion: 1.0
Nodes (0): 

### Community 44 - "Auth Routes"
Cohesion: 1.0
Nodes (0): 

### Community 45 - "Body Routes"
Cohesion: 1.0
Nodes (0): 

### Community 46 - "Nutrition Routes"
Cohesion: 1.0
Nodes (0): 

### Community 47 - "Social Routes"
Cohesion: 1.0
Nodes (0): 

### Community 48 - "Wellness Routes"
Cohesion: 1.0
Nodes (0): 

### Community 49 - "Workout Routes"
Cohesion: 1.0
Nodes (0): 

### Community 50 - "Android MainActivity"
Cohesion: 1.0
Nodes (1): MainActivity

### Community 51 - "Drift Sync DAO"
Cohesion: 1.0
Nodes (1): SyncDao

### Community 52 - "Body Stat Model"
Cohesion: 1.0
Nodes (1): BodyStat

### Community 53 - "OpenAI Embeddings & Pinecone"
Cohesion: 1.0
Nodes (2): OpenAI text-embedding-3-small, Pinecone Vector DB

### Community 54 - "Health Plugin Bridge"
Cohesion: 1.0
Nodes (2): health Flutter Plugin (HealthKit + Google Fit), health_service.dart

### Community 55 - "Body Repository"
Cohesion: 1.0
Nodes (0): 

### Community 56 - "Nutrition Repository"
Cohesion: 1.0
Nodes (0): 

### Community 57 - "User Repository"
Cohesion: 1.0
Nodes (0): 

### Community 58 - "Wellness Repository"
Cohesion: 1.0
Nodes (0): 

### Community 59 - "Workout Repository"
Cohesion: 1.0
Nodes (0): 

### Community 60 - "Backend Config"
Cohesion: 1.0
Nodes (0): 

### Community 61 - "DB Connection"
Cohesion: 1.0
Nodes (0): 

### Community 62 - "Android Build Config"
Cohesion: 1.0
Nodes (0): 

### Community 63 - "Android Settings"
Cohesion: 1.0
Nodes (0): 

### Community 64 - "App Build Gradle"
Cohesion: 1.0
Nodes (0): 

### Community 65 - "iOS Plugin Header"
Cohesion: 1.0
Nodes (0): 

### Community 66 - "iOS Bridging Header"
Cohesion: 1.0
Nodes (0): 

### Community 67 - "App Routes Constants"
Cohesion: 1.0
Nodes (0): 

### Community 68 - "Backend Index"
Cohesion: 1.0
Nodes (0): 

### Community 69 - "TypeScript Backend"
Cohesion: 1.0
Nodes (1): TypeScript Backend Language

### Community 70 - "Socket.io Real-time"
Cohesion: 1.0
Nodes (1): Socket.io Real-time

### Community 71 - "Cloudinary Storage"
Cohesion: 1.0
Nodes (1): Cloudinary File Storage

### Community 72 - "AWS Infrastructure"
Cohesion: 1.0
Nodes (1): AWS Infrastructure (ECS Fargate + RDS + ElastiCache)

### Community 73 - "GitHub Actions CI/CD"
Cohesion: 1.0
Nodes (1): GitHub Actions CI/CD

### Community 74 - "Open Food Facts API"
Cohesion: 1.0
Nodes (1): Open Food Facts API

### Community 75 - "USDA Food API"
Cohesion: 1.0
Nodes (1): USDA FoodData Central API

### Community 76 - "API Response Envelope"
Cohesion: 1.0
Nodes (1): API Response Envelope

## Knowledge Gaps
- **730 isolated node(s):** `MainActivity`, `Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.`, `-registerWithRegistry`, `FitCoreApp`, `_FitCoreAppState` (+725 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Backend Entry Point`** (2 nodes): `index.ts`, `bootstrap()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `AI Routes`** (2 nodes): `aiRoutes()`, `ai.routes.ts`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Auth Routes`** (2 nodes): `auth.routes.ts`, `authRoutes()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Body Routes`** (2 nodes): `body.routes.ts`, `bodyRoutes()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Nutrition Routes`** (2 nodes): `nutrition.routes.ts`, `nutritionRoutes()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Social Routes`** (2 nodes): `social.routes.ts`, `socialRoutes()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Wellness Routes`** (2 nodes): `wellness.routes.ts`, `wellnessRoutes()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Workout Routes`** (2 nodes): `workout.routes.ts`, `workoutRoutes()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Android MainActivity`** (2 nodes): `MainActivity.kt`, `MainActivity`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Drift Sync DAO`** (2 nodes): `sync_dao.dart`, `SyncDao`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Body Stat Model`** (2 nodes): `body_stat.dart`, `BodyStat`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `OpenAI Embeddings & Pinecone`** (2 nodes): `OpenAI text-embedding-3-small`, `Pinecone Vector DB`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Health Plugin Bridge`** (2 nodes): `health Flutter Plugin (HealthKit + Google Fit)`, `health_service.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Body Repository`** (1 nodes): `body.repository.ts`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Nutrition Repository`** (1 nodes): `nutrition.repository.ts`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `User Repository`** (1 nodes): `user.repository.ts`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Wellness Repository`** (1 nodes): `wellness.repository.ts`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Workout Repository`** (1 nodes): `workout.repository.ts`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Backend Config`** (1 nodes): `config.ts`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `DB Connection`** (1 nodes): `db.ts`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Android Build Config`** (1 nodes): `build.gradle.kts`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Android Settings`** (1 nodes): `settings.gradle.kts`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `App Build Gradle`** (1 nodes): `build.gradle.kts`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `iOS Plugin Header`** (1 nodes): `GeneratedPluginRegistrant.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `iOS Bridging Header`** (1 nodes): `Runner-Bridging-Header.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `App Routes Constants`** (1 nodes): `app_routes.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Backend Index`** (1 nodes): `index.ts`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `TypeScript Backend`** (1 nodes): `TypeScript Backend Language`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Socket.io Real-time`** (1 nodes): `Socket.io Real-time`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Cloudinary Storage`** (1 nodes): `Cloudinary File Storage`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `AWS Infrastructure`** (1 nodes): `AWS Infrastructure (ECS Fargate + RDS + ElastiCache)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `GitHub Actions CI/CD`** (1 nodes): `GitHub Actions CI/CD`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Open Food Facts API`** (1 nodes): `Open Food Facts API`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `USDA Food API`** (1 nodes): `USDA FoodData Central API`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `API Response Envelope`** (1 nodes): `API Response Envelope`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `package:flutter/material.dart` connect `Material UI Components` to `Riverpod State Providers`, `Onboarding Flow`, `UI Widgets & Theme`, `Nutrition & Food Logging`, `Workout Tracking`, `Home Dashboard`, `Auth & Notifications`, `Sleep & Wellness Data`, `Wellness & Progress Screens`, `GPS Workout Session`, `Navigation & Routing`, `Progress Charts`, `Body Stats & Set Logger`, `Workout History & Picker`, `Food Log Sheet`, `Nutrition Screen`?**
  _High betweenness centrality (0.264) - this node is a cross-community bridge._
- **Why does `package:flutter_riverpod/flutter_riverpod.dart` connect `Riverpod State Providers` to `Onboarding Flow`, `Nutrition & Food Logging`, `Workout Tracking`, `Home Dashboard`, `Auth & Notifications`, `Wellness & Progress Screens`, `GPS Workout Session`, `Navigation & Routing`, `Body Stats & Set Logger`, `Workout History & Picker`, `Food Log Sheet`, `Offline Sync & AI Coach`, `Nutrition Screen`?**
  _High betweenness centrality (0.232) - this node is a cross-community bridge._
- **Why does `../../../core/theme/app_colors.dart` connect `UI Widgets & Theme` to `Onboarding Flow`, `Material UI Components`, `Nutrition & Food Logging`, `Home Dashboard`, `Auth & Notifications`, `Sleep & Wellness Data`, `Wellness & Progress Screens`, `Progress Charts`, `Food Log Sheet`, `Nutrition Screen`?**
  _High betweenness centrality (0.079) - this node is a cross-community bridge._
- **What connects `MainActivity`, `Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.`, `-registerWithRegistry` to the rest of the system?**
  _730 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Riverpod State Providers` be split into smaller, more focused modules?**
  _Cohesion score 0.03 - nodes in this community are weakly interconnected._
- **Should `Onboarding Flow` be split into smaller, more focused modules?**
  _Cohesion score 0.03 - nodes in this community are weakly interconnected._
- **Should `UI Widgets & Theme` be split into smaller, more focused modules?**
  _Cohesion score 0.03 - nodes in this community are weakly interconnected._