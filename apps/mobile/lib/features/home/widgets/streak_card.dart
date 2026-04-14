import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Displays the user's current activity streak with a shield indicator.
///
/// Pure StatelessWidget — receives [streak] and [graceUsed] from parent.
class StreakCard extends StatelessWidget {
  const StreakCard({
    super.key,
    required this.streak,
    required this.graceUsed,
  });

  final int streak;
  final bool graceUsed;

  @override
  Widget build(BuildContext context) {
    final hasStreak = streak > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              color: hasStreak ? AppColors.warning : AppColors.onSurfaceVariant,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              'Streak',
              style: AppTextStyles.titleMedium
                  .copyWith(color: AppColors.onBackground),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Count with bounce-in animation
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.7, end: 1.0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.elasticOut,
          builder: (_, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$streak',
                style: AppTextStyles.headlineLarge.copyWith(
                  color: hasStreak
                      ? AppColors.warning
                      : AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 2, left: 4),
                child: Text(
                  streak == 1 ? 'day' : 'days',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Shield status
        Row(
          children: [
            Icon(
              graceUsed
                  ? Icons.shield_outlined
                  : Icons.shield_rounded,
              size: 13,
              color: graceUsed
                  ? AppColors.onSurfaceVariant
                  : AppColors.secondary,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                graceUsed ? 'Shield used' : 'Shield ready',
                style: AppTextStyles.labelSmall.copyWith(
                  color: graceUsed
                      ? AppColors.onSurfaceVariant
                      : AppColors.secondary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
