import 'dart:math' show max;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/services/health_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Sleep summary card: last-night duration, stages bar, 7-day trend bar chart,
/// and a sleep score badge.
class SleepCard extends StatelessWidget {
  const SleepCard({
    super.key,
    required this.sleepMinutes,
    required this.sleepScore,
    required this.sleepTrend,
    this.stages,
  });

  final int sleepMinutes;
  final int sleepScore;
  final List<int> sleepTrend;
  final SleepStages? stages;

  @override
  Widget build(BuildContext context) {
    final h = sleepMinutes ~/ 60;
    final m = sleepMinutes % 60;
    final durationText =
        sleepMinutes > 0 ? (h > 0 ? '${h}h ${m}m' : '${m}m') : 'No data';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          children: [
            const Icon(Icons.bedtime_outlined, color: AppColors.info, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Sleep',
                  style: AppTextStyles.titleMedium
                      .copyWith(color: Theme.of(context).colorScheme.onSurface)),
            ),
            _ScoreBadge(score: sleepScore, color: AppColors.info),
          ],
        ),
        const SizedBox(height: 12),
        // Duration headline
        Text(durationText,
            style: AppTextStyles.displayMedium
                .copyWith(color: Theme.of(context).colorScheme.onSurface)),
        Text('last night',
            style: AppTextStyles.bodySmall
                .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        // Stages bar (only when stage data is available)
        if (stages != null && sleepMinutes > 0) ...[
          const SizedBox(height: 16),
          _SleepStagesBar(stages: stages!, totalMinutes: sleepMinutes),
        ],
        const SizedBox(height: 16),
        Text('7-day trend',
            style: AppTextStyles.labelSmall
                .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        SizedBox(height: 84, child: _SleepTrendChart(trend: sleepTrend)),
      ],
    );
  }
}

// ── Stages bar ────────────────────────────────────────────────────────────────

class _SleepStagesBar extends StatelessWidget {
  const _SleepStagesBar(
      {required this.stages, required this.totalMinutes});

  final SleepStages stages;
  final int totalMinutes;

  @override
  Widget build(BuildContext context) {
    final sumStages =
        stages.deepMinutes + stages.lightMinutes + stages.remMinutes;
    final awake = (totalMinutes - sumStages).clamp(0, totalMinutes);
    final total = sumStages + awake;
    if (total == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                if (stages.deepMinutes > 0)
                  Expanded(
                    flex: stages.deepMinutes,
                    child: Container(color: AppColors.primary),
                  ),
                if (stages.lightMinutes > 0)
                  Expanded(
                    flex: stages.lightMinutes,
                    child: Container(color: AppColors.info),
                  ),
                if (stages.remMinutes > 0)
                  Expanded(
                    flex: stages.remMinutes,
                    child: Container(color: AppColors.secondary),
                  ),
                if (awake > 0)
                  Expanded(
                    flex: awake,
                    child:
                        Container(color: AppColors.error.withAlpha(180)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _StageLegend('Deep', '${stages.deepMinutes}m', AppColors.primary),
            const SizedBox(width: 14),
            _StageLegend('Light', '${stages.lightMinutes}m', AppColors.info),
            const SizedBox(width: 14),
            _StageLegend('REM', '${stages.remMinutes}m', AppColors.secondary),
            if (awake > 0) ...[
              const SizedBox(width: 14),
              _StageLegend('Awake', '${awake}m', AppColors.error),
            ],
          ],
        ),
      ],
    );
  }
}

class _StageLegend extends StatelessWidget {
  const _StageLegend(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: AppTextStyles.labelSmall
                    .copyWith(color: Theme.of(context).colorScheme.onSurface)),
            Text(label,
                style: AppTextStyles.labelSmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10)),
          ],
        ),
      ],
    );
  }
}

// ── 7-day trend bar chart ─────────────────────────────────────────────────────

class _SleepTrendChart extends StatelessWidget {
  const _SleepTrendChart({required this.trend});

  final List<int> trend;

  static const _kDayLabels = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

  @override
  Widget build(BuildContext context) {
    if (trend.every((v) => v == 0)) {
      return Center(
        child: Text('No trend data yet',
            style: AppTextStyles.bodySmall
                .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
    }

    final hours = trend.map((v) => v / 60.0).toList();
    final maxH = hours.reduce(max);

    return BarChart(
      BarChartData(
        maxY: max(maxH + 0.5, 9.0),
        barGroups: hours.asMap().entries.map((e) {
          final isGood = e.value >= 7.0;
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value,
                color: isGood ? AppColors.info : AppColors.info.withAlpha(130),
                width: 14,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
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
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

// ── Shared score badge ────────────────────────────────────────────────────────

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score, required this.color});

  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Score $score',
        style: AppTextStyles.labelSmall.copyWith(color: color),
      ),
    );
  }
}
