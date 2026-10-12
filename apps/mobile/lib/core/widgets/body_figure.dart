import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The nine muscle regions Revive tracks. [id] matches the keys produced by
/// `progress_provider._computeMuscleVolume`.
enum MuscleKey {
  shoulders('shoulders', 'Shoulders', BodyView.front),
  back('back', 'Back', BodyView.back),
  chest('chest', 'Chest', BodyView.front),
  arms('arms', 'Arms', BodyView.front),
  core('core', 'Core', BodyView.front),
  quads('quads', 'Quads', BodyView.front),
  hamstrings('hamstrings', 'Hamstrings', BodyView.back),
  glutes('glutes', 'Glutes', BodyView.back),
  calves('calves', 'Calves', BodyView.front);

  const MuscleKey(this.id, this.label, this.view);
  final String id;
  final String label;

  /// Which side of the body shows this muscle best.
  final BodyView view;
}

enum BodyView { front, back }

/// Stylised mannequin drawn from paths (no image asset), so regions can be
/// coloured and hit-tested. Coordinates live in a 200 × 420 box.
class BodyFigure extends StatelessWidget {
  const BodyFigure({
    super.key,
    required this.view,
    this.highlight,
    this.height = 150,
    this.baseColor = const Color(0xFFDADADA),
    this.highlightColor = AppColors.coral,
  });

  final BodyView view;
  final MuscleKey? highlight;
  final double height;
  final Color baseColor;
  final Color highlightColor;

  static const double _aspect = 200 / 420;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: height * _aspect,
        height: height,
        child: CustomPaint(
          painter: _BodyPainter(view, highlight, baseColor, highlightColor),
        ),
      ),
    );
  }
}

// ── Geometry ──────────────────────────────────────────────────────────────────

Path _rr(double l, double t, double r, double b, double rad) =>
    Path()..addRRect(RRect.fromLTRBR(l, t, r, b, Radius.circular(rad)));

Path _union(List<Path> paths) {
  var out = paths.first;
  for (final p in paths.skip(1)) {
    out = Path.combine(PathOperation.union, out, p);
  }
  return out;
}

final Path _shoulders =
    _union([_rr(36, 74, 76, 114, 18), _rr(124, 74, 164, 114, 18)]);
final Path _arms = _union([
  _rr(32, 116, 58, 172, 12),
  _rr(26, 176, 52, 244, 12),
  _rr(142, 116, 168, 172, 12),
  _rr(148, 176, 174, 244, 12),
]);
final Path _calves =
    _union([_rr(70, 330, 96, 410, 13), _rr(104, 330, 130, 410, 13)]);

final Map<MuscleKey, Path> _front = {
  MuscleKey.shoulders: _shoulders,
  MuscleKey.chest: _union([_rr(72, 80, 99, 122, 11), _rr(101, 80, 128, 122, 11)]),
  MuscleKey.arms: _arms,
  MuscleKey.core: _rr(76, 126, 124, 202, 13),
  MuscleKey.quads: _union([_rr(66, 228, 98, 324, 15), _rr(102, 228, 134, 324, 15)]),
  MuscleKey.calves: _calves,
};

final Map<MuscleKey, Path> _back = {
  MuscleKey.shoulders: _shoulders,
  MuscleKey.back:
      _union([_rr(68, 80, 132, 162, 15), _rr(76, 166, 124, 202, 12)]),
  MuscleKey.arms: _arms,
  MuscleKey.glutes: _union([_rr(70, 206, 99, 248, 15), _rr(101, 206, 130, 248, 15)]),
  MuscleKey.hamstrings:
      _union([_rr(66, 252, 98, 326, 15), _rr(102, 252, 134, 326, 15)]),
  MuscleKey.calves: _calves,
};

final Path _neutral = _union([
  Path()..addOval(Rect.fromCircle(center: const Offset(100, 34), radius: 20)),
  _rr(91, 52, 109, 76, 6),
  _rr(72, 204, 128, 228, 11), // pelvis (front only — glutes cover it from behind)
]);
final Path _neutralBack = _union([
  Path()..addOval(Rect.fromCircle(center: const Offset(100, 34), radius: 20)),
  _rr(91, 52, 109, 76, 6),
]);

/// Returns the regions drawn for [view], back-to-front.
Map<MuscleKey, Path> regionsFor(BodyView view) =>
    view == BodyView.front ? _front : _back;

class _BodyPainter extends CustomPainter {
  _BodyPainter(this.view, this.highlight, this.base, this.hi);

  final BodyView view;
  final MuscleKey? highlight;
  final Color base;
  final Color hi;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 200, size.height / 420);

    final basePaint = Paint()..color = base;
    canvas.drawPath(view == BodyView.front ? _neutral : _neutralBack, basePaint);

    for (final e in regionsFor(view).entries) {
      final on = e.key == highlight;
      canvas.drawPath(e.value, Paint()..color = on ? hi : base);
      if (on) {
        // Soft inner sheen so the highlighted muscle reads as a volume.
        canvas.drawPath(
          e.value,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.18)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }
    }

    if (view == BodyView.front) {
      // Abdominal segmentation lines.
      final line = Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(100, 130), const Offset(100, 198), line);
      for (final y in [150.0, 172.0]) {
        canvas.drawLine(Offset(80, y), Offset(120, y), line);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BodyPainter old) =>
      old.view != view ||
      old.highlight != highlight ||
      old.base != base ||
      old.hi != hi;
}
