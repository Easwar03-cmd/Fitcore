import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';

/// Butter slide-to-confirm bar ("Connect ›››", reference screen D). Also
/// triggers on a plain tap so it stays usable with assistive tech.
class SlideAction extends StatefulWidget {
  const SlideAction({
    super.key,
    required this.label,
    required this.onComplete,
    this.icon = PhosphorIconsRegular.lightning,
    this.tint = PastelTint.butter,
  });

  final String label;
  final VoidCallback onComplete;
  final IconData icon;
  final PastelTint tint;

  @override
  State<SlideAction> createState() => _SlideActionState();
}

class _SlideActionState extends State<SlideAction> {
  double _drag = 0;

  static const _h = 60.0;
  static const _thumb = 48.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      onTap: widget.onComplete,
      child: LayoutBuilder(
        builder: (context, c) {
          final max = c.maxWidth - _thumb - 12;
          return GestureDetector(
            onTap: widget.onComplete,
            onHorizontalDragUpdate: (d) =>
                setState(() => _drag = (_drag + d.delta.dx).clamp(0, max)),
            onHorizontalDragEnd: (_) {
              if (_drag >= max * 0.85) widget.onComplete();
              setState(() => _drag = 0);
            },
            child: Container(
              height: _h,
              decoration: BoxDecoration(
                color: widget.tint.color,
                borderRadius: BorderRadius.circular(AppRadius.hero),
              ),
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Center(
                    child: ExcludeSemantics(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(widget.label, style: AppTextStyles.bodyStrong),
                          const SizedBox(width: 6),
                          const Icon(PhosphorIconsBold.caretRight, size: 12),
                          const Icon(PhosphorIconsBold.caretRight, size: 12),
                          const Icon(PhosphorIconsBold.caretRight, size: 12),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 6 + _drag,
                    child: Container(
                      width: _thumb,
                      height: _thumb,
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                      child: Icon(widget.icon, size: 22, color: AppColors.ink),
                    ),
                  ),
                  Positioned(
                    right: 6,
                    child: Container(
                      width: _thumb,
                      height: _thumb,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(PhosphorIconsRegular.check, size: 22),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
