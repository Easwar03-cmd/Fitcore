import '../../workout/models/workout_log.dart';
import 'body_stat.dart';

class DayCalories {
  const DayCalories({
    required this.date,
    required this.calories,
    required this.target,
  });

  final DateTime date;
  final double calories;
  final int target;

  bool get isUnder => calories <= target;
}

class ExerciseWeekPoint {
  const ExerciseWeekPoint({
    required this.weekStart,
    required this.maxWeightKg,
  });

  final DateTime weekStart;
  final double maxWeightKg;
}

class WeeklySummary {
  const WeeklySummary({
    required this.workoutsCompleted,
    required this.avgDailyCalories,
    required this.totalVolumeKg,
  });

  final int workoutsCompleted;
  final double avgDailyCalories;

  /// Sum of (reps × weightKg) for every set in the week.
  final double totalVolumeKg;
}

class ProgressData {
  const ProgressData({
    required this.bodyStats,
    required this.calorieTrend,
    required this.strengthCurves,
    required this.muscleVolume,
    required this.thisWeek,
    required this.lastWeek,
    required this.calorieTarget,
    required this.recentWorkouts,
  });

  /// Body weight entries sorted oldest → newest (up to last 30).
  final List<BodyStat> bodyStats;

  /// Last 7 days ordered oldest → newest.
  final List<DayCalories> calorieTrend;

  /// Top 3 most-logged exercises → weekly max weight points for last 8 weeks.
  final Map<String, List<ExerciseWeekPoint>> strengthCurves;

  /// Total sets per muscle group logged this calendar week.
  final Map<String, int> muscleVolume;

  final WeeklySummary thisWeek;
  final WeeklySummary lastWeek;

  /// User's daily calorie target from their TDEE.
  final int calorieTarget;

  /// Last 5 workout logs for the "Recent Workouts" card in the progress tab.
  final List<WorkoutLog> recentWorkouts;

  static const ProgressData empty = ProgressData(
    bodyStats: [],
    calorieTrend: [],
    strengthCurves: {},
    muscleVolume: {},
    thisWeek: WeeklySummary(
        workoutsCompleted: 0, avgDailyCalories: 0, totalVolumeKg: 0),
    lastWeek: WeeklySummary(
        workoutsCompleted: 0, avgDailyCalories: 0, totalVolumeKg: 0),
    calorieTarget: 0,
    recentWorkouts: [],
  );
}
