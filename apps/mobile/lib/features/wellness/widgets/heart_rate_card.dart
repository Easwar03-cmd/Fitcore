import 'dart:math' show max, min;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Resting heart rate card: today's average HR, zone label, and 7-day trend.
class HeartRateCard extends StatelessWidget {
  const HeartRateCard({
    super.key,
    required this.restingHr,
    required this.hrZoneLabel,
    required this.hrTrend,
  });

  final int? restingHr;
  final String hrZoneLabel;
  final List<int?> hrTrend;

  static Color _zoneColor(String zone) {
    switch (zone) {
      case 'Athlete':
      case 'Excellent':
        return AppColors.success;
      case 'Good':
        return AppColors.info;
      case 'Average':
        return AppColors.warning;
      default:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final zoneColor = _zoneColor(hrZoneLabel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          children: [
            const Icon(Icons.favorite_outline_rounded,
                color: AppColors.error, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Resting Heart Rate',
                  style: AppTextStyles.titleMedium
                      .copyWith(color: Theme.of(context).colorScheme.onSurface)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // HR value + zone badge
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              restingHr != null ? '$restingHr' : '—',
              style: AppTextStyles.displayMedium
                  .copyWith(color: Theme.of(context).colorScheme.onSurface),
            ),
            if (restingHr != null) ...[
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('bpm',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
            ],
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: zoneColor.withAlpha(38),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                hrZoneLabel,
                style:
                    AppTextStyles.labelSmall.copyWith(color: zoneColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('7-day trend',
            style: AppTextStyles.labelSmall
                .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        SizedBox(height: 84, child: _HrTrendChart(trend: hrTrend)),
      ],
    );
  }
}

// ── 7-day trend line chart ────────────────────────────────────────────────────

class _HrTrendChart extends StatelessWidget {
  const _HrTrendChart({required this.trend});

  final List<int?> trend;

  static const _kDayLabels = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

  @override
  Widget build(BuildContext context) {
    final spots = trend.asMap().entries
        .where((e) => e.value != null)
        .map((e) => FlSpot(e.key.toDouble(), e.value!.toDouble()))
        .toList();

    if (spots.isEmpty) {
      return Center(
        child: Text('No HR data yet',
            style: AppTextStyles.bodySmall
                .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
    }

    final values = spots.map((s) => s.y).toList();
    final minY = values.reduce(min) - 5.0;
    final maxY = values.reduce(max) + 5.0;

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.error,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                radius: 3,
                color: AppColors.error,
                strokeWidth: 0,
                strokeColor: Colors.transparent,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.error.withAlpha(20),
            ),
          ),
        ],
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                final idx = value.round();
                if (idx < 0 || idx >= trend.length) {
                  return const SizedBox.shrink();
                }
                final dt = DateTime.now()
                    .subtract(Duration(days: trend.length - 1 - idx));
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    _kDayLabels[dt.weekday % 7],
                    style: AppTextStyles.labelSmall
                        .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 10),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}
