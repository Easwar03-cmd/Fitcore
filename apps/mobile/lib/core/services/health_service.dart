import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import 'package:logger/logger.dart';

final healthServiceProvider = Provider<HealthService>((_) => HealthService());

final _log = Logger();

// ── Permission type lists ──────────────────────────────────────────────────────

/// Core types requested on every platform.
const _kBaseTypes = [
  HealthDataType.STEPS,
  HealthDataType.HEART_RATE,
  HealthDataType.SLEEP_ASLEEP,
  HealthDataType.SLEEP_AWAKE,
  HealthDataType.WEIGHT,
  HealthDataType.WORKOUT,
];

/// Parallel access list for the base types.
/// WORKOUT needs READ_WRITE so FitCore can push sessions back to the health app.
const _kBasePermissions = [
  HealthDataAccess.READ,       // STEPS
  HealthDataAccess.READ,       // HEART_RATE
  HealthDataAccess.READ,       // SLEEP_ASLEEP
  HealthDataAccess.READ,       // SLEEP_AWAKE
  HealthDataAccess.READ,       // WEIGHT
  HealthDataAccess.READ_WRITE, // WORKOUT
];

/// Sleep stage detail — only available on Android and wearable-backed HealthKit.
/// Requested best-effort; failures are silently swallowed.
const _kSleepStageTypes = [
  HealthDataType.SLEEP_DEEP,
  HealthDataType.SLEEP_LIGHT,
  HealthDataType.SLEEP_REM,
];

// ── Sleep window helpers ───────────────────────────────────────────────────────

/// Previous evening 8 pm — start of the sleep capture window.
DateTime _sleepWindowStart() {
  final now = DateTime.now();
  final yesterday = now.subtract(const Duration(days: 1));
  return DateTime(yesterday.year, yesterday.month, yesterday.day, 20);
}

/// Today 10 am (or now if it is not yet 10 am) — end of the sleep capture window.
DateTime _sleepWindowEnd() {
  final now = DateTime.now();
  final tenAm = DateTime(now.year, now.month, now.day, 10);
  return tenAm.isBefore(now) ? tenAm : now;
}

// ── Value objects ──────────────────────────────────────────────────────────────

/// Deep / light / REM breakdown for last night's sleep.
/// [getSleepStages] returns null when the device has no stage data.
class SleepStages {
  const SleepStages({
    required this.deepMinutes,
    required this.lightMinutes,
    required this.remMinutes,
  });

  final int deepMinutes;
  final int lightMinutes;
  final int remMinutes;
}

// ── Service ────────────────────────────────────────────────────────────────────

class HealthService {
  static final Health _health = Health();

  /// True once [requestPermissions] has returned successfully.
  bool _authorised = false;

  // ── Permissions ─────────────────────────────────────────────────────────────

  /// Request all permissions FitCore requires.
  ///
  /// Returns true if the base types (steps, heart rate, sleep, weight, workout)
  /// were granted. Sleep stage types (deep/light/REM) are requested
  /// best-effort and do not affect the return value.
  Future<bool> requestPermissions() async {
    try {
      await _health.configure();

      _authorised = await _health.requestAuthorization(
        _kBaseTypes,
        permissions: _kBasePermissions,
      );

      // Best-effort: sleep stage detail.  Fails silently on unsupported devices.
      try {
        await _health.requestAuthorization(_kSleepStageTypes);
      } catch (_) {}

      return _authorised;
    } catch (e) {
      _log.w('Health permission request failed', error: e);
      return false;
    }
  }

  // ── Read: steps ─────────────────────────────────────────────────────────────

  /// Today's step count from midnight local time to now.
  /// Returns 0 if permissions are denied or the platform throws.
  Future<int> getTodaySteps() async {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    try {
      if (!_authorised) {
        final granted = await requestPermissions();
        if (!granted) return 0;
      }
      final steps = await _health.getTotalStepsInInterval(midnight, now);
      return steps ?? 0;
    } catch (e) {
      _log.w('Could not fetch step count — returning 0', error: e);
      return 0;
    }
  }

  // ── Read: heart rate ─────────────────────────────────────────────────────────

