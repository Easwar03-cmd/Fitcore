import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/progress_data.dart';

class CalorieTrendChart extends StatelessWidget {
  const CalorieTrendChart({
    super.key,
    required this.days,
    required this.calorieTarget,
  });

  final List<DayCalories> days;
  final int calorieTarget;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(
          child: Text(
            'No calorie data yet.',
            style: TextStyle(color: AppColors.onSurfaceVariant),
          ),
        ),
      );
    }

    final maxCal = days.map((d) => d.calories).fold(0.0, (a, b) => a > b ? a : b);
    final maxY = (maxCal > calorieTarget ? maxCal : calorieTarget.toDouble()) * 1.15;
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall
        ?.copyWith(color: AppColors.onSurfaceVariant);

    return BarChart(
      BarChartData(
        maxY: maxY,
        barGroups: days.asMap().entries.map((e) {
          final day = e.value;
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: day.calories,
                color: day.isUnder ? AppColors.success : AppColors.error,
                width: 22,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              interval: 500,
              getTitlesWidget: (val, meta) => SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text(val.toInt().toString(), style: labelStyle),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (val, meta) {
                final idx = val.round();
                if (idx < 0 || idx >= days.length) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    _dayAbbr(days[idx].date),
                    style: labelStyle,
                  ),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 500,
        ),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: calorieTarget.toDouble(),
              color: AppColors.warning,
              strokeWidth: 1.5,
              dashArray: [6, 4],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                labelResolver: (_) => 'Target',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: AppColors.warning),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _abbr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static String _dayAbbr(DateTime d) => _abbr[d.weekday - 1];
}
