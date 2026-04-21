import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';
import '../models/meal_plan.dart';

class PlannedMealCard extends StatefulWidget {
  const PlannedMealCard({super.key, required this.meal, required this.index});

  final PlannedMeal meal;
  final int index;

  @override
  State<PlannedMealCard> createState() => _PlannedMealCardState();
}

class _PlannedMealCardState extends State<PlannedMealCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ──────────────────────────────────────────────
              Row(
                children: [
                  _MealTypeChip(mealType: widget.meal.mealType),
                  const Spacer(),
                  Text(
                    '${widget.meal.prepTimeMin} min',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.timer_outlined,
                      size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 8),
              // ── Meal name ────────────────────────────────────────────────
              Text(
                widget.meal.name,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              // ── Macro chips ──────────────────────────────────────────────
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _MacroChip(
                    label: '${widget.meal.calories.round()} kcal',
                    color: AppColors.calories,
                  ),
                  _MacroChip(
                    label: '${widget.meal.proteinG.round()}g P',
                    color: AppColors.protein,
                  ),
                  _MacroChip(
                    label: '${widget.meal.carbsG.round()}g C',
                    color: AppColors.carbs,
                  ),
                  _MacroChip(
                    label: '${widget.meal.fatG.round()}g F',
                    color: AppColors.fat,
                  ),
                ],
              ),
              // ── Expandable ingredients ───────────────────────────────────
              if (_expanded) ...[
                const SizedBox(height: 12),
                Divider(color: Theme.of(context).colorScheme.surface),
                const SizedBox(height: 6),
                Text(
                  'Ingredients',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                ...widget.meal.ingredients.map(
                  (ing) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        Expanded(
                          child: Text(
                            ing,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              // ── Expand toggle hint ────────────────────────────────────────
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: 60 * widget.index), duration: 300.ms)
        .slideY(begin: 0.06, end: 0, duration: 300.ms);
  }
}

// ── Meal type chip ────────────────────────────────────────────────────────────

class _MealTypeChip extends StatelessWidget {
  const _MealTypeChip({required this.mealType});
  final String mealType;

  static const _icons = {
    'breakfast': Icons.wb_sunny_outlined,
    'lunch': Icons.light_mode_outlined,
    'dinner': Icons.nightlight_outlined,
    'snack': Icons.apple_outlined,
  };

  static const _colors = {
    'breakfast': Color(0xFFFF8F00),
    'lunch': Color(0xFF43A047),
    'dinner': Color(0xFF5C6BC0),
    'snack': Color(0xFFEF5350),
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[mealType] ?? AppColors.primary;
    final icon = _icons[mealType] ?? Icons.restaurant_outlined;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            mealType[0].toUpperCase() + mealType.substring(1),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Macro chip ────────────────────────────────────────────────────────────────

class _MacroChip extends StatelessWidget {
  const _MacroChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
