import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class RulerSeries {
  const RulerSeries({
    required this.values,
    required this.color,
    this.tagIndexes = const [],
    this.tagLabels = const [],
  });

  /// Y values, evenly spaced across the x axis.
  final List<double> values;
  final Color color;

  /// Points that get a value tag, and the tag text for each.
  final List<int> tagIndexes;
  final List<String> tagLabels;
}

/// Smooth lines over a tick-mark "ruler" x-axis with value tags
/// (reference screen C). No grid and no y-axis.
class RulerLineChart extends StatelessWidget {
  const RulerLineChart({
    super.key,
    required this.series,
    required this.xLabels,
    this.height = 150,
    this.semanticLabel,
  });

  final List<RulerSeries> series;
  final List<String> xLabels;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel ?? 'Line chart',
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (_, t, __) => SizedBox(
            height: height,
            width: double.infinity,
            child: CustomPaint(
              painter: _RulerPainter(series, xLabels, t),
            ),
          ),
        ),
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  _RulerPainter(this.series, this.xLabels, this.t);
  final List<RulerSeries> series;
  final List<String> xLabels;
  final double t;

  static const _axisH = 34.0;
  static const _tagH = 20.0;

  @override
  void paint(Canvas canvas, Size size) {
    final chartH = size.height - _axisH;
    _paintAxis(canvas, size, chartH);

    var minV = double.infinity;
    var maxV = double.negativeInfinity;
    for (final s in series) {
      for (final v in s.values) {
        if (v < minV) minV = v;
        if (v > maxV) maxV = v;
      }
    }
    if (minV.isInfinite || maxV == minV) {
      minV = (minV.isInfinite ? 0 : minV) - 1;
      maxV = minV + 2;
    }
    const top = _tagH + 6;
    final usable = chartH - top - 8;

    for (final s in series) {
      if (s.values.length < 2) continue;
      final pts = <Offset>[
        for (var i = 0; i < s.values.length; i++)
          Offset(
            i / (s.values.length - 1) * size.width,
            top + usable - (s.values[i] - minV) / (maxV - minV) * usable,
          ),
      ];
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (var i = 0; i < pts.length - 1; i++) {
        final p0 = pts[i];
        final p1 = pts[i + 1];
        final mx = (p0.dx + p1.dx) / 2;
        path.cubicTo(mx, p0.dy, mx, p1.dy, p1.dx, p1.dy);
      }
      final metric = path.computeMetrics().first;
      final drawn = metric.extractPath(0, metric.length * t);
      canvas.drawPath(
        drawn,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = s.color,
      );

      if (t < 1) continue;
      for (var k = 0; k < s.tagIndexes.length && k < s.tagLabels.length; k++) {
        final i = s.tagIndexes[k].clamp(0, pts.length - 1);
        _paintTag(canvas, size, pts[i], s.tagLabels[k], s.color);
      }
    }
  }

  void _paintAxis(Canvas canvas, Size size, double chartH) {
    if (xLabels.isEmpty) return;
    const ticks = 41;
    final tickPaint = Paint()
      ..color = AppColors.inkMuted.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    for (var i = 0; i < ticks; i++) {
      final x = i / (ticks - 1) * size.width;
      final major = i % 10 == 0;
      canvas.drawLine(
        Offset(x, chartH + 6),
        Offset(x, chartH + (major ? 18 : 12)),
        tickPaint,
      );
    }
    for (var i = 0; i < xLabels.length; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: xLabels[i],
          style: AppTextStyles.micro.copyWith(color: AppColors.inkMuted),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final frac = xLabels.length == 1 ? 0.0 : i / (xLabels.length - 1);
      var x = frac * size.width - tp.width / 2;
      x = x.clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(x, chartH + 20));
    }
  }

  void _paintTag(Canvas canvas, Size size, Offset p, String text, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: AppTextStyles.micro.copyWith(color: AppColors.ink, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = tp.width + 10;
    var x = p.dx - w / 2;
    x = x.clamp(0.0, size.width - w);
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, p.dy - _tagH - 6, w, _tagH),
      const Radius.circular(10),
    );
    canvas.drawRRect(rect, Paint()..color = Colors.white);
    tp.paint(canvas, Offset(x + 5, p.dy - _tagH - 6 + (_tagH - tp.height) / 2));
    canvas.drawCircle(p, 3.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_RulerPainter old) =>
      old.t != t || old.series != series || old.xLabels != xLabels;
}
