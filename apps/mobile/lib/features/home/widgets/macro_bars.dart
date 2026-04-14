import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/calorie_calculator.dart';
import '../../../core/utils/macro_calculator.dart';
import '../../../features/nutrition/models/food_log.dart';

/// Three animated macro progress bars (protein / carbs / fat).
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
        Text(
          'Macros',
          style: AppTextStyles.titleMedium
              .copyWith(color: AppColors.onBackground),
        ),
        const SizedBox(height: 14),
        _MacroRow(
          label: 'Protein',
          unit: 'g',
          consumed: totals.proteinG,
          target: targets.proteinG,
          color: AppColors.protein,
        ),
        const SizedBox(height: 12),
        _MacroRow(
          label: 'Carbs',
          unit: 'g',
          consumed: totals.carbsG,
          target: targets.carbsG,
          color: AppColors.carbs,
        ),
        const SizedBox(height: 12),
        _MacroRow(
          label: 'Fat',
          unit: 'g',
          consumed: totals.fatG,
          target: targets.fatG,
          color: AppColors.fat,
        ),
      ],
    );
  }
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({
    required this.label,
    required this.unit,
    required this.consumed,
    required this.target,
    required this.color,
  });

  final String label;
  final String unit;
  final double consumed;
  final double target;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fraction =
        target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
            Text(
              '${consumed.toInt()}$unit / ${target.toInt()}$unit',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.onSurface),
            ),
          ],
        ),
        const SizedBox(height: 5),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: fraction),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (_, value, __) => ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }
}
