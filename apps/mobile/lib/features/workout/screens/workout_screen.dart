import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/app_routes.dart';
import '../models/exercise.dart';
import '../providers/workout_provider.dart';

class WorkoutScreen extends ConsumerWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(workoutSessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => context.push(AppRoutes.workoutHistory),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.fitness_center_rounded,
                  size: 72,
                  color: Theme.of(context).colorScheme.outlineVariant),
              const SizedBox(height: 20),
              Text(
                'Ready to train?',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Pick an exercise and start logging sets.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 36),
              if (session.isActive) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        context.push(AppRoutes.activeWorkout),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Resume Workout'),
                    style: ElevatedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _startNew(context, ref),
                    child: const Text('Start New Workout'),
                  ),
                ),
              ] else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _startNew(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Start Workout'),
                    style: ElevatedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startNew(BuildContext context, WidgetRef ref) async {
    final exercise =
        await context.push<Exercise>(AppRoutes.exercisePicker);
    if (exercise != null && context.mounted) {
      ref.read(workoutSessionProvider.notifier).startWorkout(exercise);
      context.push(AppRoutes.activeWorkout);
    }
  }
}
