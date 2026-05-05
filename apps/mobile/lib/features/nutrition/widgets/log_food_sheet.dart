import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../models/food_item.dart';
import '../providers/nutrition_provider.dart';

// Unit → multiplier maps. For liquids 1 ml ≈ 1 g (beverage density ~1).
const _solidUnits = {'g': 1.0, 'cup': 240.0, 'piece': 100.0};
const _liquidUnits = {'ml': 1.0, 'cup': 240.0};

const _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
const _mealLabels = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

/// Shows the log-food bottom sheet and returns true if a log was saved.
///
/// Pass [initialMealType] to pre-select a meal (e.g. 'breakfast') when
/// navigating from a specific meal card.
Future<bool> showLogFoodSheet(
  BuildContext context,
  FoodItem item, {
  String? initialMealType,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LogFoodSheet(item: item, initialMealType: initialMealType),
  );
  return result ?? false;
}

class _LogFoodSheet extends ConsumerStatefulWidget {
  const _LogFoodSheet({required this.item, this.initialMealType});
  final FoodItem item;
  final String? initialMealType;

  @override
  ConsumerState<_LogFoodSheet> createState() => _LogFoodSheetState();
}

class _LogFoodSheetState extends ConsumerState<_LogFoodSheet> {
  late final TextEditingController _qtyController;
  late String _unit;
  late String _mealType;
  bool _saving = false;

  Map<String, double> get _unitMap =>
      widget.item.isLiquid ? _liquidUnits : _solidUnits;

  @override
  void initState() {
    super.initState();
    _mealType = widget.initialMealType ?? 'lunch';
    // Default to ml for liquids, g for solids
    _unit = widget.item.isLiquid ? 'ml' : 'g';
    _qtyController = TextEditingController(
      text: widget.item.isLiquid ? '250' : '100',
    );
  }

  /// When non-null, a quick-select chip has been tapped and overrides the
  /// text-field + unit calculation.
  double? _chipServingG;

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  double get _quantity => double.tryParse(_qtyController.text) ?? 0;
  double get _servingG => _chipServingG ?? (_quantity * (_unitMap[_unit] ?? 1.0));
  double get _factor => _servingG / 100.0;

  double get _calories => widget.item.caloriesPer100g * _factor;
  double get _protein => widget.item.proteinPer100g * _factor;
  double get _carbs => widget.item.carbsPer100g * _factor;
  double get _fat => widget.item.fatPer100g * _factor;

  List<ServingOption> get _servings => widget.item.commonServings ?? [];

  // Show quick chips for any local food that has commonServings defined
  bool get _hasServings => _servings.isNotEmpty;

  void _selectChip(ServingOption option) {
    setState(() {
      _chipServingG = option.grams;
      _qtyController.text = option.grams.toStringAsFixed(0);
      _unit = widget.item.isLiquid ? 'ml' : 'g';
    });
  }

  void _onManualInput(String _) {
    setState(() => _chipServingG = null);
  }

  Future<void> _save() async {
    if (_servingG <= 0) return;
    setState(() => _saving = true);
    try {
      await ref.read(foodLogsProvider.notifier).logFood(
            item: widget.item,
            servingG: _servingG,
            mealType: _mealType,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.9;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Food name
          Text(
            widget.item.name,
            style: Theme.of(context).textTheme.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (widget.item.nameHindi != null &&
              widget.item.nameHindi!.isNotEmpty)
            Text(
              widget.item.nameHindi!,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13),
            )
          else if (widget.item.brand != null && widget.item.brand!.isNotEmpty)
            Text(
              widget.item.brand!,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13),
            ),
          const SizedBox(height: 16),

          // ── Quick-select serving chips (any local food with commonServings) ──
          if (_hasServings) ...[
            Text('Quick select', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _servings.map((option) {
                final selected = _chipServingG == option.grams;
                return ChoiceChip(
                  label: Text(option.label, style: const TextStyle(fontSize: 12)),
                  selected: selected,
                  onSelected: (_) => _selectChip(option),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Text(
              'Or enter amount',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
          ],

          // ── Serving row (quantity + unit) ─────────────────────────────────
          Row(
            children: [
              SizedBox(
                width: 100,
                child: TextFormField(
                  controller: _qtyController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    isDense: true,
                  ),
                  onChanged: _onManualInput,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SegmentedButton<String>(
                  segments: _unitMap.keys
                      .map((u) => ButtonSegment(
                            value: u,
                            label: Text(
                              u,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ))
                      .toList(),
                  selected: {_unit},
                  onSelectionChanged: (s) => setState(() {
                    _unit = s.first;
                    _chipServingG = null;
                  }),
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Macro preview
          _MacroPreview(
            calories: _calories,
            protein: _protein,
            carbs: _carbs,
            fat: _fat,
          ),
          const SizedBox(height: 20),

          // Meal type
          Text('Meal', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: List.generate(_mealTypes.length, (i) {
              final t = _mealTypes[i];
              final selected = _mealType == t;
              return ChoiceChip(
                label: Text(_mealLabels[i]),
                selected: selected,
                onSelected: (_) => setState(() => _mealType = t),
              );
            }),
          ),
          const SizedBox(height: 24),

          // Log button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving || _servingG <= 0 ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text('Log ${_calories.round()} kcal to $_mealType'),
            ),
          ),
        ],
          ),
        ),
      ),
    );
  }
}

// ── Macro preview row ────────────────────────────────────────────────────────

class _MacroPreview extends StatelessWidget {
  const _MacroPreview({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _MacroCol(
              label: 'kcal',
              value: calories.round().toString(),
              color: AppColors.calories),
          _MacroCol(
              label: 'Protein',
              value: '${protein.toStringAsFixed(1)}g',
              color: AppColors.protein),
          _MacroCol(
              label: 'Carbs',
              value: '${carbs.toStringAsFixed(1)}g',
              color: AppColors.carbs),
          _MacroCol(
              label: 'Fat',
              value: '${fat.toStringAsFixed(1)}g',
              color: AppColors.fat),
        ],
      ),
    );
  }
}

class _MacroCol extends StatelessWidget {
  const _MacroCol(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 11)),
      ],
    );
  }
}
