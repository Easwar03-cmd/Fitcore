import '../../../core/utils/calorie_calculator.dart';

/// Mirrors the backend GET /api/v1/user/profile response shape.
class UserProfileDto {
  const UserProfileDto({
    required this.tdee,
    required this.fitnessGoal,
    required this.activityLevel,
    this.weightKg,
  });

  final int tdee;

  /// Raw string from backend: "lose_weight" | "build_muscle" | "maintain" | "endurance"
  final String fitnessGoal;
  final String activityLevel;
  final double? weightKg;

  factory UserProfileDto.fromJson(Map<String, dynamic> json) => UserProfileDto(
        tdee: (json['tdee'] as num?)?.toInt() ?? 2000,
        fitnessGoal: json['fitnessGoal'] as String? ?? 'maintain',
        activityLevel: json['activityLevel'] as String? ?? 'moderate',
        weightKg: (json['weightKg'] as num?)?.toDouble(),
      );

  /// Fallback used when the profile fetch fails gracefully.
  static const fallback = UserProfileDto(
    tdee: 2000,
    fitnessGoal: 'maintain',
    activityLevel: 'moderate',
  );
}

/// All data the home dashboard needs, held in Riverpod state.
class HomeDashboardState {
  const HomeDashboardState({
    required this.tdee,
    required this.fitnessGoal,
    required this.activityLevel,
    required this.steps,
    required this.waterMl,
    required this.streak,
    required this.graceUsed,
    this.caloriesBurnedToday = 0,
  });

  /// Raw TDEE from backend (no goal adjustment applied yet).
  final int tdee;

  /// Raw goal string from backend — "lose_weight" | "build_muscle" | "maintain" | "endurance"
  final String fitnessGoal;

  /// Raw activity level string — "sedentary" | "light" | "moderate" | "active" | "very_active"
  final String activityLevel;

  final int steps;
  final int waterMl;
  final int streak;

  /// True when the user has consumed their one-per-7-day streak shield.
  final bool graceUsed;

  /// Kcal burned in workouts logged today.
  final int caloriesBurnedToday;

  /// Converts the raw fitnessGoal string to the typed enum used by CalorieCalculator.
  FitnessGoal get goal => switch (fitnessGoal) {
        'lose_weight' => FitnessGoal.loseWeight,
        'build_muscle' => FitnessGoal.buildMuscle,
        'endurance' => FitnessGoal.endurance,
        _ => FitnessGoal.maintain,
      };

  /// Goal-adjusted base target (weight loss −500, muscle gain +300, else =TDEE).
  int get baseTarget => CalorieCalculator.dailyTarget(
        tdeeKcal: tdee.toDouble(),
        goal: goal,
      ).round();

  /// Full calorie budget for today: goal-adjusted TDEE + calories burned in workouts.
  int get adaptiveTarget => baseTarget + caloriesBurnedToday;

  /// Daily water target in ml derived from activity level.
  /// Formula: 35 ml/kg is ideal but weight isn't always available, so we use
  /// activity-level tiers as a reasonable proxy.
  int get waterTargetMl => switch (activityLevel) {
        'light' => 2250,
        'moderate' => 2500,
        'active' => 2750,
        'very_active' => 3000,
        _ => 2000, // sedentary
      };

  HomeDashboardState copyWith({
    int? tdee,
    String? fitnessGoal,
    String? activityLevel,
    int? steps,
    int? waterMl,
    int? streak,
    bool? graceUsed,
    int? caloriesBurnedToday,
  }) =>
      HomeDashboardState(
        tdee: tdee ?? this.tdee,
        fitnessGoal: fitnessGoal ?? this.fitnessGoal,
        activityLevel: activityLevel ?? this.activityLevel,
        steps: steps ?? this.steps,
        waterMl: waterMl ?? this.waterMl,
        streak: streak ?? this.streak,
        graceUsed: graceUsed ?? this.graceUsed,
        caloriesBurnedToday: caloriesBurnedToday ?? this.caloriesBurnedToday,
      );
}
