import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/progress_data.dart';

class WeeklySummaryCard extends StatelessWidget {
  const WeeklySummaryCard({
    super.key,
    required this.thisWeek,
    required this.lastWeek,
  });

  final WeeklySummary thisWeek;
  final WeeklySummary lastWeek;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'This Week',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 100),
            Expanded(
              child: Text(
                'Last Week',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: AppColors.onSurfaceVariant),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _MetricRow(
          label: 'Workouts',
          thisVal: thisWeek.workoutsCompleted.toString(),
          lastVal: lastWeek.workoutsCompleted.toString(),
          thisNumeric: thisWeek.workoutsCompleted.toDouble(),
          lastNumeric: lastWeek.workoutsCompleted.toDouble(),
          higherIsBetter: true,
        ),
        const SizedBox(height: 10),
        _MetricRow(
          label: 'Avg Calories',
          thisVal: thisWeek.avgDailyCalories.toStringAsFixed(0),
          lastVal: lastWeek.avgDailyCalories.toStringAsFixed(0),
          thisNumeric: thisWeek.avgDailyCalories,
          lastNumeric: lastWeek.avgDailyCalories,
          higherIsBetter: null,
        ),
        const SizedBox(height: 10),
        _MetricRow(
          label: 'Volume (kg)',
          thisVal: thisWeek.totalVolumeKg.toStringAsFixed(0),
          lastVal: lastWeek.totalVolumeKg.toStringAsFixed(0),
          thisNumeric: thisWeek.totalVolumeKg,
          lastNumeric: lastWeek.totalVolumeKg,
          higherIsBetter: true,
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.thisVal,
    required this.lastVal,
    required this.thisNumeric,
    required this.lastNumeric,
    required this.higherIsBetter,
  });

  final String label;
  final String thisVal;
  final String lastVal;
  final double thisNumeric;
  final double lastNumeric;
  final bool? higherIsBetter; // null = neutral (no colour coding)

  Color _deltaColor() {
    if (higherIsBetter == null) return AppColors.onSurfaceVariant;
    final isHigher = thisNumeric > lastNumeric;
    return (higherIsBetter! == isHigher) ? AppColors.success : AppColors.error;
  }

  String _deltaText() {
    if (lastNumeric == 0) return '';
    final pct = ((thisNumeric - lastNumeric) / lastNumeric * 100).round();
    return pct > 0 ? '+$pct%' : '$pct%';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final delta = _deltaText();

    return Row(
      children: [
        Expanded(
          child: Text(
            thisVal,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
            ),
          ),
        ),
        SizedBox(
          width: 100,
          child: Column(
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: AppColors.onSurfaceVariant),
              ),
              if (delta.isNotEmpty)
                Text(
                  delta,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: _deltaColor(),
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Text(
            lastVal,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
