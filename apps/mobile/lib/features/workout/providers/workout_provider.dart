import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import 'package:dio/dio.dart';

import 'package:latlong2/latlong.dart';

import '../../../core/api/api_client.dart';
import '../../../core/services/gps_service.dart';
import '../../../core/services/health_service.dart';
import '../../../core/services/sync_queue_service.dart' show syncServiceProvider;
import '../../home/providers/home_provider.dart';
import '../../progress/providers/body_log_provider.dart';
import '../../progress/providers/progress_provider.dart';
import '../models/exercise.dart';
import '../models/workout_session_state.dart';
import 'workout_history_provider.dart';

final _log = Logger();

// 90 seconds default rest between sets
const _kRestDurationSec = 90;

final workoutSessionProvider =
    NotifierProvider<WorkoutSessionNotifier, WorkoutSessionState>(
        WorkoutSessionNotifier.new);

class WorkoutSessionNotifier extends Notifier<WorkoutSessionState> {
  Timer? _restTimer;
  StreamSubscription<GpsUpdate>? _gpsSub;

  @override
  WorkoutSessionState build() {
    ref.onDispose(() {
      _restTimer?.cancel();
      _gpsSub?.cancel();
    });
    return const WorkoutSessionState();
  }

  /// Call this before navigating to ActiveWorkoutScreen.
  void startWorkout(Exercise exercise) {
    _restTimer?.cancel();
    _gpsSub?.cancel();
    state = WorkoutSessionState(
      startedAt: DateTime.now(),
      currentExercise: exercise,
    );
  }

  /// Switch to a different exercise mid-workout.
  void setExercise(Exercise exercise) {
    state = state.copyWith(currentExercise: exercise);
  }

  /// Toggle GPS outdoor tracking on/off.
  /// Only has effect for cardio exercises; safe to call for any exercise.
  Future<void> toggleOutdoorMode() async {
    final gps = ref.read(gpsServiceProvider);

    if (state.isOutdoorMode) {
      // Turning off — stop GPS, keep accumulated data in state.
      gps.stopTracking();
      _gpsSub?.cancel();
      _gpsSub = null;
      state = state.copyWith(isOutdoorMode: false);
    } else {
      // Turning on — request permission and start streaming.
      final started = await gps.startTracking();
      if (!started) {
        _log.w('GPS permission denied or unavailable');
        return;
      }
      _gpsSub = gps.updates.listen(_onGpsUpdate);
      state = state.copyWith(isOutdoorMode: true);
    }
  }

  void _onGpsUpdate(GpsUpdate update) {
    state = state.copyWith(
      routePoints: List<LatLng>.from(update.route),
      distanceKm: update.distanceKm,
      paceMinPerKm: update.paceMinPerKm,
    );
  }

  /// Log a completed set and auto-start the rest timer.
  void logSet({int? reps, double? weightKg, int? durationSec}) {
    final exercise = state.currentExercise;
    if (exercise == null) return;

    final newSet = LoggedSet(
      exerciseId: exercise.id,
      exerciseName: exercise.name,
      setNumber: state.nextSetNumber,
      reps: reps,
      weightKg: weightKg,
      durationSec: durationSec,
    );

    state = state.copyWith(
      allSets: [...state.allSets, newSet],
      isResting: true,
      restSecondsLeft: _kRestDurationSec,
    );
    _startRestTimer();
  }

  void skipRest() {
    _restTimer?.cancel();
    state = state.copyWith(isResting: false, restSecondsLeft: 0);
  }

