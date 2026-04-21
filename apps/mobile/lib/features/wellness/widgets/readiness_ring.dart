import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/wellness_state.dart';

/// Animated readiness ring showing the composite daily score (0-100) with a
/// one-line training recommendation below.
class ReadinessRing extends StatefulWidget {
  const ReadinessRing({
    super.key,
    required this.score,
    required this.label,
    required this.level,
    this.size = 180,
  });

  final int score;
  final String label;
  final ReadinessLevel level;
  final double size;

  @override
  State<ReadinessRing> createState() => _ReadinessRingState();
}

class _ReadinessRingState extends State<ReadinessRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<double> _anim;

  double get _fraction => widget.score / 100.0;

  Color get _ringColor => switch (widget.level) {
        ReadinessLevel.rest => AppColors.error,
        ReadinessLevel.light => AppColors.warning,
        ReadinessLevel.hard => AppColors.success,
      };

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _anim = Tween<double>(begin: 0.0, end: _fraction)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(ReadinessRing old) {
    super.didUpdateWidget(old);
    final oldFraction = old.score / 100.0;
    _anim = Tween<double>(begin: oldFraction, end: _fraction)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _anim,
          builder: (_, __) => SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _ReadinessRingPainter(
                progress: _anim.value,
                color: _ringColor,
                trackColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${widget.score}',
                      style: AppTextStyles.displayMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Readiness',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: _ringColor.withAlpha(38),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            widget.label,
            style: AppTextStyles.titleMedium.copyWith(color: _ringColor),
          ),
        ),
      ],
    );
  }
}

// ── Ring painter ──────────────────────────────────────────────────────────────

class _ReadinessRingPainter extends CustomPainter {
  const _ReadinessRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  static const double _strokeWidth = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - _strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..strokeWidth = _strokeWidth
        ..style = PaintingStyle.stroke,
    );

    if (progress <= 0) return;

    // Progress arc — clockwise from 12 o'clock
    canvas.drawArc(
      rect,
      -pi / 2,
      2 * pi * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = color
        ..strokeWidth = _strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ReadinessRingPainter old) =>
      old.progress != progress || old.color != color || old.trackColor != trackColor;
}
