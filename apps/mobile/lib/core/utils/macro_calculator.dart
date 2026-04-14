import 'calorie_calculator.dart';

class MacroTargets {
  const MacroTargets({
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  final double proteinG;
  final double carbsG;
  final double fatG;
}

/// Macro splits from CLAUDE.md spec.
/// protein/carbs = 4 kcal/g, fat = 9 kcal/g
abstract final class MacroCalculator {
  static MacroTargets forGoal({
    required double dailyKcal,
    required FitnessGoal goal,
  }) {
    final (proteinPct, carbsPct, fatPct) = switch (goal) {
      FitnessGoal.loseWeight => (0.40, 0.30, 0.30),
      FitnessGoal.buildMuscle => (0.30, 0.50, 0.20),
      FitnessGoal.maintain || FitnessGoal.endurance => (0.30, 0.40, 0.30),
    };

    return MacroTargets(
      proteinG: (dailyKcal * proteinPct) / 4,
      carbsG: (dailyKcal * carbsPct) / 4,
      fatG: (dailyKcal * fatPct) / 9,
    );
  }
}
