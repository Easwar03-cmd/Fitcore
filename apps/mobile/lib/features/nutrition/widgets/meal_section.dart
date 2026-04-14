import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../models/food_log.dart';
import '../providers/nutrition_provider.dart';

const _mealEmoji = {
  'breakfast': '🌅',
  'lunch': '☀️',
  'dinner': '🌙',
  'snack': '🍎',
};

class MealSection extends ConsumerWidget {
  const MealSection({
    super.key,
    required this.mealType,
    required this.logs,
  });

  final String mealType;
  final List<FoodLog> logs;

  String get _label =>
      mealType[0].toUpperCase() + mealType.substring(1);

  double get _sectionCalories =>
      logs.fold(0.0, (sum, l) => sum + l.calories);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
          child: Row(
            children: [
              Text('${_mealEmoji[mealType]} $_label',
                  style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              if (logs.isNotEmpty)
                Text(
                  '${_sectionCalories.round()} kcal',
                  style: const TextStyle(
                      color: AppColors.onSurfaceVariant, fontSize: 12),
                ),
            ],
          ),
        ),

        if (logs.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Nothing logged yet',
              style: TextStyle(
                  color: AppColors.onSurfaceVariant, fontSize: 13),
            ),
          )
        else
          ...logs.map((log) => _LogItem(log: log)),

        const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }
}

// ── Individual log item with swipe-to-delete ─────────────────────────────────

class _LogItem extends ConsumerWidget {
  const _LogItem({required this.log});
  final FoodLog log;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(log.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        // Step 1: ask user to confirm.
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Remove entry?'),
            content: Text('Remove "${log.foodName}" from your log?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Remove',
                      style: TextStyle(color: AppColors.error))),
            ],
          ),
        );
        if (confirmed != true) return false;

        // Step 2: call API — only dismiss if it succeeds.
        try {
          await ref.read(foodLogsProvider.notifier).deleteLog(log.id);
          return true;
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.toString())),
            );
          }
          return false;
        }
      },
      // API already called in confirmDismiss; just update local state immediately.
      onDismissed: (_) =>
          ref.read(foodLogsProvider.notifier).removeLogLocally(log.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(log.foodName,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    '${log.servingG.toStringAsFixed(0)} g  ·  '
                    'P ${log.proteinG.toStringAsFixed(1)}  '
                    'C ${log.carbsG.toStringAsFixed(1)}  '
                    'F ${log.fatG.toStringAsFixed(1)}',
                    style: const TextStyle(
                        color: AppColors.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${log.calories.round()} kcal',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
