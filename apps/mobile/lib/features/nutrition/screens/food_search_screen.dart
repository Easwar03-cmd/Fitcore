import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../core/widgets/skeleton.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/food_item.dart';
import '../providers/nutrition_provider.dart';
import '../widgets/food_result_card.dart';
import '../widgets/log_food_sheet.dart';

class FoodSearchScreen extends ConsumerStatefulWidget {
  const FoodSearchScreen({super.key, this.initialMealType});

  /// When set, pre-selects this meal in the log sheet (e.g. 'breakfast').
  final String? initialMealType;

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
      appBar: const PageAppBar(title: 'Search food'),
      body: Column(
        children: [
          _searchField(),
          Expanded(
            child: searchState.when(
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
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search food…',
          prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(PhosphorIconsRegular.x),
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
    );
  }

  Future<void> _onFoodSelected(FoodItem item) async {
    final logged = await showLogFoodSheet(
      context,
      item,
      initialMealType: widget.initialMealType,
    );
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
    return const EmptyState(
      icon: PhosphorIconsRegular.magnifyingGlass,
      imageName: 'obj_apple.png',
      title: 'Search for food by name',
      message: '"chicken breast", "oats", "banana"',
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: PhosphorIconsRegular.magnifyingGlassMinus,
      title: 'No results found',
      message: 'Try a different search term',
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: PhosphorIconsRegular.warningCircle,
      title: message,
      actionLabel: onRetry == null ? null : 'Retry',
      onAction: onRetry,
    );
  }
}
