import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../models/food_item.dart';
import '../providers/nutrition_provider.dart';

// Serving unit → grams multiplier
const _unitMultipliers = {'g': 1.0, 'cup': 240.0, 'piece': 100.0};

const _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
const _mealLabels = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

/// Shows the log-food bottom sheet and returns true if a log was saved.
Future<bool> showLogFoodSheet(BuildContext context, FoodItem item) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LogFoodSheet(item: item),
  );
  return result ?? false;
}

class _LogFoodSheet extends ConsumerStatefulWidget {
  const _LogFoodSheet({required this.item});
  final FoodItem item;

  @override
  ConsumerState<_LogFoodSheet> createState() => _LogFoodSheetState();
}

class _LogFoodSheetState extends ConsumerState<_LogFoodSheet> {
  final _qtyController = TextEditingController(text: '100');
  String _unit = 'g';
  String _mealType = 'lunch';
  bool _saving = false;

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  double get _quantity => double.tryParse(_qtyController.text) ?? 0;
  double get _servingG => _quantity * _unitMultipliers[_unit]!;
  double get _factor => _servingG / 100.0;

  double get _calories => widget.item.caloriesPer100g * _factor;
  double get _protein => widget.item.proteinPer100g * _factor;
  double get _carbs => widget.item.carbsPer100g * _factor;
  double get _fat => widget.item.fatPer100g * _factor;

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
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                color: AppColors.onSurfaceVariant,
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
          if (widget.item.brand != null && widget.item.brand!.isNotEmpty)
            Text(widget.item.brand!,
                style: const TextStyle(
                    color: AppColors.onSurfaceVariant, fontSize: 13)),
          const SizedBox(height: 20),

          // Serving row
          Row(
            children: [
              // Quantity input
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
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),

              // Unit picker
              Expanded(
                child: SegmentedButton<String>(
                  segments: _unitMultipliers.keys
                      .map((u) => ButtonSegment(value: u, label: Text(u)))
                      .toList(),
                  selected: {_unit},
                  onSelectionChanged: (s) =>
                      setState(() => _unit = s.first),
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
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
                  : Text(
                      'Log ${_calories.round()} kcal to $_mealType',
                    ),
            ),
          ),
        ],
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
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _MacroCol(label: 'kcal', value: calories.round().toString(),
              color: AppColors.calories),
          _MacroCol(label: 'Protein',
              value: '${protein.toStringAsFixed(1)}g', color: AppColors.protein),
          _MacroCol(label: 'Carbs',
              value: '${carbs.toStringAsFixed(1)}g', color: AppColors.carbs),
          _MacroCol(label: 'Fat',
              value: '${fat.toStringAsFixed(1)}g', color: AppColors.fat),
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
            style: const TextStyle(
                color: AppColors.onSurfaceVariant, fontSize: 11)),
      ],
    );
  }
}
