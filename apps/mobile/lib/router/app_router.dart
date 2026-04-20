import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_routes.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/coach/screens/coach_screen.dart';
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
import '../features/social/screens/challenges_screen.dart';
import '../features/social/screens/friend_search_screen.dart';
import '../features/social/screens/leaderboard_screen.dart';
import '../features/social/screens/social_screen.dart';
import '../features/wellness/screens/wellness_screen.dart';
import '../features/workout/screens/active_workout_screen.dart';
import '../features/workout/screens/exercise_picker_screen.dart';
import '../features/workout/screens/home_workout_list_screen.dart';
import '../features/workout/screens/workout_history_screen.dart';
import '../features/workout/screens/workout_screen.dart';
import '../features/workout/screens/workout_summary_screen.dart';
import 'main_shell.dart';
import 'router_notifier.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = RouterNotifier(ref);
  return GoRouter(
    initialLocation: AppRoutes.login,
    debugLogDiagnostics: true,
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
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
            path: AppRoutes.wellness,
            name: 'wellness',
            builder: (context, state) => const WellnessScreen(),
          ),
        ],
      ),

      // ── Top-level features (outside bottom nav) ──────────────────────────
      GoRoute(
        path: AppRoutes.coach,
        name: 'coach',
        builder: (context, state) => const CoachScreen(),
      ),
      GoRoute(
        path: AppRoutes.social,
        name: 'social',
        builder: (context, state) => const SocialScreen(),
        routes: [
          GoRoute(
            path: 'search',
            name: 'friend-search',
            builder: (context, state) => const FriendSearchScreen(),
          ),
          GoRoute(
            path: 'challenges',
            name: 'challenges',
            builder: (context, state) => const ChallengesScreen(),
          ),
          GoRoute(
            path: 'leaderboard',
            name: 'leaderboard',
            builder: (context, state) => const LeaderboardScreen(),
          ),
        ],
      ),
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
        ],
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
