import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../home/providers/home_provider.dart';
import '../models/food_log.dart';
import '../providers/nutrition_provider.dart';
import '../widgets/meal_section.dart' show MealCard;

const _mealOrder = ['breakfast', 'lunch', 'dinner', 'snack'];

class NutritionScreen extends ConsumerWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsState = ref.watch(foodLogsProvider);
    // Watch TDEE from the home dashboard — null while profile is still loading.
    final tdee = ref.watch(homeProvider).valueOrNull?.tdee;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrition'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push(AppRoutes.foodSearch),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => context.push(AppRoutes.barcode),
          ),
        ],
      ),
      body: logsState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: e.toString(),
          onRetry: () => ref.read(foodLogsProvider.notifier).refresh(),
        ),
        data: (dayLogs) => RefreshIndicator(
          onRefresh: () => ref.read(foodLogsProvider.notifier).refresh(),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _DaySummary(totals: dayLogs.totals, tdee: tdee),
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  ..._mealOrder.map((meal) => MealCard(
                        mealType: meal,
                        logs: dayLogs.logs
                            .where((l) => l.mealType == meal)
                            .toList(),
                      )),
                  const SizedBox(height: 24),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Day summary card ─────────────────────────────────────────────────────────

class _DaySummary extends StatelessWidget {
  const _DaySummary({required this.totals, required this.tdee});
  final DayTotals totals;
  /// Null while the user profile is still loading; hides target when absent.
  final int? tdee;

  @override
  Widget build(BuildContext context) {
    final consumed = totals.calories.round();
    final hasTarget = tdee != null && tdee! > 0;
    final remaining = hasTarget ? (tdee! - consumed) : 0;
    final isOver = hasTarget && consumed > tdee!;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "Today's calories",
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    hasTarget
                        ? '$consumed / ${tdee!} kcal'
                        : '$consumed kcal',
                    style: const TextStyle(
                      color: AppColors.calories,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                  if (hasTarget)
                    Text(
                      isOver
                          ? '${(consumed - tdee!)} kcal over'
                          : '$remaining kcal remaining',
                      style: TextStyle(
                        color: isOver
                            ? AppColors.error
                            : AppColors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MacroTile(
                  label: 'Protein',
                  value: totals.proteinG,
                  color: AppColors.protein),
              _MacroTile(
                  label: 'Carbs',
                  value: totals.carbsG,
                  color: AppColors.carbs),
              _MacroTile(
                  label: 'Fat', value: totals.fatG, color: AppColors.fat),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroTile extends StatelessWidget {
  const _MacroTile(
      {required this.label, required this.value, required this.color});
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${value.toStringAsFixed(1)}g',
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                color: AppColors.onSurfaceVariant, fontSize: 12)),
      ],
    );
  }
}

// ── Error view ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
