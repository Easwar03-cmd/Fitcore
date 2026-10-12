import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import 'package:logger/logger.dart';

final healthServiceProvider = Provider<HealthService>((_) => HealthService());

final _log = Logger();

// ── Permission type lists ──────────────────────────────────────────────────────

/// Core types requested on every platform.
/// Must stay in sync with the health permissions in AndroidManifest.xml —
/// Health Connect review only allows permissions the app actually uses.
const _kBaseTypes = [
  HealthDataType.STEPS,
  HealthDataType.ACTIVE_ENERGY_BURNED,
];

/// Parallel access list for the base types.
/// ACTIVE_ENERGY_BURNED is write-only: [writeWorkout] pushes the burn back.
const _kBasePermissions = [
  HealthDataAccess.READ,  // STEPS
  HealthDataAccess.WRITE, // ACTIVE_ENERGY_BURNED
];

/// Previous evening 8 pm — start of the sleep capture window.
DateTime _sleepWindowStart() {
  final now = DateTime.now();
  final y = now.subtract(const Duration(days: 1));
  return DateTime(y.year, y.month, y.day, 20);
}

/// Today 10 am (or now if earlier) — end of the sleep capture window.
DateTime _sleepWindowEnd() {
  final now = DateTime.now();
  final tenAm = DateTime(now.year, now.month, now.day, 10);
  return tenAm.isBefore(now) ? tenAm : now;
}

/// Vitals read for the rest / recovery view. Requested separately from the
/// base types so the steps flow is unaffected if the user declines these.
const _kVitalsTypes = [
  HealthDataType.HEART_RATE,
  HealthDataType.RESTING_HEART_RATE,
  HealthDataType.HEART_RATE_VARIABILITY_SDNN,
  HealthDataType.SLEEP_ASLEEP,
  HealthDataType.SLEEP_AWAKE,
  HealthDataType.SLEEP_DEEP,
  HealthDataType.SLEEP_LIGHT,
  HealthDataType.SLEEP_REM,
];

/// Last night's sleep split by stage (minutes). Stage fields are 0 when the
/// source device does not provide stage data.
class SleepNight {
  const SleepNight({
    required this.totalMinutes,
    this.deepMinutes = 0,
    this.lightMinutes = 0,
    this.remMinutes = 0,
    this.awakeMinutes = 0,
  });

  final int totalMinutes;
  final int deepMinutes;
  final int lightMinutes;
  final int remMinutes;
  final int awakeMinutes;

  bool get hasStages => deepMinutes + lightMinutes + remMinutes > 0;
}

// ── Service ────────────────────────────────────────────────────────────────────

class HealthService {
  static final Health _health = Health();

  /// True once [requestPermissions] has returned successfully.
  bool _authorised = false;

  // ── Permissions ─────────────────────────────────────────────────────────────

  /// Request all permissions Zenfit requires.
  ///
  /// Returns true if the base types (steps, active energy) were granted.
  /// Whether the platform health store can be used. Always true on iOS; on
  /// Android, false when Health Connect is missing or needs an update.
  Future<bool> isHealthStoreAvailable() async {
    if (Platform.isIOS) return true;
    try {
      await _health.configure();
      final status = await _health.getHealthConnectSdkStatus();
      return status == HealthConnectSdkStatus.sdkAvailable;
    } catch (e) {
      _log.w('Could not read Health Connect status', error: e);
      return false;
    }
  }

  /// Opens the Play Store listing for Health Connect (Android only).
  Future<void> installHealthStore() async {
    if (Platform.isIOS) return;
    try {
      await _health.installHealthConnect();
    } catch (e) {
      _log.w('Could not open Health Connect install page', error: e);
    }
  }

