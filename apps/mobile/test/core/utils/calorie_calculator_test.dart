import 'package:revive/core/utils/calorie_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalorieCalculator', () {
    test('BMR male', () {
      // (10×80)+(6.25×180)−(5×30)+5 = 800+1125−150+5 = 1780
      final result = CalorieCalculator.bmr(
        weightKg: 80,
        heightCm: 180,
        ageYears: 30,
        isMale: true,
      );
      expect(result, closeTo(1780, 0.01));
    });

    test('BMR female', () {
      // (10×60)+(6.25×165)−(5×25)−161 = 600+1031.25−125−161 = 1345.25
      final result = CalorieCalculator.bmr(
        weightKg: 60,
        heightCm: 165,
        ageYears: 25,
        isMale: false,
      );
      expect(result, closeTo(1345.25, 0.01));
    });

    test('TDEE moderate activity', () {
      final bmrVal = CalorieCalculator.bmr(weightKg: 80, heightCm: 180, ageYears: 30, isMale: true);
      final result = CalorieCalculator.tdee(
        weightKg: 80,
        heightCm: 180,
        ageYears: 30,
        isMale: true,
        activityLevel: ActivityLevel.moderate,
      );
      expect(result, closeTo(bmrVal * 1.55, 0.01));
    });

    test('dailyTarget loseWeight subtracts 500', () {
      const tdee = 2000.0;
      final result = CalorieCalculator.dailyTarget(tdeeKcal: tdee, goal: FitnessGoal.loseWeight);
      expect(result, 1500.0);
    });

    test('dailyTarget buildMuscle adds 300', () {
      const tdee = 2000.0;
      final result = CalorieCalculator.dailyTarget(tdeeKcal: tdee, goal: FitnessGoal.buildMuscle);
      expect(result, 2300.0);
    });

    test('dailyTarget maintain equals TDEE', () {
      const tdee = 2000.0;
      final result = CalorieCalculator.dailyTarget(tdeeKcal: tdee, goal: FitnessGoal.maintain);
      expect(result, 2000.0);
    });
  });
}
