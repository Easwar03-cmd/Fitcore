import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Small pill (reference "Challenge" / "PRO" chips and the Stress / Recovery
/// dot-chips).
class PastelChip extends StatelessWidget {
  const PastelChip({
    super.key,
    required this.label,
    this.icon,
    this.dotColor,
    this.filled = false,
    this.background,
    this.foreground,
    this.onTap,
  });

  final String label;
  final IconData? icon;

  /// Leading coloured dot (Stress ● / Recovery ●).
  final Color? dotColor;

  /// Solid teal with white text (the reference "Challenge" / "PRO" chip).
  final bool filled;
  final Color? background;
  final Color? foreground;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = background ?? (filled ? AppColors.teal : AppColors.surface);
    final fg = foreground ?? (filled ? Colors.white : AppColors.ink);
    return Material(
      color: bg,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 28),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dotColor != null) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration:
                        BoxDecoration(color: dotColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                ],
                if (icon != null) ...[
                  Icon(icon, size: 14, color: fg),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.micro.copyWith(color: fg),
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
