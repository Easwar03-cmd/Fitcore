import '../../../core/utils/calorie_calculator.dart';

/// Mirrors the backend GET /api/v1/user/profile response shape.
class UserProfileDto {
  const UserProfileDto({
    required this.tdee,
    required this.fitnessGoal,
    required this.activityLevel,
  });

  final int tdee;

  /// Raw string from backend: "lose_weight" | "build_muscle" | "maintain" | "endurance"
  final String fitnessGoal;
  final String activityLevel;

  factory UserProfileDto.fromJson(Map<String, dynamic> json) => UserProfileDto(
        tdee: (json['tdee'] as num?)?.toInt() ?? 2000,
        fitnessGoal: json['fitnessGoal'] as String? ?? 'maintain',
        activityLevel: json['activityLevel'] as String? ?? 'moderate',
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
    required this.steps,
    required this.waterMl,
    required this.streak,
    required this.graceUsed,
  });

  final int tdee;

  /// Raw goal string from backend — "lose_weight" | "build_muscle" | "maintain" | "endurance"
  final String fitnessGoal;
  final int steps;
  final int waterMl;
  final int streak;

  /// True when the user has consumed their one-per-7-day streak shield.
  final bool graceUsed;

  HomeDashboardState copyWith({
    int? tdee,
    String? fitnessGoal,
    int? steps,
    int? waterMl,
    int? streak,
    bool? graceUsed,
  }) =>
      HomeDashboardState(
        tdee: tdee ?? this.tdee,
        fitnessGoal: fitnessGoal ?? this.fitnessGoal,
        steps: steps ?? this.steps,
        waterMl: waterMl ?? this.waterMl,
        streak: streak ?? this.streak,
        graceUsed: graceUsed ?? this.graceUsed,
      );

  /// Converts the raw fitnessGoal string to the typed enum used by MacroCalculator.
  FitnessGoal get goal => switch (fitnessGoal) {
        'lose_weight' => FitnessGoal.loseWeight,
        'build_muscle' => FitnessGoal.buildMuscle,
        'endurance' => FitnessGoal.endurance,
        _ => FitnessGoal.maintain,
      };
}
