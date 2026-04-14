import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/wellness_state.dart';

const _kEmojis = ['😞', '😕', '😐', '🙂', '😄'];
const _kMoodColors = [
  AppColors.error,
  AppColors.warning,
  AppColors.onSurfaceVariant,
  AppColors.info,
  AppColors.success,
];

/// Mood logging card: a 5-point emoji scale tappable once per day, plus a
/// 14-day trend line chart.
class MoodLoggerCard extends StatelessWidget {
  const MoodLoggerCard({
    super.key,
    required this.todayMood,
    required this.moodHistory,
    required this.onLog,
  });

  /// 1-5 if already logged today, null if not yet.
  final int? todayMood;
  final List<MoodLogEntry> moodHistory;

  /// Called with a score 1-5 when the user taps an emoji.
  final void Function(int score) onLog;

  @override
  Widget build(BuildContext context) {
    final alreadyLogged = todayMood != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          children: [
            const Icon(Icons.sentiment_satisfied_alt_outlined,
                color: AppColors.warning, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Mood',
                  style: AppTextStyles.titleMedium
                      .copyWith(color: AppColors.onBackground)),
            ),
            if (alreadyLogged)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withAlpha(38),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('✓ Logged',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.success)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // Emoji picker
        Text(
          alreadyLogged ? 'Today\'s mood' : 'How are you feeling today?',
          style: AppTextStyles.bodySmall
              .copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(5, (i) {
            final score = i + 1;
            final isSelected = todayMood == score;
            return GestureDetector(
              onTap: alreadyLogged ? null : () => onLog(score),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _kMoodColors[i].withAlpha(50)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: _kMoodColors[i], width: 2)
                      : null,
                ),
                child: Text(
                  _kEmojis[i],
                  style: TextStyle(
                    fontSize: 28,
                    color: alreadyLogged && !isSelected
                        ? Colors.white.withAlpha(100)
                        : null,
                  ),
                ),
              ),
            );
          }),
        ),
        if (moodHistory.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('14-day trend',
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 8),
          SizedBox(height: 84, child: _MoodTrendChart(history: moodHistory)),
        ],
      ],
    );
  }
}

// ── 14-day mood trend line chart ──────────────────────────────────────────────

class _MoodTrendChart extends StatelessWidget {
  const _MoodTrendChart({required this.history});

  final List<MoodLogEntry> history;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today =
        DateTime(now.year, now.month, now.day);

    // Group entries by day; keep latest per day.
    final byDay = <int, double>{};
    for (final e in history) {
      final entryDay = DateTime(
          e.loggedAt.year, e.loggedAt.month, e.loggedAt.day);
      final daysAgo = today.difference(entryDay).inDays;
      if (daysAgo >= 0 && daysAgo < 14) {
        byDay[13 - daysAgo] = e.score.toDouble();
      }
    }

    final spots = byDay.entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList()
      ..sort((a, b) => a.x.compareTo(b.x));

    if (spots.isEmpty) return const SizedBox.shrink();

    return LineChart(
      LineChartData(
        minY: 0.5,
        maxY: 5.5,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.warning,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) {
                final idx = spot.y.round() - 1;
                final color = idx >= 0 && idx < 5
                    ? _kMoodColors[idx]
                    : AppColors.warning;
                return FlDotCirclePainter(
                  radius: 4,
                  color: color,
                  strokeWidth: 0,
                  strokeColor: Colors.transparent,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.warning.withAlpha(18),
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
              interval: 7,
              getTitlesWidget: (value, meta) {
                final idx = value.round();
                if (idx != 0 && idx != 7 && idx != 13) {
                  return const SizedBox.shrink();
                }
                final dt = now.subtract(Duration(days: 13 - idx));
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    '${dt.day}/${dt.month}',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.onSurfaceVariant),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}
