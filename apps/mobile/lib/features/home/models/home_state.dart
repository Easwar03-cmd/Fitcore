import '../../../core/utils/calorie_calculator.dart';

/// Mirrors the backend GET /api/v1/user/profile response shape.
/// The API returns { user: {...}, profile: {...} } — fromJson handles both keys.
class UserProfileDto {
  const UserProfileDto({
    required this.tdee,
    required this.fitnessGoal,
    required this.activityLevel,
    this.weightKg,
    this.heightCm,
  });

  final int tdee;

  /// Raw string from backend: "lose_weight" | "build_muscle" | "maintain" | "endurance"
  final String fitnessGoal;
  final String activityLevel;

  /// Latest body weight from BodyStat — used for personalised water & step targets.
  final double? weightKg;

  /// Body height in cm from User record — available for future BMI/BMR display.
  final double? heightCm;

  /// Parses the nested { user, profile } envelope returned by GET /api/v1/user/profile.
  factory UserProfileDto.fromJson(Map<String, dynamic> json) {
    // The API wraps fields in a "profile" sub-object; fall back to top-level for
    // backwards-compat if the structure ever changes.
    final p = (json['profile'] as Map<String, dynamic>?) ?? json;
    return UserProfileDto(
      tdee: (p['tdee'] as num?)?.toInt() ?? 2000,
      fitnessGoal: p['fitnessGoal'] as String? ?? 'maintain',
      activityLevel: p['activityLevel'] as String? ?? 'moderate',
      weightKg: (p['currentWeightKg'] as num?)?.toDouble(),
      heightCm: (p['heightCm'] as num?)?.toDouble(),
    );
  }

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
    this.weightKg,
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

  /// Latest body weight — drives personalised water and step targets.
  final double? weightKg;

  /// Kcal burned in workouts logged today.
  final int caloriesBurnedToday;

  // ── Derived targets ──────────────────────────────────────────────────────────

  /// Converts the raw fitnessGoal string to the typed enum used by CalorieCalculator.
  FitnessGoal get goal => switch (fitnessGoal) {
        'lose_weight' => FitnessGoal.loseWeight,
        'build_muscle' => FitnessGoal.buildMuscle,
        'endurance' => FitnessGoal.endurance,
        _ => FitnessGoal.maintain,
      };

  /// Goal-adjusted base calorie target (weight loss −500, muscle gain +300, else =TDEE).
  int get baseTarget => CalorieCalculator.dailyTarget(
        tdeeKcal: tdee.toDouble(),
        goal: goal,
      ).round();

  /// Full calorie budget for today: goal-adjusted TDEE + calories burned in workouts.
  int get adaptiveTarget => baseTarget + caloriesBurnedToday;

  /// Personalised daily step goal.
  ///
  /// Base by activity level (evidence-based WHO/ACSM tiers):
  ///   sedentary → 7,000 | light → 8,500 | moderate → 10,000
  ///   active → 12,000  | very_active → 15,000
  ///
  /// Goal adjustment:
  ///   lose_weight  +2,000  (extra NEAT accelerates fat loss)
  ///   endurance    +3,000  (zone-2 volume is core to endurance training)
  ///   build_muscle     +0  (excessive steps can reduce hypertrophy recovery)
  ///   maintain         +0
  int get stepGoal {
    final base = switch (activityLevel) {
      'light' => 8500,
      'moderate' => 10000,
      'active' => 12000,
      'very_active' => 15000,
      _ => 7000, // sedentary
    };
    final bonus = switch (fitnessGoal) {
      'lose_weight' => 2000,
      'endurance' => 3000,
      _ => 0,
    };
    return (base + bonus).clamp(5000, 20000);
  }

  /// Personalised daily water target in ml.
  ///
  /// Formula: weightKg × ml_per_kg, where ml_per_kg varies by activity:
  ///   sedentary 30 | light 33 | moderate 35 | active 38 | very_active 40
  ///
  /// Result is rounded to the nearest 50 ml and clamped to 1,500–5,000 ml.
  /// Falls back to activity-level buckets when weight is unknown.
  int get waterTargetMl {
    final mlPerKg = switch (activityLevel) {
      'light' => 33,
      'moderate' => 35,
      'active' => 38,
      'very_active' => 40,
      _ => 30, // sedentary
    };

    final weight = weightKg;
    if (weight != null && weight > 0) {
      final raw = weight * mlPerKg;
      final rounded = ((raw / 50).round() * 50).toInt();
      return rounded.clamp(1500, 5000);
    }

    // No weight available — fall back to activity-level buckets.
    return switch (activityLevel) {
      'light' => 2300,
      'moderate' => 2500,
      'active' => 2650,
      'very_active' => 3000,
      _ => 2000,
    };
  }

  HomeDashboardState copyWith({
    int? tdee,
    String? fitnessGoal,
    String? activityLevel,
    int? steps,
    int? waterMl,
    int? streak,
    bool? graceUsed,
    double? weightKg,
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
        weightKg: weightKg ?? this.weightKg,
        caloriesBurnedToday: caloriesBurnedToday ?? this.caloriesBurnedToday,
      );
}
