import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/app_routes.dart';
import '../../../core/api/api_response.dart';
import '../../subscription/providers/subscription_provider.dart';
import '../models/exercise.dart';
import '../models/home_exercise.dart';
import '../providers/workout_provider.dart';
import '../providers/workout_recommendation_provider.dart';
import '../widgets/locked_feature_card.dart';
import '../widgets/recommendation_card.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../core/widgets/pastel_card.dart';
import '../../../core/widgets/skeleton.dart';

class HomeWorkoutListScreen extends ConsumerStatefulWidget {
  const HomeWorkoutListScreen({super.key, this.pickMode = false});

  /// When true, tapping an exercise pops back with the [Exercise] instead of
  /// starting a new workout session (used by the "Switch" button in
  /// ActiveWorkoutScreen).
  final bool pickMode;

  @override
  ConsumerState<HomeWorkoutListScreen> createState() =>
      _HomeWorkoutListScreenState();
}

class _HomeWorkoutListScreenState
    extends ConsumerState<HomeWorkoutListScreen> {
  HomeWorkoutCategory? _selectedCategory;
  HomeDifficulty? _selectedDifficulty;
  String _search = '';

  List<HomeExercise> get _filtered {
    return kHomeExerciseLibrary.where((e) {
      if (_selectedCategory != null && e.category != _selectedCategory) {
        return false;
      }
      if (_selectedDifficulty != null && e.difficulty != _selectedDifficulty) {
        return false;
      }
      if (_search.isNotEmpty &&
          !e.name.toLowerCase().contains(_search.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
  }

  void _start(HomeExercise exercise) {
    if (widget.pickMode) {
      // Return the exercise to the caller (Switch button in ActiveWorkoutScreen).
      context.pop(exercise.toExercise());
    } else {
      ref
          .read(workoutSessionProvider.notifier)
          .startWorkout(exercise.toExercise());
      context.push(AppRoutes.activeWorkout);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercises = _filtered;

    return Scaffold(
      appBar: PageAppBar(
        title: widget.pickMode ? 'Switch Exercise' : 'Home Workouts',
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: const InputDecoration(
                hintText: 'Search exercises…',
                prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass),
              ),
            ),
          ),

          // ── AI home recommendation ───────────────────────────────────────
          if (!widget.pickMode) const _HomeRecommendationSection(),

          // ── Category filter ──────────────────────────────────────────────
          _CategoryBar(
            selected: _selectedCategory,
            onSelect: (c) => setState(
                () => _selectedCategory = c == _selectedCategory ? null : c),
          ),

          // ── Difficulty filter ────────────────────────────────────────────
          _DifficultyBar(
            selected: _selectedDifficulty,
            onSelect: (d) => setState(() =>
                _selectedDifficulty = d == _selectedDifficulty ? null : d),
          ),

          // ── Exercise list ────────────────────────────────────────────────
          Expanded(
            child: exercises.isEmpty
                ? const EmptyState(
                    icon: PhosphorIconsRegular.magnifyingGlass,
                    title: 'No exercises match your filters.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: exercises.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _ExerciseCard(
                      exercise: exercises[i],
                      onStart: () => _start(exercises[i]),
                    )
                        .animate()
                        .fadeIn(duration: 200.ms, delay: (i * 30).ms)
                        .slideY(begin: 0.1, end: 0, duration: 200.ms),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Filter pills ──────────────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.ink;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppColors.ink : AppColors.surface,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: fg),
                    const SizedBox(width: 6),
                  ],
                  Text(label,
                      style: AppTextStyles.micro
                          .copyWith(fontSize: 13, color: fg)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.selected, required this.onSelect});

  final HomeWorkoutCategory? selected;
  final void Function(HomeWorkoutCategory) onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: HomeWorkoutCategory.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = HomeWorkoutCategory.values[i];
          return _Pill(
            label: cat.label,
            icon: cat.icon,
            selected: selected == cat,
            onTap: () => onSelect(cat),
          );
        },
      ),
    );
  }
}

class _DifficultyBar extends StatelessWidget {
  const _DifficultyBar({required this.selected, required this.onSelect});

  final HomeDifficulty? selected;
  final void Function(HomeDifficulty) onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: HomeDifficulty.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final diff = HomeDifficulty.values[i];
          return _Pill(
            label: diff.label,
            selected: selected == diff,
            onTap: () => onSelect(diff),
          );
        },
      ),
    );
  }
}

// ── Exercise card ─────────────────────────────────────────────────────────────

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.exercise, required this.onStart});

  final HomeExercise exercise;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final cat = exercise.category;

    return PastelCard(
      onTap: onStart,
      radius: 24,
      padding: const EdgeInsets.all(14),
      semanticLabel:
          '${exercise.name}, ${exercise.difficulty.label}, ${exercise.muscleGroup.label}',
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: cat.color,
              shape: BoxShape.circle,
            ),
            child: Icon(cat.icon, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(exercise.name, style: AppTextStyles.heading),
                    ),
                    if (exercise.timedOnly)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(PhosphorIconsRegular.timer, size: 16),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  exercise.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _Tag(
                        label: exercise.difficulty.label,
                        color: exercise.difficulty.color),
                    const SizedBox(width: 6),
                    _Tag(
                        label: exercise.muscleGroup.label,
                        color: AppColors.surfaceMuted),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
                color: AppColors.ink, shape: BoxShape.circle),
            child: const Icon(PhosphorIconsFill.play,
                size: 16, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: AppTextStyles.micro),
    );
  }
}

// ── AI home recommendation section ────────────────────────────────────────────

class _HomeRecommendationSection extends ConsumerWidget {
  const _HomeRecommendationSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canUseAiFeatures = ref
            .watch(subscriptionProvider)
            .valueOrNull
            ?.canUseAiWorkoutFeatures ??
        false;

    if (!canUseAiFeatures) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: LockedFeatureCard(featureName: 'AI Workout Recommendations'),
      );
    }

    final recAsync =
        ref.watch(workoutRecommendationProvider(WorkoutType.home));
    void generate() => ref
        .read(workoutRecommendationProvider(WorkoutType.home).notifier)
        .generate();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: recAsync.when(
        data: (rec) => rec != null
            ? RecommendationCard(recommendation: rec, onRefresh: generate)
            : _GenerateTile(onTap: generate),
        loading: () => const PastelCard(
          tint: PastelTint.sky,
          radius: 24,
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Text('Generating home workout recommendation…'),
              ),
            ],
          ),
        ),
        error: (e, __) =>
            _GenerateTile(errorMessage: apiErrorMessage(e), onTap: generate),
      ),
    );
  }
}

class _GenerateTile extends StatelessWidget {
  const _GenerateTile({required this.onTap, this.errorMessage});
  final VoidCallback onTap;
  final String? errorMessage;
  bool get isError => errorMessage != null;

  @override
  Widget build(BuildContext context) {
    final text = isError
        ? '${errorMessage!} Tap to retry.'
        : 'Get AI Home Workout Recommendation';
    return PastelCard(
      tint: isError ? PastelTint.salmon : PastelTint.sky,
      radius: 24,
      onTap: onTap,
      semanticLabel: text,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
            child: Icon(
              isError
                  ? PhosphorIconsRegular.arrowClockwise
                  : PhosphorIconsRegular.sparkle,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: AppTextStyles.bodyStrong)),
          const Icon(PhosphorIconsRegular.caretRight, size: 18),
        ],
      ),
    );
  }
}
