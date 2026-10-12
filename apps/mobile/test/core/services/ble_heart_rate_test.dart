import 'package:flutter_test/flutter_test.dart';
import 'package:revive/core/services/ble_heart_rate_service.dart';
import 'package:revive/core/services/health_service.dart';
import 'package:revive/features/wearables/providers/vitals_provider.dart';

void main() {
  group('parseHeartRateMeasurement', () {
    test('8-bit value', () {
      expect(parseHeartRateMeasurement([0x00, 72]), 72);
    });

    test('16-bit little-endian value', () {
      expect(parseHeartRateMeasurement([0x01, 0x50, 0x00]), 80);
      expect(parseHeartRateMeasurement([0x01, 0x2C, 0x01]), 300);
    });

    test('ignores extra fields (sensor contact, energy, RR)', () {
      expect(parseHeartRateMeasurement([0x16, 65, 0x10, 0x03, 0x20, 0x03]), 65);
    });

    test('malformed payloads return null', () {
      expect(parseHeartRateMeasurement([]), isNull);
      expect(parseHeartRateMeasurement([0x00]), isNull);
      expect(parseHeartRateMeasurement([0x01, 0x50]), isNull);
    });
  });

  group('VitalsSummary.restScore', () {
    test('null without sleep', () {
      expect(
        const VitalsSummary(hasAccess: true, restingHeartRate: 55).restScore,
        isNull,
      );
    });

    test('8 h sleep, no body metrics → 100', () {
      const v = VitalsSummary(
        hasAccess: true,
        night: SleepNight(totalMinutes: 480),
      );
      expect(v.restScore, 100);
      expect(v.restLabel, 'Well rested');
    });

    test('short sleep scores lower and blends resting HR', () {
      const v = VitalsSummary(
        hasAccess: true,
        night: SleepNight(totalMinutes: 240), // 50 %
        restingHeartRate: 50, // 100 %
      );
      expect(v.restScore, 70); // 50 * 0.6 + 100 * 0.4
      expect(v.restLabel, 'Moderately rested');
    });
  });
}
