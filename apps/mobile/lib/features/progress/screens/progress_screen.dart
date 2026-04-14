import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../providers/progress_provider.dart';
import '../widgets/calorie_trend_chart.dart';
import '../widgets/muscle_heatmap.dart';
import '../widgets/strength_curve_chart.dart';
import '../widgets/weekly_summary_card.dart';
import '../widgets/weight_trend_chart.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(progressProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
        actions: [
          IconButton(
            icon: const Icon(Icons.monitor_weight_outlined),
            tooltip: 'Log Weight',
            onPressed: () => context.push(AppRoutes.bodyLog),
          ),
        ],
      ),
      body: progressAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text(
                  e.toString(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () =>
                      ref.read(progressProvider.notifier).refresh(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (progress) => RefreshIndicator(
          onRefresh: () => ref.read(progressProvider.notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Weekly Summary ──────────────────────────────────────────────
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader(
                      title: 'Weekly Summary',
                      subtitle: 'This week vs last week',
                    ),
                    const SizedBox(height: 14),
                    WeeklySummaryCard(
                      thisWeek: progress.thisWeek,
                      lastWeek: progress.lastWeek,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── 30-Day Weight Trend ─────────────────────────────────────────
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader(
                      title: 'Weight Trend',
                      subtitle: 'Last 30 days  ·  dashed line = trend',
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 220,
                      child: WeightTrendChart(stats: progress.bodyStats),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── 7-Day Calorie Trend ─────────────────────────────────────────
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader(
                      title: 'Calorie Trend',
                      subtitle: '7 days  ·  green = under target  ·  red = over',
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: CalorieTrendChart(
                        days: progress.calorieTrend,
                        calorieTarget: progress.calorieTarget,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Strength Curves ─────────────────────────────────────────────
              if (progress.strengthCurves.isNotEmpty) ...[
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeader(
                        title: 'Strength Curves',
                        subtitle: 'Top 3 exercises  ·  max weight per week',
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 240,
                        child: StrengthCurveChart(
                          curves: progress.strengthCurves,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Muscle Volume Heatmap ───────────────────────────────────────
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader(
                      title: 'Muscle Volume',
                      subtitle: 'Sets per group this week',
                    ),
                    const SizedBox(height: 16),
                    MuscleHeatmap(volume: progress.muscleVolume),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.onSurfaceVariant),
          ),
      ],
    );
  }
}
