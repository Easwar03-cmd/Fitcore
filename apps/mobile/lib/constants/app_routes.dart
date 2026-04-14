abstract final class AppRoutes {
  // Auth
  static const login = '/login';
  static const signup = '/signup';
  static const forgotPassword = '/forgot-password';

  // Onboarding
  static const goalSelection = '/onboarding/goal';
  static const bodyStats = '/onboarding/body-stats';
  static const activityLevel = '/onboarding/activity';

  // Shell / tabs (4 tabs)
  static const home = '/home';
  static const nutrition = '/nutrition';
  static const workout = '/workout';
  static const progress = '/progress';

  // Nutrition sub-routes
  static const foodSearch = '/nutrition/search';
  static const barcode = '/nutrition/barcode';

  // Workout sub-routes
  static const exercisePicker = '/workout/exercises';
  static const activeWorkout = '/workout/active';
  static const workoutSummary = '/workout/summary';
  static const workoutHistory = '/workout/history';

  // Progress sub-routes
  static const bodyLog = '/progress/body';

  // Social (accessed from AppBar, outside bottom nav)
  static const social = '/social';
  static const friendSearch = '/social/search';
  static const challenges = '/social/challenges';
  static const leaderboard = '/social/leaderboard';

  // Top-level features (outside bottom nav)
  static const coach = '/coach';
  static const wellness = '/wellness';
  static const profile = '/profile';
  static const notificationPrefs = '/profile/notifications';
}
