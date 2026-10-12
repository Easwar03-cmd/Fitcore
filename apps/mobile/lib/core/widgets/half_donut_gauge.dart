import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';

/// 180° gauge with value, title, caption and a ▲/▼ delta
/// (reference screen B). Direction is always printed, never colour-only.
class HalfDonutGauge extends StatelessWidget {
  const HalfDonutGauge({
    super.key,
    required this.title,
    required this.caption,
    required this.fraction,
    this.valueLabel,
    this.deltaPercent,
    this.positive = true,
  });

  final String title;
  final String caption;

  /// 0..1
  final double fraction;
  final String? valueLabel;
  final int? deltaPercent;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final f = fraction.clamp(0.0, 1.0);
    final pct = valueLabel ?? '${(f * 100).round()}%';
    final color = positive ? AppColors.tealBright : AppColors.coral;
    final delta = deltaPercent;

    return Semantics(
      label: '$title $pct${delta == null ? '' : ', ${delta >= 0 ? 'up' : 'down'} ${delta.abs()} percent'}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(title,
                      style: AppTextStyles.micro.copyWith(
                          fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ],
            ),
            Text(caption, style: AppTextStyles.caption.copyWith(fontSize: 11)),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(pct, style: AppTextStyles.metricL),
                const Spacer(),
                SizedBox(
                  width: 88,
                  height: 52,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: f),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => CustomPaint(
                      painter: _ArcPainter(v, color),
                      child: delta == null
                          ? null
                          : Align(
                              alignment: Alignment.bottomRight,
                              child: _Delta(value: delta),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Delta extends StatelessWidget {
  const _Delta({required this.value});
  final int value;

  @override
  Widget build(BuildContext context) {
    final up = value >= 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(up ? PhosphorIconsBold.caretUp : PhosphorIconsBold.caretDown,
            size: 9, color: AppColors.inkMuted),
        const SizedBox(width: 2),
        Text('${value.abs()}%',
            style: AppTextStyles.micro
                .copyWith(fontSize: 10, color: AppColors.inkMuted)),
      ],
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.t, this.color);
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 9.0;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height - 2),
      width: size.width - stroke,
      height: (size.width - stroke),
    );
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = AppColors.track;
    final value = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, math.pi, math.pi, false, track);
    canvas.drawArc(rect, math.pi, math.pi * t, false, value);
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.t != t || old.color != color;
}

/// White card holding two gauges side by side with a hairline between them.
class GaugeCard extends StatelessWidget {
  const GaugeCard({super.key, required this.left, required this.right});
  final HalfDonutGauge left;
  final HalfDonutGauge right;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.hero),
      ),
      child: Column(
        children: [
          left,
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(),
          ),
          right,
        ],
      ),
    );
  }
}
