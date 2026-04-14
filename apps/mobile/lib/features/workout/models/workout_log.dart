class ExerciseSetLog {
  const ExerciseSetLog({
    required this.id,
    required this.exerciseName,
    required this.setNumber,
    this.reps,
    this.weightKg,
    this.durationSec,
  });

  final String id;
  final String exerciseName;
  final int setNumber;
  final int? reps;
  final double? weightKg;
  final int? durationSec;

  String get detail {
    if (reps != null && weightKg != null) return '$reps reps × $weightKg kg';
    if (reps != null) return '$reps reps';
    if (weightKg != null) return '$weightKg kg';
    if (durationSec != null) return '${durationSec}s';
    return '—';
  }

  factory ExerciseSetLog.fromJson(Map<String, dynamic> json) => ExerciseSetLog(
        id: json['id'] as String,
        exerciseName: json['exerciseName'] as String,
        setNumber: json['setNumber'] as int,
        reps: json['reps'] as int?,
        weightKg: json['weightKg'] != null
            ? (json['weightKg'] as num).toDouble()
            : null,
        durationSec: json['durationSec'] as int?,
      );
}

class WorkoutLog {
  const WorkoutLog({
    required this.id,
    required this.name,
    required this.startedAt,
    this.finishedAt,
    this.durationMin,
    this.caloriesBurned,
    required this.sets,
  });

  final String id;
  final String name;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final int? durationMin;
  final int? caloriesBurned;
  final List<ExerciseSetLog> sets;

  /// Sets grouped by exercise name, preserving order of first occurrence.
  Map<String, List<ExerciseSetLog>> get setsByExercise {
    final map = <String, List<ExerciseSetLog>>{};
    for (final s in sets) {
      (map[s.exerciseName] ??= []).add(s);
    }
    return map;
  }

  factory WorkoutLog.fromJson(Map<String, dynamic> json) => WorkoutLog(
        id: json['id'] as String,
        name: json['name'] as String,
        startedAt: DateTime.parse(json['startedAt'] as String),
        finishedAt: json['finishedAt'] != null
            ? DateTime.parse(json['finishedAt'] as String)
            : null,
        durationMin: json['durationMin'] as int?,
        caloriesBurned: json['caloriesBurned'] as int?,
        sets: (json['sets'] as List<dynamic>)
            .map((e) => ExerciseSetLog.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
