import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Round 44 px control used for every header / inline action (design.md §4).
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.size = 44,
    this.iconSize = 22,
    this.selected = false,
    this.showDot = false,
    this.background,
    this.foreground,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final double size;
  final double iconSize;

  /// Selected = ink circle with white glyph.
  final bool selected;

  /// Orange unread dot (bell).
  final bool showDot;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.ink : (background ?? AppColors.surface);
    final fg = selected ? Colors.white : (foreground ?? AppColors.ink);
    // Keep a 44 px hit area even for smaller visual sizes.
    final hit = size < 44 ? 44.0 : size;

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      selected: selected,
      child: Tooltip(
        message: semanticLabel,
        child: SizedBox(
          width: hit,
          height: hit,
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Material(
                  color: bg,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onPressed,
                    child: SizedBox(
                      width: size,
                      height: size,
                      child: Icon(icon, size: iconSize, color: fg),
                    ),
                  ),
                ),
                if (showDot)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.alertDot,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.bg, width: 1.5),
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
