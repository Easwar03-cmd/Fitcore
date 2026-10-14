import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/pastel_card.dart';

/// Today's step count and progress towards the daily step goal.
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
    final fraction = stepGoal > 0 ? (steps / stepGoal).clamp(0.0, 1.0) : 0.0;
    final goalReached = steps >= stepGoal;

    return PastelCard(
      tint: goalReached ? PastelTint.lime : PastelTint.white,
      padding: const EdgeInsets.all(14),
      semanticLabel:
          'Steps $steps of $stepGoal goal, ${(fraction * 100).toInt()} percent',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                      color: AppColors.surfaceMuted, shape: BoxShape.circle),
                  child:
                      const Icon(PhosphorIconsRegular.footprints, size: 18),
                ),
                const Spacer(),
                Text('${(fraction * 100).toInt()}%', style: AppTextStyles.micro),
              ],
            ),
            const SizedBox(height: 10),
            Text('Steps', style: AppTextStyles.caption),
            Text(_formatSteps(steps), style: AppTextStyles.metricM),
            Text('/ ${_formatSteps(stepGoal)} goal',
                style: AppTextStyles.caption.copyWith(fontSize: 11)),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: fraction),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, value, __) => ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  backgroundColor: AppColors.surfaceMuted,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.ink),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatSteps(int n) {
    if (n >= 10000) return '${(n / 1000).toStringAsFixed(0)}k';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }
}
