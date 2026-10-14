import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class CategoryItem {
  const CategoryItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// Horizontally scrolling row of 56 px circles; the selected one is salmon
/// (reference "Select exercise type"). Labels are exposed to screen readers
/// and as tooltips because the visual design is icon-only.
class CategoryRow extends StatelessWidget {
  const CategoryRow({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final List<CategoryItem> items;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final item = items[i];
          final selected = i == selectedIndex;
          return Semantics(
            button: true,
            selected: selected,
            label: item.label,
            child: Tooltip(
              message: item.label,
              child: GestureDetector(
                onTap: () => onSelected(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.salmon : AppColors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item.icon, size: 24, color: AppColors.ink),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
