import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/health_service.dart';
import '../../auth/providers/auth_provider.dart';

/// Rest & heart snapshot read from Health Connect / Apple Health.
class VitalsSummary {
  const VitalsSummary({
    required this.hasAccess,
    this.night,
    this.sleepHistoryMin = const [],
    this.avgHeartRate,
    this.restingHeartRate,
    this.hrvMs,
  });

  /// False until the user has granted heart-rate / sleep read access.
  final bool hasAccess;
  final SleepNight? night;

  /// Minutes asleep per night, oldest first (7 entries).
  final List<int> sleepHistoryMin;
  final int? avgHeartRate;
  final int? restingHeartRate;
  final double? hrvMs;

  static const none = VitalsSummary(hasAccess: false);

  bool get hasAnyData =>
      night != null ||
      avgHeartRate != null ||
      restingHeartRate != null ||
      hrvMs != null;

  /// 0–100 "rest score": sleep vs an 8 h target (60 %) blended with resting
  /// heart rate / HRV (40 %) when available. Null without sleep data.
  int? get restScore {
    final n = night;
    if (n == null) return null;
    final sleep = (n.totalMinutes / 480 * 100).clamp(0, 100).toDouble();

    double? body;
    if (hrvMs != null) {
      body = ((hrvMs! - 20) / 80 * 100).clamp(0, 100).toDouble();
    } else if (restingHeartRate != null) {
      body = ((80 - restingHeartRate!) / 30 * 100).clamp(0, 100).toDouble();
    }
    final score = body == null ? sleep : sleep * 0.6 + body * 0.4;
    return score.round();
  }

  String? get restLabel {
    final s = restScore;
    if (s == null) return null;
    if (s >= 75) return 'Well rested';
    if (s >= 50) return 'Moderately rested';
    return 'Take it easy today';
  }
}

final vitalsProvider =
    AsyncNotifierProvider<VitalsNotifier, VitalsSummary>(VitalsNotifier.new);

class VitalsNotifier extends AsyncNotifier<VitalsSummary> {
  @override
  Future<VitalsSummary> build() async {
    if (ref.watch(authProvider).valueOrNull == null) return VitalsSummary.none;
    return _load();
  }

  Future<VitalsSummary> _load() async {
    final health = ref.read(healthServiceProvider);
    if (!await health.isHealthStoreAvailable()) return VitalsSummary.none;
    if (!await health.hasVitalsAccess()) return VitalsSummary.none;

    final results = await Future.wait<Object?>([
      health.getLastNight(),
      health.getSleepHistory(7),
      health.getTodayAverageHeartRate(),
      health.getRestingHeartRate(),
      health.getRecentHrv(),
    ]);
    return VitalsSummary(
      hasAccess: true,
      night: results[0] as SleepNight?,
      sleepHistoryMin: results[1]! as List<int>,
      avgHeartRate: results[2] as int?,
      restingHeartRate: results[3] as int?,
      hrvMs: results[4] as double?,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading<VitalsSummary>().copyWithPrevious(state);
    state = await AsyncValue.guard(_load);
  }

  /// Prompts for access, then reloads. Returns whether access was granted.
  Future<bool> connect() async {
    final health = ref.read(healthServiceProvider);
    final granted = await health.requestVitalsPermissions();
    await refresh();
    return granted;
  }
}
