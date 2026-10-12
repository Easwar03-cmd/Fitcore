import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/circle_icon_button.dart';
import '../models/food_log.dart';
import '../providers/nutrition_provider.dart';

const _mealIcon = {
  'breakfast': PhosphorIconsRegular.sunHorizon,
  'lunch': PhosphorIconsRegular.sun,
  'dinner': PhosphorIconsRegular.moon,
  'snack': PhosphorIconsRegular.orange,
};

const _mealTint = {
  'breakfast': PastelTint.butter,
  'lunch': PastelTint.sky,
  'dinner': PastelTint.lime,
  'snack': PastelTint.salmon,
};

/// Asks for confirmation, then deletes [log]. Returns true when removed.
Future<bool> confirmAndDeleteLog(
  BuildContext context,
  WidgetRef ref,
  FoodLog log,
) async {
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
              style: TextStyle(color: AppColors.coralText)),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  try {
    await ref.read(foodLogsProvider.notifier).deleteLog(log.id);
    ref.read(foodLogsProvider.notifier).removeLogLocally(log.id);
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
    return false;
  }
}

/// Tinted meal card.
///
/// - Empty: placeholder text; the whole card opens food search.
/// - With food: horizontal chip row + "See all" toggle for the full list.
/// - The + circle always opens food search with [mealType] pre-selected.
class MealCard extends ConsumerStatefulWidget {
  const MealCard({super.key, required this.mealType, required this.logs});

  final String mealType;
  final List<FoodLog> logs;

  @override
  ConsumerState<MealCard> createState() => _MealCardState();
}

class _MealCardState extends ConsumerState<MealCard> {
  bool _expanded = false;

  String get _label =>
      widget.mealType[0].toUpperCase() + widget.mealType.substring(1);

  int get _totalKcal =>
      widget.logs.fold(0.0, (sum, l) => sum + l.calories).round();

  void _add() => context.push(AppRoutes.foodSearch, extra: widget.mealType);

  @override
  Widget build(BuildContext context) {
    final hasLogs = widget.logs.isNotEmpty;
    final tint = _mealTint[widget.mealType] ?? PastelTint.grey;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Material(
        color: tint.color,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: hasLogs ? null : _add,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                      child: Icon(
                          _mealIcon[widget.mealType] ??
                              PhosphorIconsRegular.forkKnife,
                          size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_label, style: AppTextStyles.heading),
                          Text(
                            hasLogs
                                ? '$_totalKcal kcal · ${widget.logs.length} item${widget.logs.length == 1 ? '' : 's'}'
                                : 'Tap + to add ${widget.mealType}',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.ink),
                          ),
                        ],
                      ),
                    ),
                    CircleIconButton(
                      icon: PhosphorIconsBold.plus,
                      iconSize: 18,
                      size: 40,
                      semanticLabel: 'Add ${widget.mealType}',
                      onPressed: _add,
                    ),
                  ],
                ),
                if (hasLogs) ...[
                  const SizedBox(height: 12),
                  if (!_expanded)
                    _FoodChipRow(logs: widget.logs)
                        .animate(key: ValueKey(widget.logs.length))
                        .fadeIn(duration: 250.ms)
                  else
                    for (int i = 0; i < widget.logs.length; i++)
                      _LogItem(log: widget.logs[i])
                          .animate(delay: (i * 40).ms)
                          .fadeIn(duration: 180.ms),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setState(() => _expanded = !_expanded),
                      child: Text(_expanded
                          ? 'Collapse'
                          : 'See all (${widget.logs.length})'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FoodChipRow extends StatelessWidget {
  const _FoodChipRow({required this.logs});
  final List<FoodLog> logs;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(log.foodName,
                style: AppTextStyles.micro.copyWith(fontSize: 12),
                overflow: TextOverflow.ellipsis,
                maxLines: 1),
          ),
          const SizedBox(width: 6),
          Text('${log.calories.round()} kcal',
              style: AppTextStyles.micro.copyWith(color: AppColors.inkMuted)),
          IconButton(
            tooltip: 'Remove ${log.foodName}',
            onPressed: () => confirmAndDeleteLog(context, ref, log),
            icon: const Icon(PhosphorIconsRegular.x, size: 14),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// Full row with swipe-to-delete (expanded card).
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
        color: AppColors.coral,
        child: const Icon(PhosphorIconsRegular.trash, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        // The helper removes the row itself, so never let Dismissible do it.
        await confirmAndDeleteLog(context, ref, log);
        return false;
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(log.foodName,
                      style: AppTextStyles.bodyStrong,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    '${log.servingG.toStringAsFixed(0)} g  ·  '
                    'P ${log.proteinG.toStringAsFixed(1)}  '
                    'C ${log.carbsG.toStringAsFixed(1)}  '
                    'F ${log.fatG.toStringAsFixed(1)}',
                    style: AppTextStyles.caption.copyWith(color: AppColors.ink),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('${log.calories.round()} kcal',
                style: AppTextStyles.bodyStrong.copyWith(fontSize: 13)),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(PhosphorIconsRegular.trash, size: 18),
              onPressed: () => confirmAndDeleteLog(context, ref, log),
            ),
          ],
        ),
      ),
    );
  }
}