  /// POST the session to the backend, populate summary, return it.
  Future<WorkoutSummary?> finishWorkout() async {
    if (state.allSets.isEmpty) return null;

    final start = state.startedAt;
    if (start == null) return null;

    skipRest();

    // Stop GPS tracking and capture final route.
    final gps = ref.read(gpsServiceProvider);
    gps.stopTracking();
    _gpsSub?.cancel();
    _gpsSub = null;

    final now = DateTime.now();
    final durationMin = now.difference(start).inMinutes.clamp(1, 480);
    final exerciseNames =
        state.allSets.map((s) => s.exerciseName).toSet().toList();

    final hasCardio = state.allSets.any((s) {
      final ex =
          kExerciseLibrary.where((e) => e.id == s.exerciseId).firstOrNull;
      return ex?.muscleGroup == MuscleGroup.cardio;
    });

    final weightKg =
        ref.read(bodyLogProvider).valueOrNull?.firstOrNull?.weightKg ?? 70.0;

    // ── Calorie calculation ─────────────────────────────────────────────────
    // Outdoor + GPS with meaningful distance → use distance × MET × weight.
    // Otherwise fall back to time-based estimate (MET × weight × hours).
    final int caloriesBurned;
    final outdoorDistanceKm = state.isOutdoorMode || state.distanceKm > 0
        ? state.distanceKm
        : 0.0;

    if (outdoorDistanceKm > 0.05 && hasCardio) {
      // Find the primary cardio exercise for the MET coefficient.
      final primaryCardioId = state.allSets
          .map((s) => s.exerciseId)
          .firstWhere(
            (id) => kOutdoorKcalPerKgPerKm.containsKey(id),
            orElse: () => '',
          );
      caloriesBurned = outdoorCaloriesForExercise(
        exerciseId: primaryCardioId,
        weightKg: weightKg,
        distanceKm: outdoorDistanceKm,
      ).round().clamp(1, 9999);
    } else {
      final met = hasCardio ? 8.0 : 5.0;
      caloriesBurned =
          (met * weightKg * (durationMin / 60.0)).round().clamp(1, 9999);
    }

    // ── Route polyline ──────────────────────────────────────────────────────
    final routePoints = state.routePoints;
    final String? routePolyline =
        routePoints.length >= 2 ? GpsService.encodePolyline(routePoints) : null;

    final workoutName = exerciseNames.length == 1
        ? exerciseNames.first
        : '${exerciseNames.first} +${exerciseNames.length - 1} more';

    final summary = WorkoutSummary(
      workoutName: workoutName,
      totalSets: state.allSets.length,
      durationMin: durationMin,
      caloriesBurned: caloriesBurned,
      exerciseNames: exerciseNames,
      distanceKm: outdoorDistanceKm > 0.05 ? outdoorDistanceKm : null,
      routePolyline: routePolyline,
      routePoints: routePoints,
    );

    state = state.copyWith(isSubmitting: true);

    final workoutPayload = <String, dynamic>{
      'name': workoutName,
      'startedAt': start.toIso8601String(),
      'finishedAt': now.toIso8601String(),
      'durationMin': durationMin,
      'caloriesBurned': caloriesBurned,
      if (outdoorDistanceKm > 0.05)
        'distanceM': (outdoorDistanceKm * 1000).round(),
      if (routePolyline != null) 'routePolyline': routePolyline,
      'sets': state.allSets
          .map((s) => <String, dynamic>{
                'exerciseId': s.exerciseId,
                'exerciseName': s.exerciseName,
                'setNumber': s.setNumber,
                if (s.reps != null) 'reps': s.reps,
                if (s.weightKg != null) 'weightKg': s.weightKg,
                if (s.durationSec != null) 'durationSec': s.durationSec,
              })
          .toList(),
    };

    try {
      await ref
          .read(apiClientProvider)
          .dio
          .post('/workout/logs', data: workoutPayload);
      ref.read(homeProvider.notifier).addBurnedCalories(caloriesBurned);
      // Refresh history + progress tabs so they reflect the new workout.
      ref.invalidate(workoutHistoryProvider);
      ref.invalidate(progressProvider);
    } on DioException catch (e) {
      if (e.response == null) {
        await ref
            .read(syncServiceProvider)
            .enqueue('/workout/logs', workoutPayload);
        // Still credit the calories locally — the log will sync when online.
        ref.read(homeProvider.notifier).addBurnedCalories(caloriesBurned);
        _log.w('Workout log queued for sync (offline)');
      } else {
        _log.e('Failed to POST workout log (server error)', error: e);
      }
    } catch (e, st) {
      _log.e('Failed to POST workout log', error: e, stackTrace: st);
    }

    unawaited(
      ref.read(healthServiceProvider).writeWorkout(
        isCardio: hasCardio,
        startTime: start,
        endTime: now,
        caloriesBurned: caloriesBurned,
      ),
    );

    state = state.copyWith(isSubmitting: false, summary: summary);
    return summary;
  }

  void resetSession() {
    _restTimer?.cancel();
    _gpsSub?.cancel();
    _gpsSub = null;
    ref.read(gpsServiceProvider).stopTracking();
    state = const WorkoutSessionState();
  }

  void _startRestTimer() {
    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final secs = state.restSecondsLeft;
      if (secs <= 1) {
        _restTimer?.cancel();
        state = state.copyWith(isResting: false, restSecondsLeft: 0);
      } else {
        state = state.copyWith(restSecondsLeft: secs - 1);
      }
    });
  }
}
