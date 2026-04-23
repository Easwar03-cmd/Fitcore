import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../../core/api/api_client.dart';
import '../../../core/services/health_service.dart';
import '../../../core/services/sync_queue_service.dart' show syncServiceProvider;
import '../../auth/providers/auth_provider.dart';
import '../models/wellness_state.dart';

final _log = Logger();

class WellnessNotifier extends AsyncNotifier<WellnessState> {
  @override
  Future<WellnessState> build() {
    if (ref.watch(authProvider).valueOrNull == null) {
      return Future.value(WellnessState.empty);
    }
    return _loadState();
  }

  // ── Public actions ──────────────────────────────────────────────────────────

  Future<void> logMood(int score) async {
    final current = state.valueOrNull;
    if (current == null) return;

    // Optimistically update UI immediately so the emoji tap feels instant.
    state = AsyncData(current.copyWithMood(
      todayMood: score,
      moodHistory: current.moodHistory,
    ));

    final payload = <String, dynamic>{'score': score};
    try {
      final res = await ref
          .read(apiClientProvider)
          .dio
          .post('/wellness/mood', data: payload);
      final entry = MoodLogEntry.fromJson(
          res.data['data'] as Map<String, dynamic>);
      // Replace optimistic state with server-confirmed entry (has id + timestamp).
      state = AsyncData(current.copyWithMood(
        todayMood: score,
        moodHistory: [...current.moodHistory, entry],
      ));
    } on DioException catch (e, st) {
      if (e.response == null) {
        // Offline: queue for sync, keep optimistic state.
        await ref
            .read(syncServiceProvider)
            .enqueue('/wellness/mood', payload);
        _log.w('Mood log queued for sync (offline)', error: e);
        return;
      }
      // Server error: keep optimistic state visible, just log the error.
      _log.e('Failed to log mood', error: e, stackTrace: st);
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_loadState);
  }

  // ── Load ────────────────────────────────────────────────────────────────────

  Future<WellnessState> _loadState() async {
    final health = ref.read(healthServiceProvider);
    final api = ref.read(apiClientProvider);

    // Kick off all fetches concurrently before the first await.
    final f1 = health.getLastNightSleep();
    final f2 = health.getSleepStages();
    final f3 = health.getTodayHeartRate();
    final f4 = health.getSleepHistoryDays(7);
    final f5 = health.getHeartRateHistoryDays(7);
    final f6 = _fetchMoodData(api);
    final f7 = _fetchYesterdayCalsBurned(api);
    final f8 = health.getTodayHRV();

    final sleepMin = await f1;
    final stages = await f2;
    final restingHr = await f3;
    final sleepTrend = await f4;
    final hrTrend = await f5;
    final (todayMood, moodHistory) = await f6;
    final yesterdayCalsBurned = await f7;
    final hrv = await f8;

    final sleepScore = _computeSleepScore(sleepMin, stages);
    final readiness = _computeReadiness(
      sleepScore: sleepScore,
      restingHr: restingHr,
      hrv: hrv,
      yesterdayCalsBurned: yesterdayCalsBurned,
    ); // hrv: null on devices without a wearable → falls back to RHR

    return WellnessState(
      sleepMinutes: sleepMin,
      sleepStages: stages,
      sleepScore: sleepScore,
      sleepTrend: sleepTrend,
      restingHr: restingHr,
      hrTrend: hrTrend,
      hrv: hrv,
      todayMood: todayMood,
      moodHistory: moodHistory,
      readinessScore: readiness,
      readinessLabel: _readinessLabel(readiness),
      readinessLevel: _readinessLevel(readiness),
    );
  }

  // ── API helpers ─────────────────────────────────────────────────────────────

  Future<(int?, List<MoodLogEntry>)> _fetchMoodData(ApiClient api) async {
    try {
      final res = await api.dio
          .get('/wellness/mood', queryParameters: {'days': 14});
      final data = res.data['data'] as Map<String, dynamic>;
      final todayJson = data['todayMood'];
      final todayMood =
          todayJson != null ? (todayJson['score'] as int) : null;
      final history = (data['history'] as List<dynamic>)
          .map((e) => MoodLogEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      return (todayMood, history);
    } on DioException catch (e, st) {
      _log.w('Failed to fetch mood data', error: e, stackTrace: st);
      return (null, <MoodLogEntry>[]);
    }
  }

  Future<int> _fetchYesterdayCalsBurned(ApiClient api) async {
    try {
      final res = await api.dio.get('/wellness/training-load');
      return (res.data['data']['calsBurned'] as num).toInt();
    } on DioException catch (e, st) {
      _log.w('Failed to fetch training load', error: e, stackTrace: st);
      return 0;
    }
  }

  // ── Score calculations ──────────────────────────────────────────────────────

  /// score = (durationHours/8 × 50) + (deepPct × 30) + (remPct × 20)
  static int _computeSleepScore(int sleepMin, SleepStages? stages) {
    if (sleepMin == 0) return 0;
    final durationScore =
        (sleepMin / 60.0 / 8.0).clamp(0.0, 1.0) * 50.0;
    if (stages == null) return durationScore.round();
    final total =
        stages.deepMinutes + stages.lightMinutes + stages.remMinutes;
    if (total == 0) return durationScore.round();
    final deepPct = stages.deepMinutes / total;
    final remPct = stages.remMinutes / total;
    return (durationScore + deepPct * 30.0 + remPct * 20.0)
        .round()
        .clamp(0, 100);
  }

  /// readiness = sleepScore×0.4 + hrComponent×0.3 + trainingLoadScore×0.3
  /// hrComponent: HRV (10–100 ms → 0–100) if available, else RHR fallback.
  static int _computeReadiness({
    required int sleepScore,
    required int? restingHr,
    double? hrv,
    required int yesterdayCalsBurned,
  }) {
    final double hrComponent;
    if (hrv != null) {
      // HRV 10–100 ms → 0–100 score (higher HRV = better recovery).
      hrComponent = ((hrv - 10.0) / 90.0).clamp(0.0, 1.0) * 100.0;
    } else {
      // Map RHR 40-100 bpm → 100-0 score (lower RHR = better recovery).
      hrComponent = restingHr != null
          ? ((100 - restingHr.clamp(40, 100)) / 60.0 * 100.0)
              .clamp(0.0, 100.0)
          : 50.0;
    }
    // High training load yesterday → lower readiness today.
    final trainingScore =
        100.0 - (yesterdayCalsBurned / 5.0).clamp(0.0, 90.0);
    return (sleepScore * 0.4 + hrComponent * 0.3 + trainingScore * 0.3)
        .round()
        .clamp(0, 100);
  }

  static String _readinessLabel(int score) {
    if (score < 40) return 'Rest today';
    if (score < 66) return 'Light training';
    return 'Train hard';
  }

  static ReadinessLevel _readinessLevel(int score) {
    if (score < 40) return ReadinessLevel.rest;
    if (score < 66) return ReadinessLevel.light;
    return ReadinessLevel.hard;
  }
}

final wellnessProvider =
    AsyncNotifierProvider<WellnessNotifier, WellnessState>(
        WellnessNotifier.new);
