import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/food_item.dart';

class FoodResultCard extends StatelessWidget {
  const FoodResultCard({super.key, required this.item, this.onTap});

  final FoodItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _FoodImage(imageUrl: item.imageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name.isEmpty ? 'Unknown product' : item.name,
                      style: theme.textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.brand != null && item.brand!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.brand!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    _MacroRow(item: item),
                    const SizedBox(height: 4),
                    const Text(
                      'per 100 g',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Private widgets ──────────────────────────────────────────────────────────

class _FoodImage extends StatelessWidget {
  const _FoodImage({this.imageUrl});
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) return _placeholder();
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        imageUrl!,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : _placeholder(),
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.fastfood_outlined,
          color: AppColors.onSurfaceVariant,
          size: 28,
        ),
      );
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({required this.item});
  final FoodItem item;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        _Badge(label: '${item.caloriesPer100g.round()} kcal', color: AppColors.calories),
        _Badge(label: 'P ${item.proteinPer100g.toStringAsFixed(1)}g', color: AppColors.protein),
        _Badge(label: 'C ${item.carbsPer100g.toStringAsFixed(1)}g', color: AppColors.carbs),
        _Badge(label: 'F ${item.fatPer100g.toStringAsFixed(1)}g', color: AppColors.fat),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
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
