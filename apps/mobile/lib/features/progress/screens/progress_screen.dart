import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/circle_icon_button.dart';
import '../../../core/widgets/hero_card.dart';
import '../../../core/widgets/muscle_workload_card.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../core/widgets/pastel_card.dart';
import '../../../core/widgets/skeleton.dart';
import '../../workout/widgets/train_muscle.dart';
import '../../workout/models/workout_log.dart';
import '../providers/progress_provider.dart';
import '../widgets/calorie_trend_chart.dart';
import '../widgets/strength_curve_chart.dart';
import '../widgets/weekly_summary_card.dart';
import '../widgets/weight_trend_chart.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(progressProvider);

    return Scaffold(
      appBar: PageAppBar(
        showBack: false,
        title: 'Progress',
        actions: [
          CircleIconButton(
            icon: PhosphorIconsRegular.scales,
            semanticLabel: 'Log weight',
            onPressed: () => context.push(AppRoutes.bodyLog),
          ),
        ],
      ),
      body: progressAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: Column(children: [
            Skeleton(height: 170, radius: 28),
            SizedBox(height: 12),
            Skeleton(height: 220, radius: 28),
          ]),
        ),
        error: (e, _) => EmptyState(
          icon: PhosphorIconsRegular.warningCircle,
          title: e.toString(),
          actionLabel: 'Retry',
          onAction: () => ref.read(progressProvider.notifier).refresh(),
        ),
        data: (progress) => RefreshIndicator(
          onRefresh: () => ref.read(progressProvider.notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              // ── Hero ────────────────────────────────────────────────────────
              HeroCard(
                chipLabel: 'This week',
                chipIcon: PhosphorIconsFill.trophy,
                title: progress.thisWeek.workoutsCompleted == 1
                    ? '1 workout done'
                    : '${progress.thisWeek.workoutsCompleted} workouts done',
                subtitle: progress.thisWeek.avgDailyCalories > 0
                    ? 'Avg ${progress.thisWeek.avgDailyCalories.round()} kcal / day'
                    : 'Keep logging to see trends',
                ctaLabel: 'Log weight',
                onCta: () => context.push(AppRoutes.bodyLog),
                imageName: 'hero_progress.jpg',
                fallbackIcon: PhosphorIconsRegular.chartLineUp,
              ),
              const SizedBox(height: 16),

              // ── Weekly Summary ──────────────────────────────────────────────
              PastelCard(radius: 28, padding: const EdgeInsets.all(18), 
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
              PastelCard(radius: 28, padding: const EdgeInsets.all(18), 
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
              PastelCard(radius: 28, padding: const EdgeInsets.all(18), 
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
                PastelCard(radius: 28, padding: const EdgeInsets.all(18), 
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

              // ── Muscles workload ────────────────────────────────────────────
              MuscleWorkloadCard(
                volume: progress.muscleVolume,
                onTrain: (k) => startTrainingForMuscle(context, ref, k),
              ),
              const SizedBox(height: 16),

              // ── Recent Workouts ─────────────────────────────────────────────
              PastelCard(radius: 28, padding: const EdgeInsets.all(18), 
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: _SectionHeader(
                            title: 'Recent Workouts',
                            subtitle: 'Last 5 sessions',
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              context.push(AppRoutes.workoutHistory),
                          child: const Text('View All'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (progress.recentWorkouts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            'No workouts yet — start your first session!',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                          ),
                        ),
                      )
                    else
                      ...progress.recentWorkouts
                          .map((w) => _RecentWorkoutTile(log: w)),
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

// ── Recent workout tile ───────────────────────────────────────────────────────

class _RecentWorkoutTile extends StatelessWidget {
  const _RecentWorkoutTile({required this.log});

  final WorkoutLog log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final dt = log.startedAt;
    final dateStr = '${dt.day} ${months[dt.month - 1]}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.fitness_center_rounded,
                size: 20, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.name,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                  [
                    dateStr,
                    if (log.durationMin != null) '${log.durationMin}m',
                    '${log.sets.length} sets',
                  ].join('  ·  '),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (log.caloriesBurned != null) ...[
            const Icon(Icons.local_fire_department_outlined,
                size: 14, color: AppColors.warning),
            const SizedBox(width: 2),
            Text(
              '${log.caloriesBurned}',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: AppColors.warning),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

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
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
      ],
    );
  }
}
