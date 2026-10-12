import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Drop-in slot for the reference's cut-out photos / 3D renders.
///
/// Loads `assets/images/<name>`; while the real asset has not been supplied it
/// falls back to a soft white disc with [fallbackIcon], so layouts are final
/// before art arrives. See design.md §7 for the file contract.
class CutoutImage extends StatelessWidget {
  const CutoutImage({
    super.key,
    required this.name,
    required this.fallbackIcon,
    this.width,
    this.height,
    this.alignment = Alignment.bottomRight,
    this.fit,
  });

  /// `.jpg` files are rectangular photographs (shown cover-fit, clipped by the
  /// parent); `.png` files are transparent cut-outs / 3D renders (contain-fit).
  static bool isPhotoName(String name) {
    final n = name.toLowerCase();
    return n.endsWith('.jpg') || n.endsWith('.jpeg');
  }

  /// File name inside `assets/images/`, e.g. `hero_athlete_ropes.png`.
  final String name;
  final IconData fallbackIcon;
  final double? width;
  final double? height;
  final Alignment alignment;
  final BoxFit? fit;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: height,
        child: Image.asset(
          'assets/images/$name',
          cacheWidth: 900,
          fit: fit ?? (isPhotoName(name) ? BoxFit.cover : BoxFit.contain),
          alignment: alignment,
          errorBuilder: (_, __, ___) => Center(
            child: Container(
              width: (height ?? width ?? 96) * 0.7,
              height: (height ?? width ?? 96) * 0.7,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: Icon(
                fallbackIcon,
                size: (height ?? width ?? 96) * 0.34,
                color: AppColors.ink.withValues(alpha: 0.75),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
