import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/pastel_card.dart';
import '../models/progress_data.dart';

/// Horizontally scrolling coloured metric cards (reference: "Heart Rate
/// Range" / "Resting Heart Rate Alert"): this week vs last week.
class WeeklyMetricStrip extends StatelessWidget {
  const WeeklyMetricStrip({
    super.key,
    required this.thisWeek,
    required this.lastWeek,
  });

  final WeeklySummary thisWeek;
  final WeeklySummary lastWeek;

  String _delta(num now, num before, {String unit = ''}) {
    final d = now - before;
    if (before == 0 && now == 0) return 'No change';
    final sign = d > 0 ? '+' : '';
    return '$sign${d.round()}$unit vs last week';
  }

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      _MetricTile(
        tint: PastelTint.sky,
        title: 'Workouts',
        value: '${thisWeek.workoutsCompleted}',
        unit: 'this week',
        footnote: _delta(thisWeek.workoutsCompleted, lastWeek.workoutsCompleted),
        up: thisWeek.workoutsCompleted >= lastWeek.workoutsCompleted,
      ),
      _MetricTile(
        tint: PastelTint.white,
        title: 'Avg calories',
        value: thisWeek.avgDailyCalories.round().toString(),
        unit: 'kcal / day',
        footnote: _delta(thisWeek.avgDailyCalories, lastWeek.avgDailyCalories),
        up: thisWeek.avgDailyCalories >= lastWeek.avgDailyCalories,
      ),
      _MetricTile(
        tint: PastelTint.salmon,
        title: 'Volume',
        value: thisWeek.totalVolumeKg.round().toString(),
        unit: 'kg lifted',
        footnote: _delta(thisWeek.totalVolumeKg, lastWeek.totalVolumeKg, unit: ' kg'),
        up: thisWeek.totalVolumeKg >= lastWeek.totalVolumeKg,
      ),
    ];

    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tiles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => tiles[i],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.tint,
    required this.title,
    required this.value,
    required this.unit,
    required this.footnote,
    required this.up,
  });

  final PastelTint tint;
  final String title;
  final String value;
  final String unit;
  final String footnote;
  final bool up;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 156,
      child: PastelCard(
        tint: tint,
        radius: 24,
        padding: const EdgeInsets.all(14),
        semanticLabel: '$title $value $unit, $footnote',
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.heading),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(value, style: AppTextStyles.metricL),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(unit, style: AppTextStyles.micro),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    up ? PhosphorIconsBold.caretUp : PhosphorIconsBold.caretDown,
                    size: 11,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(footnote,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.micro
                            .copyWith(color: AppColors.ink, fontSize: 11)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
