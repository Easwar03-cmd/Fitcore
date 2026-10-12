import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import 'cutout_image.dart';
import 'pastel_chip.dart';

/// Big tinted card with chip, two-line title, ▶ call-to-action and a cut-out
/// image that overflows the top edge (reference screen A).
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.title,
    this.chipLabel,
    this.chipIcon,
    this.ctaLabel,
    this.onCta,
    this.subtitle,
    this.tint = PastelTint.sky,
    this.imageName,
    this.fallbackIcon = PhosphorIconsRegular.barbell,
    this.height = 150,
  });

  final String title;
  final String? subtitle;
  final String? chipLabel;
  final IconData? chipIcon;
  final String? ctaLabel;
  final VoidCallback? onCta;
  final PastelTint tint;
  final String? imageName;
  final IconData fallbackIcon;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: title,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              color: tint.color,
              borderRadius: BorderRadius.circular(AppRadius.hero),
            ),
            padding: const EdgeInsets.fromLTRB(18, 16, 0, 16),
            child: Row(
              children: [
                Expanded(
                  flex: 11,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (chipLabel != null)
                        PastelChip(
                            label: chipLabel!, icon: chipIcon, filled: true),
                      const Spacer(),
                      Text(title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.heading.copyWith(fontSize: 18)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.ink)),
                      ],
                      if (ctaLabel != null) ...[
                        const SizedBox(height: 10),
                        _Cta(label: ctaLabel!, onTap: onCta),
                      ],
                    ],
                  ),
                ),
                const Expanded(flex: 9, child: SizedBox()),
              ],
            ),
          ),
          if (imageName != null && CutoutImage.isPhotoName(imageName!))
            // Photographs sit inside the card as a rounded inset tile.
            Positioned(
              right: 10,
              top: 10,
              bottom: 10,
              width: height * 0.92,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.hero - 8),
                child: CutoutImage(
                  name: imageName!,
                  fallbackIcon: fallbackIcon,
                  alignment: Alignment.center,
                ),
              ),
            )
          else if (imageName != null)
            // Transparent cut-outs overflow the card's top edge.
            Positioned(
              right: 4,
              top: -22,
              bottom: 0,
              width: height * 1.05,
              child: CutoutImage(name: imageName!, fallbackIcon: fallbackIcon),
            ),
        ],
      ),
    );
  }
}

class _Cta extends StatelessWidget {
  const _Cta({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: AppTextStyles.bodyStrong),
              const SizedBox(width: 10),
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                child: const Icon(PhosphorIconsFill.play, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
