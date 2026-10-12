import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/calorie_calculator.dart';
import '../../../core/utils/macro_calculator.dart';
import '../../../features/nutrition/models/food_log.dart';

/// Protein / carbs / fat progress as three tinted pill bars.
///
/// Pure StatelessWidget — receives [totals], [tdee], and [goal] from parent.
class MacroBars extends StatelessWidget {
  const MacroBars({
    super.key,
    required this.totals,
    required this.tdee,
    required this.goal,
  });

  final DayTotals totals;
  final int tdee;
  final FitnessGoal goal;

  @override
  Widget build(BuildContext context) {
    final targets = MacroCalculator.forGoal(
      dailyKcal: tdee.toDouble(),
      goal: goal,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Macros', style: AppTextStyles.heading),
        const SizedBox(height: 14),
        _MacroRow(
          label: 'Protein',
          consumed: totals.proteinG,
          target: targets.proteinG,
          tint: AppColors.sky,
        ),
        const SizedBox(height: 14),
        _MacroRow(
          label: 'Carbs',
          consumed: totals.carbsG,
          target: targets.carbsG,
          tint: AppColors.butter,
        ),
        const SizedBox(height: 14),
        _MacroRow(
          label: 'Fat',
          consumed: totals.fatG,
          target: targets.fatG,
          tint: AppColors.salmon,
        ),
      ],
    );
  }
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({
    required this.label,
    required this.consumed,
    required this.target,
    required this.tint,
  });

  final String label;
  final double consumed;
  final double target;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final fraction = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;

    return Semantics(
      label: '$label ${consumed.toInt()} of ${target.toInt()} grams',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: AppTextStyles.caption),
                Text(
                  '${consumed.toInt()} g / ${target.toInt()} g',
                  style: AppTextStyles.micro.copyWith(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: fraction),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, value, __) => ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 10,
                  backgroundColor: AppColors.surfaceMuted,
                  valueColor: AlwaysStoppedAnimation<Color>(tint),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
