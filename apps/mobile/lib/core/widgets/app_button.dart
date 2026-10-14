import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum AppButtonVariant { primary, secondary, ghost }

/// Pill button: primary = ink, secondary = white, ghost = text.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final onDark = variant == AppButtonVariant.primary;
    final child = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: onDark ? Colors.white : AppColors.ink,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    return switch (variant) {
      AppButtonVariant.primary =>
        ElevatedButton(onPressed: isLoading ? null : onPressed, child: child),
      AppButtonVariant.secondary =>
        OutlinedButton(onPressed: isLoading ? null : onPressed, child: child),
      AppButtonVariant.ghost =>
        TextButton(onPressed: isLoading ? null : onPressed, child: child),
    };
  }
}
