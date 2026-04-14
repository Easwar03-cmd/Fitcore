import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Animated circular progress ring showing calories consumed vs. daily target.
///
/// Animates from 0 → current fraction on mount and re-animates whenever
/// [consumed] or [target] changes. Turns red when [consumed] > [target].
class CalorieRing extends StatefulWidget {
  const CalorieRing({
    super.key,
    required this.consumed,
    required this.target,
    this.size = 200,
  });

  final double consumed;
  final int target;
  final double size;

  @override
  State<CalorieRing> createState() => _CalorieRingState();
}

class _CalorieRingState extends State<CalorieRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<double> _progressAnim;

  double get _targetFraction =>
      widget.target > 0
          ? (widget.consumed / widget.target).clamp(0.0, 1.0)
          : 0.0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _setAnimation(from: 0.0, to: _targetFraction);
    _ctrl.forward();
  }

  void _setAnimation({required double from, required double to}) {
    _progressAnim = Tween<double>(begin: from, end: to).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didUpdateWidget(CalorieRing old) {
    super.didUpdateWidget(old);
    final oldFraction =
        old.target > 0 ? (old.consumed / old.target).clamp(0.0, 1.0) : 0.0;
    _setAnimation(from: oldFraction, to: _targetFraction);
    _ctrl
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOver = widget.consumed > widget.target;
    final remaining =
        (widget.target - widget.consumed).clamp(0.0, widget.target.toDouble());

    return AnimatedBuilder(
      animation: _progressAnim,
      builder: (_, __) => SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _RingPainter(
            progress: _progressAnim.value,
            isOver: isOver,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.consumed.toInt().toString(),
                  style: AppTextStyles.displayMedium.copyWith(
                    color: AppColors.onBackground,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'kcal eaten',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color:
                        (isOver ? AppColors.error : AppColors.primary)
                            .withAlpha(38),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isOver
                        ? '${(widget.consumed - widget.target).toInt()} over'
                        : '${remaining.toInt()} left',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: isOver ? AppColors.error : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.isOver});

  final double progress;
  final bool isOver;

  static const double _strokeWidth = 16.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - _strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.surfaceVariant
        ..strokeWidth = _strokeWidth
        ..style = PaintingStyle.stroke,
    );

    if (progress <= 0) return;

    // Progress arc — clockwise from 12 o'clock (−π/2)
    canvas.drawArc(
      rect,
      -pi / 2,
      2 * pi * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = isOver ? AppColors.error : AppColors.primary
        ..strokeWidth = _strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.isOver != isOver;
}
