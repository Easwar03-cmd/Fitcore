import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/food_photo_provider.dart';
import '../providers/nutrition_provider.dart';
import '../widgets/detected_food_card.dart';

const _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];

class FoodPhotoScreen extends ConsumerStatefulWidget {
  const FoodPhotoScreen({super.key});

  @override
  ConsumerState<FoodPhotoScreen> createState() => _FoodPhotoScreenState();
}

class _FoodPhotoScreenState extends ConsumerState<FoodPhotoScreen> {
  @override
  void initState() {
    super.initState();
    // Reset any previous session on open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(foodPhotoProvider.notifier).reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(foodPhotoProvider);

    // When logging completes, refresh nutrition and pop.
    ref.listen(foodPhotoProvider, (prev, next) {
      if (next.loggedCount > 0 && (prev?.loggedCount ?? 0) == 0) {
        ref.read(foodLogsProvider.notifier).refresh();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${next.loggedCount} item${next.loggedCount == 1 ? '' : 's'} logged successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Food by Photo'),
        actions: [
          if (state.hasImage && !state.isAnalyzing)
            TextButton.icon(
              onPressed: () =>
                  ref.read(foodPhotoProvider.notifier).reset(),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retake'),
            ),
        ],
      ),
      body: state.isAnalyzing
          ? _AnalyzingView(imagePath: state.imagePath)
          : state.hasResults
              ? _ResultsView(state: state)
              : _PickerView(state: state),
      bottomNavigationBar: state.hasResults && !state.isLogging
          ? _LogBar(state: state)
          : state.isLogging
              ? const _LoggingBar()
              : null,
    );
  }
}

// ── Picker view (no image yet) ────────────────────────────────────────────────

class _PickerView extends ConsumerWidget {
  const _PickerView({required this.state});
  final FoodPhotoState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(foodPhotoProvider.notifier);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt_outlined,
                  size: 56, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            Text(
              'Snap your meal',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'AI will detect every food item on your plate or bowl — including mixed dishes, sauces, and sides.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            if (state.error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  state.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 36),
            FilledButton.icon(
              onPressed: () =>
                  notifier.pickAndAnalyze(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Take Photo'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(220, 50),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () =>
                  notifier.pickAndAnalyze(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose from Gallery'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(220, 50),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('Works best with',
                      style: TextStyle(
                          fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
                Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 12),
            const Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                _Hint('Full plates & bowls'),
                _Hint('Indian thali / biryani'),
                _Hint('Mixed dishes'),
                _Hint('Multiple items'),
                _Hint('Packaged food'),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }
}

// ── Analyzing view ────────────────────────────────────────────────────────────

class _AnalyzingView extends StatelessWidget {
  const _AnalyzingView({this.imagePath});
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (imagePath != null)
          Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(File(imagePath!), fit: BoxFit.cover),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.85),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          flex: 2,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 20),
                Text(
                  'Analysing your meal…',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  'Detecting all food items, estimating portions\nand calculating nutritional values',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Results view ──────────────────────────────────────────────────────────────

class _ResultsView extends ConsumerWidget {
  const _ResultsView({required this.state});
  final FoodPhotoState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(foodPhotoProvider.notifier);
    final theme = Theme.of(context);

    return CustomScrollView(
      slivers: [
        // Thumbnail + summary header
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.imagePath != null)
                SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(File(state.imagePath!), fit: BoxFit.cover),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        left: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${state.detectedFoods.length} items detected',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18),
                            ),
                            Text(
                              '${state.totalSelectedCalories.round()} kcal selected',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              // Notes from AI
              if (state.notes != null && state.notes!.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    state.notes!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              // Meal type selector
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _MealTypeSelector(
                  selected: state.selectedMealType,
                  onChanged: notifier.setMealType,
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Text('Detected foods',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text(
                      '${state.selectedCount} of ${state.detectedFoods.length} selected',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Food cards
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) => DetectedFoodCard(
              item: state.detectedFoods[i],
              index: i,
              onToggle: () => notifier.toggleItem(i),
              onServingChanged: (v) => notifier.updateServing(i, v),
              onRemove: () => notifier.removeItem(i),
            ),
            childCount: state.detectedFoods.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }
}

// ── Meal type selector ────────────────────────────────────────────────────────

class _MealTypeSelector extends StatelessWidget {
  const _MealTypeSelector({required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;

  static const _icons = {
    'breakfast': Icons.wb_sunny_outlined,
    'lunch': Icons.light_mode_outlined,
    'dinner': Icons.nightlight_outlined,
    'snack': Icons.apple_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _mealTypes.map((type) {
        final isSelected = type == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.2)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _icons[type] ?? Icons.restaurant,
                    size: 18,
                    color: isSelected
                        ? AppColors.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    type[0].toUpperCase() + type.substring(1),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Bottom bars ───────────────────────────────────────────────────────────────

class _LogBar extends ConsumerWidget {
  const _LogBar({required this.state});
  final FoodPhotoState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noneSelected = state.selectedCount == 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      child: FilledButton.icon(
        onPressed: noneSelected
            ? null
            : () => ref.read(foodPhotoProvider.notifier).logSelected(),
        icon: const Icon(Icons.check_circle_outline),
        label: Text(
          noneSelected
              ? 'Select items to log'
              : 'Log ${state.selectedCount} item${state.selectedCount == 1 ? '' : 's'} · ${state.totalSelectedCalories.round()} kcal',
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          minimumSize: const Size(double.infinity, 50),
        ),
      ),
    );
  }
}

class _LoggingBar extends StatelessWidget {
  const _LoggingBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary)),
          SizedBox(width: 12),
          Text('Saving to food log…'),
        ],
      ),
    );
  }
}
