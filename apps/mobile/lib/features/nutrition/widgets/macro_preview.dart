import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Four tinted pills: kcal, protein, carbs, fat for the amount being logged.
class MacroPreview extends StatelessWidget {
  const MacroPreview({
    super.key,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MacroCol(
            label: 'kcal',
            value: calories.round().toString(),
            color: AppColors.lime),
        const SizedBox(width: 8),
        _MacroCol(
            label: 'Protein',
            value: '${protein.toStringAsFixed(1)}g',
            color: AppColors.sky),
        const SizedBox(width: 8),
        _MacroCol(
            label: 'Carbs',
            value: '${carbs.toStringAsFixed(1)}g',
            color: AppColors.butter),
        const SizedBox(width: 8),
        _MacroCol(
            label: 'Fat',
            value: '${fat.toStringAsFixed(1)}g',
            color: AppColors.salmon),
      ],
    );
  }
}

class _MacroCol extends StatelessWidget {
  const _MacroCol(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: '$label $value',
        child: ExcludeSemantics(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(value,
                    style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                const SizedBox(height: 2),
                Text(label,
                    style:
                        const TextStyle(color: AppColors.ink, fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
