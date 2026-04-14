import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../../core/api/api_client.dart';
import '../../workout/models/workout_log.dart';
import '../models/body_stat.dart';
import '../models/progress_data.dart';

final _log = Logger();

final progressProvider =
    AsyncNotifierProvider<ProgressNotifier, ProgressData>(ProgressNotifier.new);

class ProgressNotifier extends AsyncNotifier<ProgressData> {
  @override
  Future<ProgressData> build() => _fetch();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<ProgressData> _fetch() async {
    final dio = ref.read(apiClientProvider).dio;
    final now = DateTime.now();

    // 14 days: first 7 for trend display, all 14 for this/last-week comparison.
    final calDates = List.generate(14, (i) => now.subtract(Duration(days: i)));
    final calDateStrs = calDates.map(_dateStr).toList();

    final List<Future<Response<dynamic>?>> futures = [
      _get(dio, '/body/stats'),
      _get(dio, '/workout/logs'),
      _get(dio, '/user/profile'),
      for (var i = 0; i < 14; i++)
        _get(dio, '/nutrition/food-logs', query: {'date': calDateStrs[i]}),
    ];

    final results = await Future.wait(futures);

    // ── Body stats ────────────────────────────────────────────────────────────
    final bodyRes = results[0];
    final allStats = bodyRes != null
        ? (bodyRes.data['data'] as List<dynamic>)
            .map((e) => BodyStat.fromJson(e as Map<String, dynamic>))
            .toList()
        : <BodyStat>[];
    final sortedStats = [...allStats]
      ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));

    // ── Workout logs ──────────────────────────────────────────────────────────
    final workoutRes = results[1];
    final workoutLogs = workoutRes != null
        ? (workoutRes.data['data'] as List<dynamic>)
            .map((e) => WorkoutLog.fromJson(e as Map<String, dynamic>))
            .toList()
        : <WorkoutLog>[];

    // ── TDEE ──────────────────────────────────────────────────────────────────
    final profileRes = results[2];
    final tdee = profileRes != null
        ? (profileRes.data['data']['tdee'] as num?)?.toInt() ?? 2000
        : 2000;

    // ── Calorie data (indices 3–16) ────────────────────────────────────────────
    final List<DayCalories> allDays = [];
    for (var i = 0; i < 14; i++) {
      final res = results[3 + i];
      double cals = 0;
      if (res != null) {
        try {
          final data = res.data['data'] as Map<String, dynamic>;
          final totals = data['totals'] as Map<String, dynamic>;
          cals = (totals['calories'] as num?)?.toDouble() ?? 0;
        } catch (_) {}
      }
      allDays.add(DayCalories(date: calDates[i], calories: cals, target: tdee));
    }

    // Trend = last 7 days, oldest first.
    final calorieTrend = allDays.take(7).toList().reversed.toList();

    // ── Weekly summaries ───────────────────────────────────────────────────────
    final thisWeekStart = _weekStart(now);
    final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));

    final thisWeekLogs = workoutLogs
        .where((w) => !w.startedAt.isBefore(thisWeekStart))
        .toList();
    final lastWeekLogs = workoutLogs
        .where((w) =>
            !w.startedAt.isBefore(lastWeekStart) &&
            w.startedAt.isBefore(thisWeekStart))
        .toList();

    double avgCals(Iterable<DayCalories> days) {
      final vals = days.map((d) => d.calories).toList();
      if (vals.isEmpty) return 0;
      return vals.reduce((a, b) => a + b) / vals.length;
    }

    final thisWeek = WeeklySummary(
      workoutsCompleted: thisWeekLogs.length,
      avgDailyCalories:
          avgCals(allDays.where((d) => !d.date.isBefore(thisWeekStart))),
      totalVolumeKg: _totalVolume(thisWeekLogs),
    );
    final lastWeek = WeeklySummary(
      workoutsCompleted: lastWeekLogs.length,
      avgDailyCalories: avgCals(allDays.where((d) =>
          !d.date.isBefore(lastWeekStart) && d.date.isBefore(thisWeekStart))),
      totalVolumeKg: _totalVolume(lastWeekLogs),
    );

    return ProgressData(
      bodyStats: sortedStats,
      calorieTrend: calorieTrend,
      strengthCurves: _computeStrengthCurves(workoutLogs, now),
      muscleVolume: _computeMuscleVolume(thisWeekLogs),
      thisWeek: thisWeek,
      lastWeek: lastWeek,
      calorieTarget: tdee,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static Future<Response<dynamic>?> _get(
    Dio dio,
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      return await dio.get(path, queryParameters: query);
    } catch (e) {
      _log.w('Progress fetch degraded: $path', error: e);
      return null;
    }
  }

  static String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime _weekStart(DateTime d) =>
      DateTime(d.year, d.month, d.day - (d.weekday - 1));

  static double _totalVolume(List<WorkoutLog> logs) {
    var vol = 0.0;
    for (final w in logs) {
      for (final s in w.sets) {
        if (s.reps != null && s.weightKg != null) {
          vol += s.reps! * s.weightKg!;
        }
      }
    }
    return vol;
  }

  static Map<String, List<ExerciseWeekPoint>> _computeStrengthCurves(
    List<WorkoutLog> logs,
    DateTime now,
  ) {
    // Rank exercises by total weighted sets.
    final setCount = <String, int>{};
    for (final w in logs) {
      for (final s in w.sets) {
        if (s.weightKg != null) {
          setCount[s.exerciseName] = (setCount[s.exerciseName] ?? 0) + 1;
        }
      }
    }
    if (setCount.isEmpty) return {};

    final top3 = (setCount.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(3)
        .map((e) => e.key)
        .toList();

    final thisWeekStart = _weekStart(now);
    // Oldest week first.
    final weekStarts = List.generate(
      8,
      (i) => thisWeekStart.subtract(Duration(days: 7 * (7 - i))),
    );

    final Map<String, List<ExerciseWeekPoint>> curves = {};
    for (final ex in top3) {
      final points = <ExerciseWeekPoint>[];
      for (final ws in weekStarts) {
        final weekEnd = ws.add(const Duration(days: 7));
        double maxW = 0;
        for (final w in logs) {
          if (w.startedAt.isBefore(ws) || !w.startedAt.isBefore(weekEnd)) {
            continue;
          }
          for (final s in w.sets) {
            if (s.exerciseName == ex && s.weightKg != null && s.weightKg! > maxW) {
              maxW = s.weightKg!;
            }
          }
        }
        if (maxW > 0) {
          points.add(ExerciseWeekPoint(weekStart: ws, maxWeightKg: maxW));
        }
      }
      if (points.isNotEmpty) curves[ex] = points;
    }
    return curves;
  }

  static Map<String, int> _computeMuscleVolume(List<WorkoutLog> logs) {
    final volume = <String, int>{};
    for (final w in logs) {
      for (final s in w.sets) {
        final group = _muscleGroup(s.exerciseName);
        if (group != 'other') {
          volume[group] = (volume[group] ?? 0) + 1;
        }
      }
    }
    return volume;
  }

  static String _muscleGroup(String exerciseName) {
    final n = exerciseName.toLowerCase();
    if (n.contains('bench') || n.contains('chest') || n.contains('fly') ||
        n.contains('flye') || n.contains('pec') ||
        n.contains('incline press') || n.contains('decline press') ||
        n.contains('push up') || n.contains('pushup')) {
      return 'chest';
    }
    if (n.contains('squat') || n.contains('leg press') ||
        n.contains('lunge') || n.contains('quad') ||
        n.contains('leg extension')) {
      return 'quads';
    }
    if (n.contains('hamstring') || n.contains('rdl') ||
        n.contains('romanian') || n.contains('leg curl') ||
        n.contains('good morning')) {
      return 'hamstrings';
    }
    if (n.contains('calf') || n.contains('calve')) { return 'calves'; }
    if (n.contains('deadlift') || n.contains('row') || n.contains('pull up') ||
        n.contains('pullup') || n.contains('lat pull') ||
        n.contains('chin up') || n.contains('chinup')) {
      return 'back';
    }
    if (n.contains('shoulder') || n.contains('delt') ||
        n.contains('lateral raise') || n.contains('front raise') ||
        n.contains('overhead') || n.contains('ohp') ||
        n.contains('arnold')) {
      return 'shoulders';
    }
    if (n.contains('curl') || n.contains('bicep') ||
        n.contains('hammer curl')) {
      return 'arms';
    }
    if (n.contains('tricep') || n.contains('pushdown') ||
        n.contains('skull') || n.contains('dip') ||
        n.contains('extension')) {
      return 'arms';
    }
    if (n.contains('press')) { return 'shoulders'; }
    if (RegExp(r'\babs?\b').hasMatch(n) || n.contains('crunch') ||
        n.contains('plank') || n.contains('sit up') || n.contains('situp') ||
        n.contains('core') || n.contains('russian twist')) {
      return 'core';
    }
    if (n.contains('hip thrust') || n.contains('glute') ||
        n.contains('bridge')) {
      return 'glutes';
    }
    return 'other';
  }
}
