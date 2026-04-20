import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/app_routes.dart';
import '../models/exercise.dart';
import '../models/home_exercise.dart';
import '../providers/workout_provider.dart';

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
    final theme = Theme.of(context);
    final exercises = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pickMode ? 'Switch Exercise' : 'Home Workouts'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search exercises…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Category filter ──────────────────────────────────────────────
          _CategoryBar(
            selected: _selectedCategory,
            onSelect: (c) =>
                setState(() => _selectedCategory = c == _selectedCategory ? null : c),
          ),

          // ── Difficulty filter ────────────────────────────────────────────
          _DifficultyBar(
            selected: _selectedDifficulty,
            onSelect: (d) =>
                setState(() => _selectedDifficulty = d == _selectedDifficulty ? null : d),
          ),

          // ── Exercise list ────────────────────────────────────────────────
          Expanded(
            child: exercises.isEmpty
                ? Center(
                    child: Text(
                      'No exercises match your filters.',
                      style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: exercises.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
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

// ── Category filter bar ───────────────────────────────────────────────────────

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.selected, required this.onSelect});

  final HomeWorkoutCategory? selected;
  final void Function(HomeWorkoutCategory) onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: HomeWorkoutCategory.values.map((cat) {
          final isSelected = selected == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(cat.label),
              avatar: Icon(cat.icon,
                  size: 16,
                  color: isSelected
                      ? cat.color
                      : theme.colorScheme.onSurfaceVariant),
              selected: isSelected,
              onSelected: (_) => onSelect(cat),
              side: BorderSide.none,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              selectedColor: cat.color.withValues(alpha: 0.18),
              showCheckmark: false,
              labelStyle: TextStyle(
                color: isSelected
                    ? cat.color
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Difficulty filter bar ─────────────────────────────────────────────────────

class _DifficultyBar extends StatelessWidget {
  const _DifficultyBar({required this.selected, required this.onSelect});

  final HomeDifficulty? selected;
  final void Function(HomeDifficulty) onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: HomeDifficulty.values.map((diff) {
          final isSelected = selected == diff;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(diff.label),
              selected: isSelected,
              onSelected: (_) => onSelect(diff),
              side: BorderSide.none,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              selectedColor: diff.color.withValues(alpha: 0.18),
              showCheckmark: false,
              labelStyle: TextStyle(
                color: isSelected
                    ? diff.color
                    : theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
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
    final theme = Theme.of(context);
    final cat = exercise.category;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onStart,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // ── Colour icon ──────────────────────────────────────────────
              CircleAvatar(
                backgroundColor: cat.color.withValues(alpha: 0.12),
                child: Icon(cat.icon, color: cat.color, size: 20),
              ),
              const SizedBox(width: 14),

              // ── Name + description ───────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            exercise.name,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (exercise.timedOnly)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.timer_outlined, size: 14),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      exercise.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _DiffBadge(difficulty: exercise.difficulty),
                        const SizedBox(width: 6),
                        _MuscleChip(label: exercise.muscleGroup.label),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Start arrow ──────────────────────────────────────────────
              Icon(Icons.play_arrow_rounded,
                  color: theme.colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiffBadge extends StatelessWidget {
  const _DiffBadge({required this.difficulty});
  final HomeDifficulty difficulty;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: difficulty.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        difficulty.label,
        style: TextStyle(
          color: difficulty.color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MuscleChip extends StatelessWidget {
  const _MuscleChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
