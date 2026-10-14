import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/food_item.dart';
import '../providers/meal_menu_provider.dart';
import 'food_result_card.dart';

const _menus = [
  ('breakfast', 'Breakfast'),
  ('lunch', 'Lunch'),
  ('dinner', 'Dinner'),
  ('snack', 'Snacks'),
];

/// Tabbed list of routine Indian menus (breakfast / lunch / dinner / snacks)
/// shown on the search screen while the query is empty.
class MealMenuView extends ConsumerStatefulWidget {
  const MealMenuView({super.key, this.initialMeal, required this.onSelect});

  final String? initialMeal;
  final ValueChanged<FoodItem> onSelect;

  @override
  ConsumerState<MealMenuView> createState() => _MealMenuViewState();
}

class _MealMenuViewState extends ConsumerState<MealMenuView> {
  late String _meal = _menus.any((m) => m.$1 == widget.initialMeal)
      ? widget.initialMeal!
      : 'breakfast';

  @override
  Widget build(BuildContext context) {
    final menu = ref.watch(mealMenuProvider(_meal));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Wrap(
            spacing: 8,
            children: [
              for (final m in _menus)
                ChoiceChip(
                  label: Text(m.$2),
                  selected: _meal == m.$1,
                  onSelected: (_) => setState(() => _meal = m.$1),
                ),
            ],
          ),
        ),
        Expanded(
          child: menu.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) =>
                const Center(child: Text('Could not load the menu')),
            data: (items) => ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: items.length,
              itemBuilder: (_, i) => FoodResultCard(
                item: items[i],
                onTap: () => widget.onSelect(items[i]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
