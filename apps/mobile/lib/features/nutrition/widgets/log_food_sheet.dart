import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/food_item.dart';
import '../providers/nutrition_provider.dart';
import 'amount_stepper.dart';
import 'macro_preview.dart';

const _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
const _mealLabels = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

/// Smallest amount that can be logged, and the free-amount step.
const double kMinAmount = 10;
const double _step = 10;
const _quickAmounts = [10.0, 50.0, 100.0, 200.0];

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
  late String _mealType = widget.initialMealType ?? 'lunch';
  late final String _unit = widget.item.isLiquid ? 'ml' : 'g';
  bool _saving = false;

  /// Selected household serving (e.g. "1 katori (150g)") and how many of it.
  /// When null the free amount in [_free] (grams / ml) is used.
  ServingOption? _serving;
  int _count = 1;
  double _free = 100;

  List<ServingOption> get _servings => widget.item.commonServings ?? const [];

  @override
  void initState() {
    super.initState();
    if (_servings.isNotEmpty) {
      _serving = _servings.first;
    } else {
      _free = widget.item.isLiquid ? 250 : 100;
    }
  }

  double get _servingG => _serving != null ? _serving!.grams * _count : _free;
  double get _factor => _servingG / 100.0;
  bool get _valid => _serving != null || _free >= kMinAmount;

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  void _pickServing(ServingOption o) => setState(() {
        if (_serving == o) return;
        _serving = o;
        _count = 1;
      });

  void _setFree(double v) => setState(() {
        _serving = null;
        _free = v;
      });

  void _onStep(int dir) {
    if (_serving != null) {
      setState(() => _count = (_count + dir).clamp(1, 20));
    } else {
      _setFree((_free + dir * _step).clamp(kMinAmount, 5000).toDouble());
    }
  }

  void _onTyped(String text) {
    if (_serving != null) {
      final n = int.tryParse(text);
      if (n != null && n >= 1) setState(() => _count = n.clamp(1, 20));
      return;
    }
    _setFree(double.tryParse(text) ?? 0);
  }

  Future<void> _save() async {
    if (!_valid || _servingG <= 0) return;
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
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final item = widget.item;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.9;
    final kcal = (item.caloriesPer100g * _factor).round();

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: muted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(item.name,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              if ((item.nameHindi ?? '').isNotEmpty)
                Text(item.nameHindi!,
                    style: TextStyle(color: muted, fontSize: 13))
              else if ((item.brand ?? '').isNotEmpty)
                Text(item.brand!, style: TextStyle(color: muted, fontSize: 13)),
              const SizedBox(height: 16),
              if (_servings.isNotEmpty) ...[
                Text('Serving', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final o in _servings)
                      ChoiceChip(
                        label:
                            Text(o.label, style: const TextStyle(fontSize: 12)),
                        selected: _serving == o,
                        onSelected: (_) => _pickServing(o),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              Text(
                _serving != null
                    ? 'How many servings · ${_fmt(_servingG)} $_unit'
                    : 'Amount (min ${_fmt(kMinAmount)} $_unit)',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              AmountStepper(
                value: _serving != null ? '$_count' : _fmt(_free),
                unit: _serving != null ? '×' : _unit,
                canDecrease: _serving != null ? _count > 1 : _free > kMinAmount,
                errorText:
                    !_valid ? 'Minimum ${_fmt(kMinAmount)} $_unit' : null,
                onStep: _onStep,
                onChanged: _onTyped,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  for (final a in _quickAmounts)
                    ActionChip(
                      label: Text('${_fmt(a)} $_unit',
                          style: const TextStyle(fontSize: 12)),
                      onPressed: () => _setFree(a),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              MacroPreview(
                calories: item.caloriesPer100g * _factor,
                protein: item.proteinPer100g * _factor,
                carbs: item.carbsPer100g * _factor,
                fat: item.fatPer100g * _factor,
              ),
              const SizedBox(height: 20),
              Text('Meal', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (var i = 0; i < _mealTypes.length; i++)
                    ChoiceChip(
                      label: Text(_mealLabels[i]),
                      selected: _mealType == _mealTypes[i],
                      onSelected: (_) =>
                          setState(() => _mealType = _mealTypes[i]),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving || !_valid ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text('Log $kcal kcal to $_mealType'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
