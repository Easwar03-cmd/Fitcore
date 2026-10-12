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
