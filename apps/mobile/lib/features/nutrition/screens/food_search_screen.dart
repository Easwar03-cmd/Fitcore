import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../models/food_item.dart';
import '../providers/nutrition_provider.dart';
import '../widgets/food_result_card.dart';
import '../widgets/log_food_sheet.dart';

class FoodSearchScreen extends ConsumerStatefulWidget {
  const FoodSearchScreen({super.key});

  @override
  ConsumerState<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends ConsumerState<FoodSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      ref.read(foodSearchProvider.notifier).clear();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(foodSearchProvider.notifier).search(value);
    });
  }

  void _clearSearch() {
    _controller.clear();
    ref.read(foodSearchProvider.notifier).clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(foodSearchProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          style: const TextStyle(color: AppColors.onBackground),
          decoration: InputDecoration(
            hintText: 'Search food…',
            hintStyle:
                const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 16),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _clearSearch,
                  )
                : null,
          ),
          onChanged: (v) {
            _onQueryChanged(v);
            setState(() {}); // refresh clear button visibility
          },
          onSubmitted: (v) {
            _debounce?.cancel();
            ref.read(foodSearchProvider.notifier).search(v);
          },
        ),
      ),
      body: searchState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: e.toString(),
          onRetry: _controller.text.trim().isNotEmpty
              ? () => ref
                  .read(foodSearchProvider.notifier)
                  .search(_controller.text.trim())
              : null,
        ),
        data: (results) {
          if (results.isEmpty && _controller.text.trim().isNotEmpty) {
            return const _EmptyResults();
          }
          if (results.isEmpty) {
            return const _SearchHint();
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: results.length,
            itemBuilder: (_, i) => FoodResultCard(
              item: results[i],
              onTap: () => _onFoodSelected(results[i]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _onFoodSelected(FoodItem item) async {
    final logged = await showLogFoodSheet(context, item);
    if (logged && mounted) {
      Navigator.of(context).pop(); // return to NutritionScreen after logging
    }
  }
}

// ── Static sub-widgets ───────────────────────────────────────────────────────

class _SearchHint extends StatelessWidget {
  const _SearchHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search, size: 64, color: AppColors.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            'Search for food by name',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          const Text(
            '"chicken breast", "oats", "banana"',
            style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 48, color: AppColors.onSurfaceVariant),
          SizedBox(height: 12),
          Text(
            'No results found',
            style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 15),
          ),
          SizedBox(height: 4),
          Text(
            'Try a different search term',
            style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.onSurfaceVariant),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
