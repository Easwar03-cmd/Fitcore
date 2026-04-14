import 'package:latlong2/latlong.dart';

import 'exercise.dart';

class LoggedSet {
  const LoggedSet({
    required this.exerciseId,
    required this.exerciseName,
    required this.setNumber,
    this.reps,
    this.weightKg,
    this.durationSec,
  });

  final String exerciseId;
  final String exerciseName;
  final int setNumber;
  final int? reps;
  final double? weightKg;
  final int? durationSec;
}

class WorkoutSummary {
  const WorkoutSummary({
    required this.workoutName,
    required this.totalSets,
    required this.durationMin,
    required this.caloriesBurned,
    required this.exerciseNames,
    this.distanceKm,
    this.routePolyline,
    this.routePoints = const [],
  });

  final String workoutName;
  final int totalSets;
  final int durationMin;
  final int caloriesBurned;
  final List<String> exerciseNames;

  /// Total outdoor distance, null when GPS tracking was not active.
  final double? distanceKm;

  /// Google Encoded Polyline string for backend storage.
  final String? routePolyline;

  /// Decoded route for flutter_map display (same points, no extra decode step).
  final List<LatLng> routePoints;
}

class WorkoutSessionState {
  const WorkoutSessionState({
    this.startedAt,
    this.currentExercise,
    this.allSets = const [],
    this.isResting = false,
    this.restSecondsLeft = 0,
    this.isSubmitting = false,
    this.summary,
    // GPS / outdoor
    this.isOutdoorMode = false,
    this.routePoints = const [],
    this.distanceKm = 0.0,
    this.paceMinPerKm,
  });

  final DateTime? startedAt;
  final Exercise? currentExercise;
  final List<LoggedSet> allSets;
  final bool isResting;
  final int restSecondsLeft;
  final bool isSubmitting;
  final WorkoutSummary? summary;

  // ── GPS / outdoor mode ──────────────────────────────────────────────────────

  /// Whether outdoor GPS tracking is currently active.
  final bool isOutdoorMode;

  /// Accumulated route coordinates from the GPS service.
  final List<LatLng> routePoints;

  /// Total distance in km as reported by the GPS service.
  final double distanceKm;

  /// Rolling pace in min/km; null until enough movement is recorded.
  final double? paceMinPerKm;

  bool get isActive => startedAt != null && summary == null;

  List<LoggedSet> get setsForCurrentExercise => currentExercise == null
      ? const []
      : allSets.where((s) => s.exerciseId == currentExercise!.id).toList();

  int get nextSetNumber => setsForCurrentExercise.length + 1;

  WorkoutSessionState copyWith({
    DateTime? startedAt,
    Exercise? currentExercise,
    List<LoggedSet>? allSets,
    bool? isResting,
    int? restSecondsLeft,
    bool? isSubmitting,
    WorkoutSummary? summary,
    bool? isOutdoorMode,
    List<LatLng>? routePoints,
    double? distanceKm,
    // Use a wrapper to allow setting paceMinPerKm to null explicitly.
    Object? paceMinPerKm = _sentinel,
  }) =>
      WorkoutSessionState(
        startedAt: startedAt ?? this.startedAt,
        currentExercise: currentExercise ?? this.currentExercise,
        allSets: allSets ?? this.allSets,
        isResting: isResting ?? this.isResting,
        restSecondsLeft: restSecondsLeft ?? this.restSecondsLeft,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        summary: summary ?? this.summary,
        isOutdoorMode: isOutdoorMode ?? this.isOutdoorMode,
        routePoints: routePoints ?? this.routePoints,
        distanceKm: distanceKm ?? this.distanceKm,
        paceMinPerKm: paceMinPerKm == _sentinel
            ? this.paceMinPerKm
            : paceMinPerKm as double?,
      );
}

// Sentinel value for nullable copyWith field.
const Object _sentinel = Object();
