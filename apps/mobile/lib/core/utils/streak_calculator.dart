/// Streak logic from CLAUDE.md spec:
/// - Increments if user logs food, a workout, OR hits 7500+ steps
/// - Resets at midnight local time if none of the above
/// - Grace period: one missed day allowed per 7-day window ("streak shield")
abstract final class StreakCalculator {
  static const int minStepsForStreak = 7500;

  /// Returns true if the day qualifies for a streak increment.
  static bool dayQualifies({
    required bool hasFoodLog,
    required bool hasWorkoutLog,
    required int steps,
  }) {
    return hasFoodLog || hasWorkoutLog || steps >= minStepsForStreak;
  }

  /// Compute current streak given a list of qualifying dates (sorted desc).
  /// [graceUsed] tracks whether the grace period for the current 7-day window is consumed.
  static ({int streak, bool graceUsed}) computeStreak({
    required List<DateTime> qualifyingDates,
    required DateTime now,
  }) {
    if (qualifyingDates.isEmpty) return (streak: 0, graceUsed: false);

    final today = _dateOnly(now);
    int streak = 0;
    bool graceUsed = false;
    DateTime expected = today;

    for (final date in qualifyingDates) {
      final d = _dateOnly(date);
      if (d == expected) {
        streak++;
        expected = expected.subtract(const Duration(days: 1));
      } else if (d == expected.subtract(const Duration(days: 1)) && !graceUsed) {
        // One missed day — apply grace shield; d is still a qualifying day
        graceUsed = true;
        streak++;
        expected = d.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return (streak: streak, graceUsed: graceUsed);
  }

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}
