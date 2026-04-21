import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/progress_data.dart';

class StrengthCurveChart extends StatelessWidget {
  const StrengthCurveChart({super.key, required this.curves});

  final Map<String, List<ExerciseWeekPoint>> curves;

  static const _lineColors = [
    AppColors.primary,
    AppColors.secondary,
    AppColors.warning,
  ];

  @override
  Widget build(BuildContext context) {
    if (curves.isEmpty) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Text(
            'Log weighted exercises to see strength curves.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    final now = DateTime.now();
    final thisWeekStart = _weekStart(now);
    final entries = curves.entries.toList();

    // Build one LineChartBarData per exercise.
    final lineBars = entries.asMap().entries.map((indexed) {
      final colorIdx = indexed.key % _lineColors.length;
      final points = indexed.value.value;
      final spots = points.map((p) {
        final weeksAgo =
            thisWeekStart.difference(p.weekStart).inDays ~/ 7;
        final x = (7 - weeksAgo).toDouble().clamp(0.0, 7.0);
        return FlSpot(x, p.maxWeightKg);
      }).toList()
        ..sort((a, b) => a.x.compareTo(b.x));

      return LineChartBarData(
        spots: spots,
        isCurved: true,
        color: _lineColors[colorIdx],
        barWidth: 2.0,
        dotData: FlDotData(
          show: true,
          getDotPainter: (s, pct, bar, idx) => FlDotCirclePainter(
            radius: 3.5,
            color: _lineColors[colorIdx],
            strokeWidth: 0,
            strokeColor: Colors.transparent,
          ),
        ),
      );
    }).toList();

    // Y-axis bounds.
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    for (final pts in curves.values) {
      for (final p in pts) {
        if (p.maxWeightKg < minY) minY = p.maxWeightKg;
        if (p.maxWeightKg > maxY) maxY = p.maxWeightKg;
      }
    }
    if (minY == double.infinity) { minY = 0; maxY = 100; }
    final yPad = (maxY - minY) * 0.15 + 5.0;

    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);

    return Column(
      children: [
        Expanded(
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: 7,
              minY: (minY - yPad).clamp(0.0, double.infinity),
              maxY: maxY + yPad,
              lineBarsData: lineBars,
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
                    reservedSize: 44,
                    getTitlesWidget: (val, meta) => SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: Text('${val.toInt()}kg', style: labelStyle),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: 1,
                    getTitlesWidget: (val, meta) {
                      if (val % 1 != 0) return const SizedBox.shrink();
                      final idx = val.toInt();
                      final label = idx == 7 ? 'Now' : 'W${idx + 1}';
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        child: Text(label, style: labelStyle),
                      );
                    },
                  ),
                ),
              ),
              gridData: const FlGridData(
                show: true,
                drawVerticalLine: false,
              ),
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Legend
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: entries.asMap().entries.map((indexed) {
            final colorIdx = indexed.key % _lineColors.length;
            final name = indexed.value.key;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 3,
                  color: _lineColors[colorIdx],
                ),
                const SizedBox(width: 4),
                Text(
                  name,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  static DateTime _weekStart(DateTime d) =>
      DateTime(d.year, d.month, d.day - (d.weekday - 1));
}