  /// Average heart rate (bpm) from today's readings.
  /// Returns null if no readings exist or permissions are denied.
  Future<int?> getTodayHeartRate() async {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    try {
      if (!_authorised) {
        final granted = await requestPermissions();
        if (!granted) return null;
      }
      final points = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: midnight,
        endTime: now,
      );
      if (points.isEmpty) return null;

      final values = points
          .map((p) => (p.value as NumericHealthValue).numericValue.toDouble())
          .toList();
      final avg = values.reduce((a, b) => a + b) / values.length;
      return avg.round();
    } catch (e) {
      _log.w('Could not fetch heart rate', error: e);
      return null;
    }
  }

  // ── Read: sleep ──────────────────────────────────────────────────────────────

  /// Total sleep duration in minutes from last night's window
  /// (8 pm the previous evening → 10 am today).
  /// Returns 0 when no data exists or permissions are denied.
  Future<int> getLastNightSleep() async {
    try {
      if (!_authorised) {
        final granted = await requestPermissions();
        if (!granted) return 0;
      }
      final points = await _health.getHealthDataFromTypes(
        types: [HealthDataType.SLEEP_ASLEEP],
        startTime: _sleepWindowStart(),
        endTime: _sleepWindowEnd(),
      );
      if (points.isEmpty) return 0;

      int totalMinutes = 0;
      for (final p in points) {
        totalMinutes += p.dateTo.difference(p.dateFrom).inMinutes;
      }
      return totalMinutes;
    } catch (e) {
      _log.w('Could not fetch sleep data', error: e);
      return 0;
    }
  }

  /// Deep, light, and REM breakdown from last night's sleep window.
  ///
  /// Returns null when the device provides no stage-level data (iOS without
  /// a wearable app writing to HealthKit, or Android without a compatible
  /// sleep source). In that case callers should fall back to showing only
  /// the total from [getLastNightSleep].
  Future<SleepStages?> getSleepStages() async {
    try {
      if (!_authorised) {
        final granted = await requestPermissions();
        if (!granted) return null;
      }
      final start = _sleepWindowStart();
      final end = _sleepWindowEnd();

      Future<int> sumStageMinutes(HealthDataType type) async {
        try {
          final pts = await _health.getHealthDataFromTypes(
            types: [type],
            startTime: start,
            endTime: end,
          );
          return pts.fold<int>(
            0,
            (acc, p) => acc + p.dateTo.difference(p.dateFrom).inMinutes,
          );
        } catch (_) {
          return 0; // type not available on this device
        }
      }

      final deep = await sumStageMinutes(HealthDataType.SLEEP_DEEP);
      final light = await sumStageMinutes(HealthDataType.SLEEP_LIGHT);
      final rem = await sumStageMinutes(HealthDataType.SLEEP_REM);

      // All zeroes → device has no stage data.
      if (deep == 0 && light == 0 && rem == 0) return null;

      return SleepStages(
        deepMinutes: deep,
        lightMinutes: light,
        remMinutes: rem,
      );
    } catch (e) {
      _log.w('Could not fetch sleep stages', error: e);
      return null;
    }
  }

  // ── Read: sleep history ──────────────────────────────────────────────────────

  /// Returns total sleep minutes for each of the past [days] nights.
  /// Index 0 = oldest, index [days-1] = last night.
  /// Uses a single health query for efficiency.
  Future<List<int>> getSleepHistoryDays(int days) async {
    try {
      if (!_authorised) {
        final granted = await requestPermissions();
        if (!granted) return List.filled(days, 0);
      }
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      // Cover every night in the window (20:00 of [days] evenings ago → now).
      final windowStart = today.subtract(Duration(days: days));
      final pts = await _health.getHealthDataFromTypes(
        types: [HealthDataType.SLEEP_ASLEEP],
        startTime: windowStart,
        endTime: now,
      );
      final byDay = <int, int>{for (var i = 0; i < days; i++) i: 0};
      for (final p in pts) {
        final wakeDay = DateTime(p.dateTo.year, p.dateTo.month, p.dateTo.day);
        final daysAgo = today.difference(wakeDay).inDays;
        if (daysAgo >= 0 && daysAgo < days) {
          final idx = days - 1 - daysAgo;
          byDay[idx] = byDay[idx]! + p.dateTo.difference(p.dateFrom).inMinutes;
        }
      }
      return List.generate(days, (i) => byDay[i]!);
    } catch (e) {
      _log.w('Could not fetch sleep history', error: e);
      return List.filled(days, 0);
    }
  }

  // ── Read: heart rate history ──────────────────────────────────────────────────

  /// Returns average HR bpm for each of the past [days] days.
  /// Index 0 = oldest, index [days-1] = today. Null = no readings for that day.
  Future<List<int?>> getHeartRateHistoryDays(int days) async {
    try {
      if (!_authorised) {
        final granted = await requestPermissions();
        if (!granted) return List.filled(days, null);
      }
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final start = today.subtract(Duration(days: days - 1));
      final pts = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: start,
        endTime: now,
      );
      final readings = <int, List<double>>{};
      for (final p in pts) {
        final day = DateTime(p.dateFrom.year, p.dateFrom.month, p.dateFrom.day);
        final daysAgo = today.difference(day).inDays;
        if (daysAgo >= 0 && daysAgo < days) {
          final idx = days - 1 - daysAgo;
          readings.putIfAbsent(idx, () => [])
              .add((p.value as NumericHealthValue).numericValue.toDouble());
        }
      }
      return List.generate(days, (i) {
        final r = readings[i];
        if (r == null || r.isEmpty) return null;
        return (r.reduce((a, b) => a + b) / r.length).round();
      });
    } catch (e) {
      _log.w('Could not fetch HR history', error: e);
      return List.filled(days, null);
    }
  }

  // ── Write: workout ───────────────────────────────────────────────────────────

  /// Push a completed FitCore workout to Apple Health / Google Fit so it
  /// appears in the native health app alongside other activity sources.
  ///
  /// Writes active energy burned (KILOCALORIE) for the workout duration.
  /// Returns true if the write succeeded.
  ///
  /// This is best-effort — callers should not surface a failure to the user;
  /// just log it.
  Future<bool> writeWorkout({
    required bool isCardio,
    required DateTime startTime,
    required DateTime endTime,
    required int caloriesBurned,
  }) async {
    try {
      if (!_authorised) {
        final granted = await requestPermissions();
        if (!granted) return false;
      }
      // Write the calorie burn as active energy; the WORKOUT data type requires
      // platform-specific session objects not available in the health plugin's
      // cross-platform API, so ACTIVE_ENERGY_BURNED is the portable equivalent.
      return await _health.writeHealthData(
        value: caloriesBurned.toDouble(),
        type: HealthDataType.ACTIVE_ENERGY_BURNED,
        startTime: startTime,
        endTime: endTime,
      );
    } catch (e) {
      _log.w('Could not write workout to health platform', error: e);
      return false;
    }
  }
}