  Future<bool> requestPermissions() async {
    try {
      await _health.configure();

      _authorised = await _health.requestAuthorization(
        _kBaseTypes,
        permissions: _kBasePermissions,
      );

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

  // ── Vitals: heart rate / sleep / HRV ────────────────────────────────────────

  bool _vitalsAuthorised = false;

  /// Asks for heart-rate, resting heart-rate, HRV and sleep read access.
  /// Returns true when the platform reports access was granted.
  Future<bool> requestVitalsPermissions() async {
    try {
      await _health.configure();
      _vitalsAuthorised = await _health.requestAuthorization(
        _kVitalsTypes,
        permissions: List.filled(_kVitalsTypes.length, HealthDataAccess.READ),
      );
      return _vitalsAuthorised;
    } catch (e) {
      _log.w('Vitals permission request failed', error: e);
      return false;
    }
  }

  Future<bool> _ensureVitals() async {
    if (_vitalsAuthorised) return true;
    try {
      await _health.configure();
      _vitalsAuthorised = await _health.hasPermissions(
            _kVitalsTypes,
            permissions: List.filled(_kVitalsTypes.length, HealthDataAccess.READ),
          ) ==
          true;
    } catch (_) {
      _vitalsAuthorised = false;
    }
    return _vitalsAuthorised;
  }

  /// True when vitals can be read without prompting.
  Future<bool> hasVitalsAccess() => _ensureVitals();

  Future<List<HealthDataPoint>> _read(
    List<HealthDataType> types,
    DateTime from,
    DateTime to,
  ) async {
    try {
      return await _health.getHealthDataFromTypes(
        types: types,
        startTime: from,
        endTime: to,
      );
    } catch (e) {
      _log.w('Could not read $types', error: e);
      return const [];
    }
  }

  static double? _avg(Iterable<HealthDataPoint> pts) {
    final v = pts
        .map((p) => p.value)
        .whereType<NumericHealthValue>()
        .map((n) => n.numericValue.toDouble())
        .toList();
    if (v.isEmpty) return null;
    return v.reduce((a, b) => a + b) / v.length;
  }

  /// Average heart rate (bpm) since midnight, or null when none recorded.
  Future<int?> getTodayAverageHeartRate() async {
    if (!await _ensureVitals()) return null;
    final now = DateTime.now();
    final pts = await _read(
        [HealthDataType.HEART_RATE], DateTime(now.year, now.month, now.day), now);
    return _avg(pts)?.round();
  }

  /// Most recent resting heart rate in the last 7 days (bpm).
  Future<int?> getRestingHeartRate() async {
    if (!await _ensureVitals()) return null;
    final now = DateTime.now();
    final pts = await _read([HealthDataType.RESTING_HEART_RATE],
        now.subtract(const Duration(days: 7)), now);
    if (pts.isEmpty) return null;
    pts.sort((a, b) => b.dateTo.compareTo(a.dateTo));
    return _avg([pts.first])?.round();
  }

  /// Average HRV (SDNN, ms) over the last 2 days, or null.
  Future<double?> getRecentHrv() async {
    if (!await _ensureVitals()) return null;
    final now = DateTime.now();
    final pts = await _read([HealthDataType.HEART_RATE_VARIABILITY_SDNN],
        now.subtract(const Duration(days: 2)), now);
    return _avg(pts);
  }

  /// Last night's sleep (8 pm yesterday → 10 am today) with stage split.
  Future<SleepNight?> getLastNight() async {
    if (!await _ensureVitals()) return null;
    final from = _sleepWindowStart();
    final to = _sleepWindowEnd();
    final pts = await _read([
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_AWAKE,
      HealthDataType.SLEEP_DEEP,
      HealthDataType.SLEEP_LIGHT,
      HealthDataType.SLEEP_REM,
    ], from, to);
    if (pts.isEmpty) return null;

    int mins(HealthDataType t) => pts
        .where((p) => p.type == t)
        .fold<int>(0, (a, p) => a + p.dateTo.difference(p.dateFrom).inMinutes);

    final deep = mins(HealthDataType.SLEEP_DEEP);
    final light = mins(HealthDataType.SLEEP_LIGHT);
    final rem = mins(HealthDataType.SLEEP_REM);
    final asleep = mins(HealthDataType.SLEEP_ASLEEP);
    // Stage-only sources report no generic "asleep" total.
    final total = asleep > 0 ? asleep : deep + light + rem;
    if (total == 0) return null;
    return SleepNight(
      totalMinutes: total,
      deepMinutes: deep,
      lightMinutes: light,
      remMinutes: rem,
      awakeMinutes: mins(HealthDataType.SLEEP_AWAKE),
    );
  }

  /// Total sleep minutes for each of the last [days] nights
  /// (index 0 = oldest, last = last night).
  Future<List<int>> getSleepHistory(int days) async {
    if (!await _ensureVitals()) return List.filled(days, 0);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final pts = await _read([HealthDataType.SLEEP_ASLEEP],
        today.subtract(Duration(days: days)), now);
    final byIdx = List<int>.filled(days, 0);
    for (final p in pts) {
      final wake = DateTime(p.dateTo.year, p.dateTo.month, p.dateTo.day);
      final daysAgo = today.difference(wake).inDays;
      if (daysAgo >= 0 && daysAgo < days) {
        byIdx[days - 1 - daysAgo] += p.dateTo.difference(p.dateFrom).inMinutes;
      }
    }
    return byIdx;
  }

  // ── Write: workout ───────────────────────────────────────────────────────────

  /// Push a completed Zenfit workout to Apple Health / Google Fit so it
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
