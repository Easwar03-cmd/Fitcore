import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Displays today's step count and progress towards the daily step goal.
///
/// Pure StatelessWidget — caller supplies [steps] and optional [stepGoal].
class StepCounterCard extends StatelessWidget {
  const StepCounterCard({
    super.key,
    required this.steps,
    this.stepGoal = 10000,
  });

  final int steps;
  final int stepGoal;

  @override
  Widget build(BuildContext context) {
    final fraction = stepGoal > 0
        ? (steps / stepGoal).clamp(0.0, 1.0)
        : 0.0;
    final pct = (fraction * 100).toInt();
    final goalReached = steps >= stepGoal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.directions_walk_rounded,
              color: goalReached ? AppColors.success : AppColors.secondary,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              'Steps',
              style: AppTextStyles.titleMedium
                  .copyWith(color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _formatSteps(steps),
          style: AppTextStyles.headlineLarge.copyWith(
            color: goalReached ? AppColors.success : Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '/ ${_formatSteps(stepGoal)} goal',
          style: AppTextStyles.bodySmall
              .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: fraction),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (_, value, __) => ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                goalReached ? AppColors.success : AppColors.secondary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '$pct%',
            style: AppTextStyles.labelSmall
                .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  static String _formatSteps(int n) {
    if (n >= 10000) return '${(n / 1000).toStringAsFixed(0)}k';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }
}
