import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Revive logo mark: ink "R" on a lime disc with a butter sun and salmon dot.
/// Drawn in code (same geometry as `assets/icons/gen_revive_logo.py`) so it is
/// crisp at any size and needs no asset.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 64, this.background});

  final double size;

  /// Optional rounded-square plate behind the mark (e.g. [AppColors.sky]).
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Revive',
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _MarkPainter(background)),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.background);
  final Color? background;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 1024;
    canvas.save();
    canvas.scale(s);

    if (background != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(0, 0, 1024, 1024), const Radius.circular(232)),
        Paint()..color = background!,
      );
    }
    // Artwork is authored for a 0.86 fill of the canvas (see generator).
    canvas.translate(512, 512);
    canvas.scale(background == null ? 1.0 : 0.86);
    canvas.translate(-512, -512);

    canvas.drawCircle(const Offset(512, 522), 360, Paint()..color = AppColors.lime);
    canvas.drawCircle(const Offset(790, 236), 104, Paint()..color = AppColors.butter);
    canvas.drawCircle(const Offset(214, 826), 64, Paint()..color = AppColors.salmon);

    final ink = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 112
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(Path()..moveTo(418, 340)..lineTo(418, 716), ink);
    final bowl = Path()
      ..moveTo(418, 340)
      ..lineTo(540, 340)
      ..arcToPoint(const Offset(540, 592),
          radius: const Radius.circular(126), clockwise: true)
      ..lineTo(418, 592);
    canvas.drawPath(bowl, ink);
    canvas.drawPath(Path()..moveTo(548, 592)..lineTo(664, 716), ink);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.background != background;
}

/// Mark + "Revive" wordmark, side by side.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.markSize = 40, this.center = false});

  final double markSize;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment:
          center ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        BrandMark(size: markSize),
        SizedBox(width: markSize * 0.25),
        Text(
          'Revive',
          style: AppTextStyles.title
              .copyWith(fontSize: markSize * 0.58, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
