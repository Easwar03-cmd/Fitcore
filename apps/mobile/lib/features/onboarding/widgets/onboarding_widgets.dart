import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cutout_image.dart';

/// Pill progress bar shown on every onboarding step.
class OnboardingStepBar extends StatelessWidget {
  const OnboardingStepBar({super.key, required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step $current of $total',
      child: ExcludeSemantics(
        child: Row(
          children: List.generate(total, (i) {
            final active = i + 1 <= current;
            return Expanded(
              child: Container(
                height: 6,
                margin: EdgeInsets.only(right: i < total - 1 ? 8 : 0),
                decoration: BoxDecoration(
                  color: active ? AppColors.ink : AppColors.track,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Title + subtitle with a 3D render in a tinted card.
class OnboardingHeader extends StatelessWidget {
  const OnboardingHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.imageName,
    required this.fallbackIcon,
    this.tint = PastelTint.sky,
  });

  final String title;
  final String subtitle;
  final String imageName;
  final IconData fallbackIcon;
  final PastelTint tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: BoxDecoration(
        color: tint.color,
        borderRadius: BorderRadius.circular(AppRadius.hero),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(title,
                      style: AppTextStyles.title.copyWith(fontSize: 24)),
                ),
                const SizedBox(height: 6),
                Text(subtitle,
                    style: AppTextStyles.caption.copyWith(color: AppColors.ink)),
              ],
            ),
          ),
          CutoutImage(
            name: imageName,
            fallbackIcon: fallbackIcon,
            width: 104,
            height: 104,
            alignment: Alignment.center,
          ),
        ],
      ),
    );
  }
}

/// Selectable option row (goal / activity level).
class OnboardingOptionCard extends StatelessWidget {
  const OnboardingOptionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label. $description',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? AppColors.sky : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: selected ? AppColors.tealBright : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: ExcludeSemantics(
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : AppColors.surfaceMuted,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: AppTextStyles.heading),
                      const SizedBox(height: 2),
                      Text(description,
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.ink)),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(PhosphorIconsFill.checkCircle, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
