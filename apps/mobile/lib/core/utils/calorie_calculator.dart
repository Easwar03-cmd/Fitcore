/// Mifflin-St Jeor BMR + TDEE + goal adjustment.
/// All rules from CLAUDE.md spec.
abstract final class CalorieCalculator {
  /// BMR in kcal/day.
  static double bmr({
    required double weightKg,
    required double heightCm,
    required int ageYears,
    required bool isMale,
  }) {
    final base = (10 * weightKg) + (6.25 * heightCm) - (5 * ageYears);
    return isMale ? base + 5 : base - 161;
  }

  /// TDEE = BMR × activity multiplier.
  static double tdee({
    required double weightKg,
    required double heightCm,
    required int ageYears,
    required bool isMale,
    required ActivityLevel activityLevel,
  }) {
    return bmr(
          weightKg: weightKg,
          heightCm: heightCm,
          ageYears: ageYears,
          isMale: isMale,
        ) *
        activityLevel.multiplier;
  }

  /// Daily calorie target after goal adjustment.
  static double dailyTarget({
    required double tdeeKcal,
    required FitnessGoal goal,
  }) {
    return switch (goal) {
      FitnessGoal.loseWeight => tdeeKcal - 500,
      FitnessGoal.buildMuscle => tdeeKcal + 300,
      FitnessGoal.maintain || FitnessGoal.endurance => tdeeKcal,
    };
  }
}

enum ActivityLevel {
  sedentary(1.2),
  light(1.375),
  moderate(1.55),
  active(1.725),
  veryActive(1.9);

  const ActivityLevel(this.multiplier);
  final double multiplier;
}

enum FitnessGoal { loseWeight, buildMuscle, maintain, endurance }
