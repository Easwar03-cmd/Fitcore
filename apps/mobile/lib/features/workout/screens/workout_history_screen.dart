import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/workout_log.dart';
import '../providers/workout_history_provider.dart';

class WorkoutHistoryScreen extends ConsumerWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(workoutHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Workout History')),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: e.toString().replaceAll('Exception: ', ''),
          onRetry: () => ref.read(workoutHistoryProvider.notifier).refresh(),
        ),
        data: (logs) => logs.isEmpty
            ? const _EmptyView()
            : RefreshIndicator(
                onRefresh: () =>
                    ref.read(workoutHistoryProvider.notifier).refresh(),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: logs.length,
                  itemBuilder: (context, i) => _WorkoutCard(log: logs[i])
                      .animate()
                      .fadeIn(delay: Duration(milliseconds: i * 50)),
                ),
              ),
      ),
    );
  }
}

// ── Workout card (expandable) ─────────────────────────────────────────────────

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({required this.log});

  final WorkoutLog log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grouped = log.setsByExercise;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          log.name,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            _formatDate(log.startedAt),
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        trailing: _StatChips(log: log),
        children: grouped.entries
            .map((entry) => _ExerciseGroup(
                  exerciseName: entry.key,
                  sets: entry.value,
                ))
            .toList(),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

class _StatChips extends StatelessWidget {
  const _StatChips({required this.log});

  final WorkoutLog log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dimStyle = theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (log.durationMin != null) ...[
          Icon(Icons.timer_outlined, size: 13,
              color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 2),
          Text('${log.durationMin}m', style: dimStyle),
          const SizedBox(width: 8),
        ],
        Icon(Icons.format_list_numbered, size: 13,
            color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 2),
        Text('${log.sets.length}', style: dimStyle),
        if (log.caloriesBurned != null) ...[
          const SizedBox(width: 8),
          Icon(Icons.local_fire_department_outlined, size: 13,
              color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 2),
          Text('~${log.caloriesBurned}', style: dimStyle),
        ],
      ],
    );
  }
}

class _ExerciseGroup extends StatelessWidget {
  const _ExerciseGroup({required this.exerciseName, required this.sets});

  final String exerciseName;
  final List<ExerciseSetLog> sets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 20),
        Text(
          exerciseName,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 6),
        ...sets.map(
          (s) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: Text(
                    '${s.setNumber}',
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 8),
                Text(s.detail, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Empty / error states ──────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fitness_center_rounded,
              size: 64, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text('No workouts yet',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Finish your first workout to see it here.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
