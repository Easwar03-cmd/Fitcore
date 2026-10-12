import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_routes.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/nutrition/screens/barcode_screen.dart';
import '../features/nutrition/screens/food_search_screen.dart';
import '../features/nutrition/screens/food_photo_screen.dart';
import '../features/nutrition/screens/meal_plan_screen.dart';
import '../features/nutrition/screens/nutrition_screen.dart';
import '../features/onboarding/screens/activity_level_screen.dart';
import '../features/onboarding/screens/body_stats_screen.dart';
import '../features/onboarding/screens/goal_selection_screen.dart';
import '../features/progress/screens/body_log_screen.dart';
import '../features/progress/screens/progress_screen.dart';
import '../features/settings/screens/notification_preferences_screen.dart';
import '../features/settings/screens/profile_screen.dart';
import '../features/settings/screens/wearable_integrations_screen.dart';
import '../features/subscription/screens/paywall_screen.dart';
import '../features/subscription/screens/subscription_screen.dart';
import '../features/community/screens/community_screen.dart';
import '../features/workout/screens/active_workout_screen.dart';
import '../features/workout/screens/exercise_picker_screen.dart';
import '../features/workout/screens/gym_workout_screen.dart';
import '../features/workout/screens/home_workout_list_screen.dart';
import '../features/workout/screens/workout_history_screen.dart';
import '../features/workout/screens/workout_screen.dart';
import '../features/workout/screens/workout_summary_screen.dart';
import 'main_shell.dart';
import 'router_notifier.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = RouterNotifier(ref);
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      // ── Splash ──────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // ── Auth ────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        name: 'signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // ── Onboarding ──────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.goalSelection,
        name: 'goal-selection',
        builder: (context, state) => const GoalSelectionScreen(),
      ),
      GoRoute(
        path: AppRoutes.bodyStats,
        name: 'body-stats',
        builder: (context, state) => const BodyStatsScreen(),
      ),
      GoRoute(
        path: AppRoutes.activityLevel,
        name: 'activity-level',
        builder: (context, state) => const ActivityLevelScreen(),
      ),

      // ── Main shell (4-tab bottom nav) ────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            name: 'home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.nutrition,
            name: 'nutrition',
            builder: (context, state) => const NutritionScreen(),
            routes: [
              GoRoute(
                path: 'search',
                name: 'food-search',
                builder: (context, state) => FoodSearchScreen(
                  initialMealType: state.extra as String?,
                ),
              ),
              GoRoute(
                path: 'barcode',
                name: 'barcode',
                builder: (context, state) => const BarcodeScreen(),
              ),
              GoRoute(
                path: 'meal-plan',
                name: 'meal-plan',
                builder: (context, state) => const MealPlanScreen(),
              ),
              GoRoute(
                path: 'food-photo',
                name: 'food-photo',
                builder: (context, state) => const FoodPhotoScreen(),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.workout,
            name: 'workout',
            builder: (context, state) => const WorkoutScreen(),
            routes: [
              GoRoute(
                path: 'exercises',
                name: 'exercise-picker',
                builder: (context, state) => const ExercisePickerScreen(),
              ),
              GoRoute(
                path: 'active',
                name: 'active-workout',
                builder: (context, state) => const ActiveWorkoutScreen(),
              ),
              GoRoute(
                path: 'summary',
                name: 'workout-summary',
                builder: (context, state) => const WorkoutSummaryScreen(),
              ),
              GoRoute(
                path: 'history',
                name: 'workout-history',
                builder: (context, state) => const WorkoutHistoryScreen(),
              ),
              GoRoute(
                path: 'gym',
                name: 'gym-workout',
                builder: (context, state) => const GymWorkoutScreen(),
              ),
              GoRoute(
                path: 'home',
                name: 'home-workouts',
                builder: (context, state) => HomeWorkoutListScreen(
                  pickMode: state.extra == true,
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.progress,
            name: 'progress',
            builder: (context, state) => const ProgressScreen(),
            routes: [
              GoRoute(
                path: 'body',
                name: 'body-log',
                builder: (context, state) => const BodyLogScreen(),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.community,
            name: 'community',
            builder: (context, state) => const CommunityScreen(),
          ),
        ],
      ),

      // ── Top-level features (outside bottom nav) ──────────────────────────
      GoRoute(
        path: AppRoutes.profile,
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
        routes: [
          GoRoute(
            path: 'notifications',
            name: 'notification-prefs',
            builder: (context, state) => const NotificationPreferencesScreen(),
          ),
          GoRoute(
            path: 'wearables',
            name: 'wearable-integrations',
            builder: (context, state) => const WearableIntegrationsScreen(),
          ),
          GoRoute(
            path: 'subscription',
            name: 'subscription',
            builder: (context, state) => const SubscriptionScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.paywall,
        name: 'paywall',
        builder: (context, state) => PaywallScreen(
          highlightFeature: state.extra as String?,
        ),
      ),
    ],

    errorBuilder: (context, state) => _ErrorScreen(uri: state.uri.toString()),
  );
});

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.uri});
  final String uri;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('Page not found: $uri')));
  }
}
