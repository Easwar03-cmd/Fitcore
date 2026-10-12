abstract final class AppRoutes {
  // Splash
  static const splash = '/splash';

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
  static const mealPlan = '/nutrition/meal-plan';
  static const foodPhoto = '/nutrition/food-photo';

  // Workout sub-routes
  static const exercisePicker = '/workout/exercises';
  static const activeWorkout = '/workout/active';
  static const workoutSummary = '/workout/summary';
  static const workoutHistory = '/workout/history';
  static const homeWorkouts = '/workout/home';
  static const gymWorkout = '/workout/gym';

  // Progress sub-routes
  static const bodyLog = '/progress/body';

  // Top-level features (outside bottom nav)
  static const community = '/community';
  static const communityCreate = '/community/create';
  static const communitySearch = '/community/search';
  static const communityTodo = '/community/todo';
  static String communityJoinPath(String code) => '/community/join/$code';
  static String communityChatPath(String id) => '/community/$id';
  static String communityInfoPath(String id) => '/community/$id/info';
  static String communityAdminPath(String id) => '/community/$id/admin';
  static String communityMemberPath(String id, String userId) =>
      '/community/$id/member/$userId';
  static String communityChallengesPath(String id) =>
      '/community/$id/challenges';
  static String communityNewChallengePath(String id) =>
      '/community/$id/challenges/new';
  static String communityChallengePath(String id, String challengeId) =>
      '/community/$id/challenge/$challengeId';
  static const profile = '/profile';
  static const notificationPrefs = '/profile/notifications';
  static const wearableIntegrations = '/profile/wearables';
  static const subscription = '/profile/subscription';
  static const paywall = '/paywall';
}
