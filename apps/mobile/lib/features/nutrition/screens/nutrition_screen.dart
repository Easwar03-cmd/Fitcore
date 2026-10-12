import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/circle_icon_button.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../core/widgets/pastel_card.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/stat_row.dart';
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
    // Goal-adjusted + workout-adaptive calorie target — null while profile loads.
    final tdee = ref.watch(homeProvider).valueOrNull?.adaptiveTarget;

    return Scaffold(
      appBar: PageAppBar(
        showBack: false,
        title: 'Nutrition',
        actions: [
          CircleIconButton(
            icon: PhosphorIconsRegular.magnifyingGlass,
            semanticLabel: 'Search food',
            onPressed: () => context.push(AppRoutes.foodSearch),
          ),
          const SizedBox(width: 4),
          CircleIconButton(
            icon: PhosphorIconsRegular.barcode,
            semanticLabel: 'Scan barcode',
            onPressed: () => context.push(AppRoutes.barcode),
          ),
        ],
      ),
      body: logsState.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Skeleton(height: 200, radius: 28),
              SizedBox(height: 12),
              Skeleton(height: 110, radius: 24),
            ],
          ),
        ),
        error: (e, _) => EmptyState(
          icon: PhosphorIconsRegular.warningCircle,
          title: e.toString(),
          actionLabel: 'Retry',
          onAction: () => ref.read(foodLogsProvider.notifier).refresh(),
        ),
        data: (dayLogs) => RefreshIndicator(
          onRefresh: () => ref.read(foodLogsProvider.notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _Title(date: DateTime.now()),
              _DaySummary(totals: dayLogs.totals, tdee: tdee),
              const SizedBox(height: 12),
              const _ShortcutRow(),
              const SizedBox(height: 16),
              ..._mealOrder.map((meal) => MealCard(
                    mealType: meal,
                    logs:
                        dayLogs.logs.where((l) => l.mealType == meal).toList(),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text("Today's Nutrition", style: AppTextStyles.title),
          ),
          const SizedBox(height: 4),
          Text(DateFormat('d MMMM, y').format(date),
              style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

/// Calories rows + macro pills (reference "Today's Activity" stat rows).
class _DaySummary extends StatelessWidget {
  const _DaySummary({required this.totals, required this.tdee});
  final DayTotals totals;

  /// Null while the user profile is still loading; hides target when absent.
  final int? tdee;

  @override
  Widget build(BuildContext context) {
    final consumed = totals.calories.round();
    final hasTarget = tdee != null && tdee! > 0;
    final isOver = hasTarget && consumed > tdee!;
    final remaining = hasTarget ? (tdee! - consumed).abs() : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: PastelCard(
        radius: 28,
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatRow(
              tint: PastelTint.lime,
              icon: PhosphorIconsRegular.flame,
              value: hasTarget ? '$consumed / $tdee kcal' : '$consumed kcal',
              label: "Today's calories",
            ),
            StatRow(
              tint: isOver ? PastelTint.salmon : PastelTint.sky,
              icon: isOver
                  ? PhosphorIconsRegular.arrowUp
                  : PhosphorIconsRegular.target,
              value: hasTarget ? '$remaining kcal' : '—',
              label: isOver ? 'Over target' : 'Remaining',
              showDivider: false,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _MacroPill(
                    label: 'Protein',
                    grams: totals.proteinG,
                    tint: PastelTint.sky),
                const SizedBox(width: 8),
                _MacroPill(
                    label: 'Carbs',
                    grams: totals.carbsG,
                    tint: PastelTint.butter),
                const SizedBox(width: 8),
                _MacroPill(
                    label: 'Fat', grams: totals.fatG, tint: PastelTint.salmon),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroPill extends StatelessWidget {
  const _MacroPill(
      {required this.label, required this.grams, required this.tint});
  final String label;
  final double grams;
  final PastelTint tint;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: '$label ${grams.toStringAsFixed(1)} grams',
        child: ExcludeSemantics(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: tint.color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text('${grams.toStringAsFixed(1)} g',
                    style: AppTextStyles.bodyStrong),
                const SizedBox(height: 2),
                Text(label,
                    style:
                        AppTextStyles.caption.copyWith(color: AppColors.ink)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Meal plan + photo logging (replaces the stacked FABs).
class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow();

  @override
  Widget build(BuildContext context) {
    Widget tile(PastelTint tint, IconData icon, String title, String route) =>
        Expanded(
          child: PastelCard(
            tint: tint,
            onTap: () => context.push(route),
            semanticLabel: title,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                  child: Icon(icon, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title,
                      style: AppTextStyles.bodyStrong,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          tile(PastelTint.lime, PhosphorIconsRegular.forkKnife, 'Meal plan',
              AppRoutes.mealPlan),
          const SizedBox(width: 12),
          tile(PastelTint.sky, PhosphorIconsRegular.camera, 'Log by photo',
              AppRoutes.foodPhoto),
        ],
      ),
    );
  }
}
