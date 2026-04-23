import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Applies Exponential Moving Average (EMA) to ML Kit pose landmarks.
///
/// At 6 fps with α=0.5 each new frame contributes 50% of the final value
/// — fast enough to track real movement, smooth enough to eliminate jitter.
class PoseSmoother {
  static const double _alpha = 0.50;

  final Map<PoseLandmarkType, _SmLm> _data = {};

  /// Feed a raw [Pose]. Returns a new [Pose] with smoothed coordinates.
  Pose update(Pose raw) {
    for (final e in raw.landmarks.entries) {
      final prev = _data[e.key];
      if (prev == null) {
        _data[e.key] = _SmLm.from(e.value);
      } else {
        prev.blend(e.value, _alpha);
      }
    }
    return _build();
  }

  /// Reset all smoothing state (call when switching exercises or resetting).
  void reset() => _data.clear();

  Pose _build() => Pose(
        landmarks: {
          for (final e in _data.entries)
            e.key: PoseLandmark(
              type: e.key,
              x: e.value.x,
              y: e.value.y,
              z: e.value.z,
              likelihood: e.value.likelihood,
            ),
        },
      );
}

class _SmLm {
  double x, y, z, likelihood;

  _SmLm.from(PoseLandmark lm)
      : x = lm.x,
        y = lm.y,
        z = lm.z,
        likelihood = lm.likelihood;

  void blend(PoseLandmark lm, double a) {
    x = x * (1 - a) + lm.x * a;
    y = y * (1 - a) + lm.y * a;
    z = z * (1 - a) + lm.z * a;
    likelihood = likelihood * (1 - a) + lm.likelihood * a;
  }
}
