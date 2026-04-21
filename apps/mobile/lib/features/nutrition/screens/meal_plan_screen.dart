import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../models/meal_plan.dart';
import '../providers/meal_plan_provider.dart';
import '../widgets/planned_meal_card.dart';

class MealPlanScreen extends ConsumerStatefulWidget {
  const MealPlanScreen({super.key});

  @override
  ConsumerState<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends ConsumerState<MealPlanScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final planState = ref.watch(mealPlanProvider);
    final upgradeRequired = ref.watch(mealPlanUpgradeRequiredProvider);
    final isGenerating = planState.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Plan'),
        actions: [
          if (planState.valueOrNull != null)
            IconButton(
              tooltip: 'Regenerate',
              icon: isGenerating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              onPressed: isGenerating
                  ? null
                  : () => ref.read(mealPlanProvider.notifier).generate(),
            ),
        ],
      ),
      body: planState.when(
        loading: () => const _GeneratingView(),
        error: (e, _) => _ErrorView(
          message: e.toString(),
          onRetry: () => ref.read(mealPlanProvider.notifier).generate(),
        ),
        data: (plan) {
          if (upgradeRequired) return const _PaywallView();
          if (plan == null) return _EmptyView(onGenerate: () => ref.read(mealPlanProvider.notifier).generate());
          return _PlanView(plan: plan, tabController: _tabController);
        },
      ),
    );
  }
}

// ── Plan view (7-day tab layout) ─────────────────────────────────────────────

class _PlanView extends StatelessWidget {
  const _PlanView({required this.plan, required this.tabController});

  final WeeklyMealPlan plan;
  final TabController tabController;

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Day tab bar
        TabBar(
          controller: tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
          tabs: _days.map((d) => Tab(text: d)).toList(),
        ),
        Expanded(
          child: TabBarView(
            controller: tabController,
            children: List.generate(7, (i) {
              final day = plan.days[i];
              return _DayTab(day: day);
            }),
          ),
        ),
      ],
    );
  }
}

class _DayTab extends StatelessWidget {
  const _DayTab({required this.day});
  final DayMealPlan day;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 32),
      children: [
        // Day macro summary card
        _DaySummaryCard(day: day),
        const SizedBox(height: 8),
        // Meal cards
        ...List.generate(
          day.meals.length,
          (i) => PlannedMealCard(meal: day.meals[i], index: i),
        ),
      ],
    );
  }
}

class _DaySummaryCard extends StatelessWidget {
  const _DaySummaryCard({required this.day});
  final DayMealPlan day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            day.dayName,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SummaryMacro(
                label: 'Calories',
                value: '${day.totalCalories.round()}',
                unit: 'kcal',
                color: AppColors.calories,
              ),
              _SummaryMacro(
                label: 'Protein',
                value: '${day.totalProteinG.round()}',
                unit: 'g',
                color: AppColors.protein,
              ),
              _SummaryMacro(
                label: 'Carbs',
                value: '${day.totalCarbsG.round()}',
                unit: 'g',
                color: AppColors.carbs,
              ),
              _SummaryMacro(
                label: 'Fat',
                value: '${day.totalFatG.round()}',
                unit: 'g',
                color: AppColors.fat,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMacro extends StatelessWidget {
  const _SummaryMacro({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ── Empty / generating / error / paywall states ───────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onGenerate});
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.restaurant_menu,
                size: 72, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 20),
            Text(
              'Your personalised 7-day meal plan',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Meals matched to your calorie target, macro split, and fitness goal — generated by AI.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onGenerate,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate Meal Plan'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _GeneratingView extends StatelessWidget {
  const _GeneratingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 20),
          Text(
            'Building your meal plan…',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Text(
            'This may take up to 15 seconds',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 20),
            OutlinedButton(onPressed: onRetry, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}

class _PaywallView extends StatelessWidget {
  const _PaywallView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF9C27B0)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.auto_awesome,
                  size: 48, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Text(
              'Pro Feature',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'AI meal plans are available on the Pro and Coach plans.\nUpgrade to unlock personalised weekly menus.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.workspace_premium),
              label: const Text('Upgrade to Pro'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}
