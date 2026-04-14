import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:logger/logger.dart';

final _log = Logger();

// ── Public data class emitted on every position update ────────────────────────

class GpsUpdate {
  const GpsUpdate({
    required this.position,
    required this.route,
    required this.distanceKm,
    this.paceMinPerKm,
  });

  /// Latest GPS fix.
  final LatLng position;

  /// Immutable snapshot of the full route so far.
  final List<LatLng> route;

  /// Total distance accumulated since [GpsService.startTracking] was called.
  final double distanceKm;

  /// Rolling pace over the last [GpsService._paceWindowSec] seconds.
  /// `null` until enough movement has been recorded.
  final double? paceMinPerKm;
}

// ── MET-derived kcal/kg/km coefficients for outdoor cardio exercises ──────────

/// Calories = kcalPerKgPerKm[exerciseId] * weightKg * distanceKm.
/// Coefficients derived from MET values and typical reference speeds.
///   running   → MET 9.8, ref 10 km/h  → 0.98
///   cycling   → MET 7.5, ref 15 km/h  → 0.50
///   walking   → MET 3.5, ref  5 km/h  → 0.70
///   default   → MET 8.0, ref  9 km/h  → ~0.89 (rounded to 0.9)
const Map<String, double> kOutdoorKcalPerKgPerKm = {
  'running': 0.98,
  'cycling': 0.50,
  'walking': 0.70,
};

const double kDefaultOutdoorKcalPerKgPerKm = 0.90;

double outdoorCaloriesForExercise({
  required String exerciseId,
  required double weightKg,
  required double distanceKm,
}) {
  final factor =
      kOutdoorKcalPerKgPerKm[exerciseId] ?? kDefaultOutdoorKcalPerKgPerKm;
  return factor * weightKg * distanceKm;
}

// ── Service ───────────────────────────────────────────────────────────────────

class GpsService {
  GpsService();

  StreamSubscription<Position>? _sub;
  final _controller = StreamController<GpsUpdate>.broadcast();

  final List<LatLng> _points = [];
  double _totalDistanceKm = 0;

  // Keeps (timestamp, point) pairs for rolling pace calculation.
  final List<(DateTime, LatLng)> _recentPoints = [];

  /// Rolling pace window in seconds.
  static const int _paceWindowSec = 30;

  /// Minimum movement in km before a point is accepted (GPS jitter filter).
  static const double _minMovementKm = 0.005; // 5 metres

  Stream<GpsUpdate> get updates => _controller.stream;
  List<LatLng> get currentRoute => List.unmodifiable(_points);
  double get distanceKm => _totalDistanceKm;

  // ── Permission ─────────────────────────────────────────────────────────────

  Future<bool> requestPermission() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always;
  }

  // ── Start / stop ───────────────────────────────────────────────────────────

  Future<bool> startTracking() async {
    final granted = await requestPermission();
    if (!granted) return false;

    _points.clear();
    _totalDistanceKm = 0;
    _recentPoints.clear();

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // only emit updates when moved ≥ 5 metres
    );

    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      _onPosition,
      onError: (Object e, StackTrace st) =>
          _log.e('GPS stream error', error: e, stackTrace: st),
    );
    return true;
  }

  void stopTracking() {
    _sub?.cancel();
    _sub = null;
  }

  void dispose() {
    stopTracking();
    if (!_controller.isClosed) _controller.close();
  }

  // ── Incoming position handler ──────────────────────────────────────────────

  void _onPosition(Position pos) {
    final pt = LatLng(pos.latitude, pos.longitude);
    final now = DateTime.now();

    if (_points.isNotEmpty) {
      final dist = _haversineKm(_points.last, pt);
      if (dist < _minMovementKm) return; // jitter: skip tiny moves
      _totalDistanceKm += dist;
    }

    _points.add(pt);
    _recentPoints.add((now, pt));

    // Trim entries older than the pace window.
    final windowCutoff =
        now.subtract(const Duration(seconds: _paceWindowSec));
    _recentPoints.removeWhere((e) => e.$1.isBefore(windowCutoff));

    double? pace;
    if (_recentPoints.length >= 2) {
      double windowDist = 0;
      for (int i = 1; i < _recentPoints.length; i++) {
        windowDist +=
            _haversineKm(_recentPoints[i - 1].$2, _recentPoints[i].$2);
      }
      if (windowDist > 0.01) {
        // need at least 10 m of movement in the window
        final minutes = _recentPoints.last
                .$1
                .difference(_recentPoints.first.$1)
                .inMilliseconds /
            60000.0;
        pace = minutes / windowDist;
      }
    }

    if (!_controller.isClosed) {
      _controller.add(GpsUpdate(
        position: pt,
        route: List.unmodifiable(List<LatLng>.from(_points)),
        distanceKm: _totalDistanceKm,
        paceMinPerKm: pace,
      ));
    }
  }

  // ── Google Encoded Polyline Algorithm ─────────────────────────────────────

  /// Encodes [points] to a Google Encoded Polyline string.
  static String encodePolyline(List<LatLng> points) {
    final buffer = StringBuffer();
    int prevLat = 0;
    int prevLng = 0;

    for (final p in points) {
      final lat = (p.latitude * 1e5).round();
      final lng = (p.longitude * 1e5).round();
      _encodeChunk(buffer, lat - prevLat);
      _encodeChunk(buffer, lng - prevLng);
      prevLat = lat;
      prevLng = lng;
    }
    return buffer.toString();
  }

  static void _encodeChunk(StringBuffer buf, int value) {
    int v = value < 0 ? ~(value << 1) : (value << 1);
    while (v >= 0x20) {
      buf.writeCharCode((0x20 | (v & 0x1f)) + 63);
      v >>= 5;
    }
    buf.writeCharCode(v + 63);
  }

  // ── Haversine distance ─────────────────────────────────────────────────────

  static double _haversineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final sinLat = math.sin(dLat / 2);
    final sinLon = math.sin(dLon / 2);
    final h = sinLat * sinLat +
        math.cos(_rad(a.latitude)) * math.cos(_rad(b.latitude)) * sinLon * sinLon;
    return 2 * r * math.asin(math.sqrt(h));
  }

  static double _rad(double deg) => deg * math.pi / 180;
}

// ── Riverpod provider ─────────────────────────────────────────────────────────

final gpsServiceProvider = Provider<GpsService>((ref) {
  final service = GpsService();
  ref.onDispose(service.dispose);
  return service;
});
