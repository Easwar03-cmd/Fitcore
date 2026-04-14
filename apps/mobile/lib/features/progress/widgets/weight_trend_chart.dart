import 'dart:math' show min, max;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/body_stat.dart';

class WeightTrendChart extends StatelessWidget {
  const WeightTrendChart({super.key, required this.stats});

  final List<BodyStat> stats;

  @override
  Widget build(BuildContext context) {
    final points = stats.where((s) => s.weightKg != null).toList();
    if (points.isEmpty) {
      return const _EmptyState(
        message: 'No weight entries yet.\nTap + to log your first entry.',
      );
    }

    final spots = points.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.weightKg!))
        .toList();

    final trendSpots = _trendLine(spots);
    final minY = spots.map((s) => s.y).reduce(min) - 2.0;
    final maxY = spots.map((s) => s.y).reduce(max) + 2.0;
    final xInterval = max(1.0, ((spots.length - 1) / 3).floorToDouble());
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall
        ?.copyWith(color: AppColors.onSurfaceVariant);

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.primary,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
                radius: 3.5,
                color: AppColors.primary,
                strokeWidth: 0,
                strokeColor: Colors.transparent,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primary.withValues(alpha: 0.08),
            ),
          ),
          if (trendSpots.length >= 2)
            LineChartBarData(
              spots: trendSpots,
              isCurved: false,
              color: AppColors.warning.withValues(alpha: 0.8),
              barWidth: 1.5,
              dashArray: const [8, 4],
              dotData: const FlDotData(show: false),
            ),
        ],
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
              getTitlesWidget: (value, meta) => SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text(value.toStringAsFixed(1), style: labelStyle),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: xInterval,
              getTitlesWidget: (value, meta) {
                final idx = value.round();
                if (idx < 0 || idx >= points.length) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    _monthDay(points[idx].measuredAt),
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
          horizontalInterval: 2,
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  static List<FlSpot> _trendLine(List<FlSpot> spots) {
    if (spots.length < 2) return [];
    final n = spots.length.toDouble();
    final sumX = spots.fold(0.0, (s, p) => s + p.x);
    final sumY = spots.fold(0.0, (s, p) => s + p.y);
    final sumXY = spots.fold(0.0, (s, p) => s + p.x * p.y);
    final sumX2 = spots.fold(0.0, (s, p) => s + p.x * p.x);
    final denom = n * sumX2 - sumX * sumX;
    if (denom == 0) return [];
    final slope = (n * sumXY - sumX * sumY) / denom;
    final intercept = (sumY - slope * sumX) / n;
    return [
      FlSpot(spots.first.x, slope * spots.first.x + intercept),
      FlSpot(spots.last.x, slope * spots.last.x + intercept),
    ];
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _monthDay(DateTime dt) =>
      '${dt.day} ${_months[dt.month - 1]}';
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
