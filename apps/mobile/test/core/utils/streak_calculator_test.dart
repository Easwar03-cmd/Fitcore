import 'package:zenfit/core/utils/streak_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StreakCalculator.dayQualifies', () {
    test('qualifies with food log', () {
      expect(StreakCalculator.dayQualifies(hasFoodLog: true, hasWorkoutLog: false, steps: 0), isTrue);
    });

    test('qualifies with workout log', () {
      expect(StreakCalculator.dayQualifies(hasFoodLog: false, hasWorkoutLog: true, steps: 0), isTrue);
    });

    test('qualifies with 7500 steps', () {
      expect(StreakCalculator.dayQualifies(hasFoodLog: false, hasWorkoutLog: false, steps: 7500), isTrue);
    });

    test('does not qualify below 7500 steps and no logs', () {
      expect(StreakCalculator.dayQualifies(hasFoodLog: false, hasWorkoutLog: false, steps: 7499), isFalse);
    });
  });

  group('StreakCalculator.computeStreak', () {
    final now = DateTime(2024, 6, 10);

    test('consecutive days', () {
      final dates = [
        DateTime(2024, 6, 10),
        DateTime(2024, 6, 9),
        DateTime(2024, 6, 8),
      ];
      final result = StreakCalculator.computeStreak(qualifyingDates: dates, now: now);
      expect(result.streak, 3);
      expect(result.graceUsed, isFalse);
    });

    test('grace period for one missed day', () {
      final dates = [
        DateTime(2024, 6, 10),
        // June 9 missing — grace
        DateTime(2024, 6, 8),
        DateTime(2024, 6, 7),
      ];
      final result = StreakCalculator.computeStreak(qualifyingDates: dates, now: now);
      expect(result.streak, 3);
      expect(result.graceUsed, isTrue);
    });

    test('empty dates returns zero streak', () {
      final result = StreakCalculator.computeStreak(qualifyingDates: [], now: now);
      expect(result.streak, 0);
    });
  });
}
