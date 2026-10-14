import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/category_row.dart';
import '../../../core/widgets/hero_card.dart';
import '../../../core/widgets/pastel_card.dart';
import '../../../core/widgets/pastel_chip.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/skeleton.dart';
import '../../nutrition/models/food_log.dart';
import '../models/home_state.dart';
import 'ad_placeholders.dart';
import 'calorie_ring.dart';
import 'macro_bars.dart';
import 'step_counter_card.dart';
import 'streak_card.dart';
import 'water_tracker_card.dart';

/// Home layout: hero → quick actions → bento (ring | steps + streak) →
/// macros → water (design.md §6.1).
class HomeDashboard extends StatelessWidget {
  const HomeDashboard({
    super.key,
    required this.home,
    required this.totals,
    required this.onRefresh,
    required this.onAddWater,
  });

  final HomeDashboardState home;
  final DayTotals totals;
  final Future<void> Function() onRefresh;
  final void Function(int ml) onAddWater;

  static const _actions = [
    CategoryItem(icon: PhosphorIconsRegular.forkKnife, label: 'Log food'),
    CategoryItem(icon: PhosphorIconsRegular.barcode, label: 'Scan barcode'),
    CategoryItem(icon: PhosphorIconsRegular.drop, label: 'Add 250 ml water'),
    CategoryItem(icon: PhosphorIconsRegular.barbell, label: 'Workout'),
    CategoryItem(icon: PhosphorIconsRegular.scales, label: 'Log weight'),
  ];

  void _onAction(BuildContext context, int i) {
    switch (i) {
      case 0:
        context.push(AppRoutes.foodSearch);
      case 1:
        context.push(AppRoutes.barcode);
      case 2:
        onAddWater(250);
      case 3:
        context.go(AppRoutes.workout);
      case 4:
        context.push(AppRoutes.bodyLog);
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = home.adaptiveTarget;
    final over = totals.calories > target;
    final remaining = (target - totals.calories).round().clamp(0, target);
    final heroTitle = over
        ? '${(totals.calories - target).round()} kcal over today'
        : '$remaining kcal left today';

    Widget animated(Widget w, int i) => w
        .animate()
        .fadeIn(duration: 320.ms, delay: (40 * i).ms)
        .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: AdBannerPlaceholder(),
          ),
          animated(
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
              child: HeroCard(
                chipLabel: 'Today',
                chipIcon: PhosphorIconsFill.trophy,
                title: heroTitle,
                subtitle: 'Daily target · $target kcal',
                ctaLabel: 'Log food',
                onCta: () => context.push(AppRoutes.foodSearch),
                imageName: 'hero_home_plate.jpg',
                fallbackIcon: PhosphorIconsRegular.bowlFood,
              ),
            ),
            0,
          ),
          const SectionHeader('Quick actions'),
          animated(
            CategoryRow(
              items: _actions,
              selectedIndex: 0,
              onSelected: (i) => _onAction(context, i),
            ),
            1,
          ),
          const SizedBox(height: 16),
          animated(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _CalorieCard(
                        consumed: totals.calories,
                        target: target,
                        burned: home.caloriesBurnedToday,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: StepCounterCard(
                              steps: home.steps,
                              stepGoal: home.stepGoal,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: StreakCard(
                              streak: home.streak,
                              graceUsed: home.graceUsed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            2,
          ),
          const SizedBox(height: 12),
          animated(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PastelCard(
                radius: 28,
                padding: const EdgeInsets.all(18),
                child: MacroBars(
                  totals: totals,
                  tdee: target,
                  goal: home.goal,
                ),
              ),
            ),
            3,
          ),
          const SizedBox(height: 12),
          animated(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: WaterTrackerCard(
                waterMl: home.waterMl,
                waterTargetMl: home.waterTargetMl,
                onAdd: onAddWater,
              ),
            ),
            4,
          ),
        ],
      ),
    );
  }
}

class _CalorieCard extends StatelessWidget {
  const _CalorieCard({
    required this.consumed,
    required this.target,
    required this.burned,
  });

  final double consumed;
  final int target;
  final int burned;

  @override
  Widget build(BuildContext context) {
    return PastelCard(
      tint: PastelTint.lime,
      radius: 28,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      semanticLabel:
          'Calories eaten ${consumed.toInt()} of $target. ${burned > 0 ? 'Plus $burned from workouts.' : ''}',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Calories', style: AppTextStyles.heading),
          const SizedBox(height: 10),
          CalorieRing(
            consumed: consumed,
            target: target,
            size: 132,
            strokeWidth: 12,
            trackColor: Colors.white.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 10),
          if (burned > 0)
            PastelChip(
              label: '+$burned kcal workout',
              icon: PhosphorIconsRegular.flame,
              background: Colors.white,
            )
          else
            Text('Target $target kcal',
                style: AppTextStyles.caption.copyWith(color: AppColors.ink)),
        ],
      ),
    );
  }
}

/// Butter chip-bar shown under the header while writes are queued offline.
class SyncBanner extends StatelessWidget {
  const SyncBanner({
    super.key,
    required this.pendingCount,
    required this.isSyncing,
    required this.onSync,
  });

  final int pendingCount;
  final bool isSyncing;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: PastelCard(
        tint: PastelTint.butter,
        radius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          children: [
            if (isSyncing)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(PhosphorIconsRegular.cloudSlash, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isSyncing
                    ? 'Syncing…'
                    : 'Offline — $pendingCount item${pendingCount == 1 ? '' : 's'} '
                        'waiting to sync',
                style: AppTextStyles.micro.copyWith(fontSize: 12),
              ),
            ),
            if (!isSyncing)
              TextButton(
                onPressed: onSync,
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                ),
                child: const Text('Sync now'),
              ),
          ],
        ),
      ),
    );
  }
}

class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Skeleton(height: 150, radius: 28),
          SizedBox(height: 16),
          Skeleton(height: 60, radius: 30),
          SizedBox(height: 16),
          Skeleton(height: 220, radius: 28),
        ],
      ),
    );
  }
}

class HomeErrorView extends StatelessWidget {
  const HomeErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: PhosphorIconsRegular.wifiSlash,
      title: message.replaceFirst('Exception: ', ''),
      actionLabel: 'Retry',
      onAction: onRetry,
    );
  }
}
