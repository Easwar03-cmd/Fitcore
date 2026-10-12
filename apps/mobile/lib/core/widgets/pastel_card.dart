import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Flat tinted card — no shadow, no border (design.md §2). The base of every
/// bento tile.
class PastelCard extends StatelessWidget {
  const PastelCard({
    super.key,
    required this.child,
    this.tint = PastelTint.white,
    this.color,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppRadius.card,
    this.onTap,
    this.semanticLabel,
    this.clip = true,
  });

  final Widget child;
  final PastelTint tint;

  /// Overrides [tint] when set.
  final Color? color;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? tint.color;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    Widget card = Material(
      color: bg,
      shape: shape,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
    );
    if (semanticLabel != null) {
      card = Semantics(
        container: true,
        button: onTap != null,
        label: semanticLabel,
        child: card,
      );
    }
    return card;
  }
}
