import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../models/food_log.dart';
import '../providers/nutrition_provider.dart';

const _mealEmoji = {
  'breakfast': '🌅',
  'lunch': '☀️',
  'dinner': '🌙',
  'snack': '🍎',
};

/// Card-based meal section.
///
/// - Empty: shows placeholder text; entire card navigates to FoodSearchScreen.
/// - With food: compact horizontal chip row + "See all" toggle for full list.
/// - Tapping + always navigates to FoodSearchScreen with [mealType] pre-selected.
class MealCard extends ConsumerStatefulWidget {
  const MealCard({
    super.key,
    required this.mealType,
    required this.logs,
  });

  final String mealType;
  final List<FoodLog> logs;

  @override
  ConsumerState<MealCard> createState() => _MealCardState();
}

class _MealCardState extends ConsumerState<MealCard> {
  bool _expanded = false;

  String get _label =>
      widget.mealType[0].toUpperCase() + widget.mealType.substring(1);

  double get _totalKcal =>
      widget.logs.fold(0.0, (sum, l) => sum + l.calories);

  void _navigateToSearch() =>
      context.push(AppRoutes.foodSearch, extra: widget.mealType);

  @override
  Widget build(BuildContext context) {
    final hasLogs = widget.logs.isNotEmpty;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: hasLogs ? null : _navigateToSearch,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MealHeader(
                label: _label,
                mealType: widget.mealType,
                totalKcal: hasLogs ? _totalKcal.round() : null,
                onAdd: _navigateToSearch,
              ),
              if (!hasLogs)
                _EmptyPlaceholder(mealType: widget.mealType)
              else
                _LoggedBody(
                  logs: widget.logs,
                  expanded: _expanded,
                  onToggle: () => setState(() => _expanded = !_expanded),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header row ────────────────────────────────────────────────────────────────

class _MealHeader extends StatelessWidget {
  const _MealHeader({
    required this.label,
    required this.mealType,
    required this.totalKcal,
    required this.onAdd,
  });

  final String label;
  final String mealType;
  final int? totalKcal;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 4, 8),
      child: Row(
        children: [
          Text(
            '${_mealEmoji[mealType]} $label',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const Spacer(),
          if (totalKcal != null) ...[
            Text(
              '$totalKcal kcal',
              style: const TextStyle(
                color: AppColors.calories,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
          ],
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: onAdd,
            iconSize: 22,
            visualDensity: VisualDensity.compact,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyPlaceholder extends StatelessWidget {
  const _EmptyPlaceholder({required this.mealType});
  final String mealType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Text(
        'Tap + to add $mealType',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
      ),
    );
  }
}

// ── Body when foods are logged ────────────────────────────────────────────────

class _LoggedBody extends StatelessWidget {
  const _LoggedBody({
    required this.logs,
    required this.expanded,
    required this.onToggle,
  });

  final List<FoodLog> logs;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!expanded) ...[
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 4),
            child: _FoodChipRow(logs: logs)
                .animate(key: ValueKey(logs.length))
                .fadeIn(duration: 250.ms)
                .slideX(begin: -0.05, end: 0),
          ),
          _ToggleLink(label: 'See all (${logs.length})', onTap: onToggle),
        ] else ...[
          for (int i = 0; i < logs.length; i++)
            _LogItem(log: logs[i])
                .animate(delay: (i * 40).ms)
                .fadeIn(duration: 180.ms)
                .slideY(begin: 0.06, end: 0),
          _ToggleLink(label: 'Collapse', onTap: onToggle),
        ],
      ],
    );
  }
}

class _ToggleLink extends StatelessWidget {
  const _ToggleLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 12, 12),
      child: Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onTap: onTap,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.primary,
                ),
          ),
        ),
      ),
    );
  }
}

// ── Horizontal chip row ───────────────────────────────────────────────────────

class _FoodChipRow extends StatelessWidget {
  const _FoodChipRow({required this.logs});
  final List<FoodLog> logs;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 12),
        itemCount: logs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => _FoodChip(log: logs[i]),
      ),
    );
  }
}

class _FoodChip extends ConsumerWidget {
  const _FoodChip({required this.log});
  final FoodLog log;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
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
    if (confirmed != true) return;
    try {
      await ref.read(foodLogsProvider.notifier).deleteLog(log.id);
      ref.read(foodLogsProvider.notifier).removeLogLocally(log.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 4, top: 5, bottom: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 100),
            child: Text(
              log.foodName,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${log.calories.round()} kcal',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.calories,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 2),
          GestureDetector(
            onTap: () => _delete(context, ref),
            child: Icon(
              Icons.close,
              size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Full log item with swipe-to-delete ────────────────────────────────────────

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
        try {
          await ref.read(foodLogsProvider.notifier).deleteLog(log.id);
          return true;
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(e.toString())));
          }
          return false;
        }
      },
      onDismissed: (_) =>
          ref.read(foodLogsProvider.notifier).removeLogLocally(log.id),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
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
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${log.calories.round()} kcal',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              visualDensity: VisualDensity.compact,
              tooltip: 'Delete',
              onPressed: () async {
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
                if (confirmed != true) return;
                try {
                  await ref.read(foodLogsProvider.notifier).deleteLog(log.id);
                  ref.read(foodLogsProvider.notifier).removeLogLocally(log.id);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
