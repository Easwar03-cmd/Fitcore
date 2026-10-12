import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/app_routes.dart';
import '../../../core/widgets/body_figure.dart';
import '../models/exercise.dart';
import '../providers/workout_provider.dart';

/// Muscle picker region → exercise-library group (legs cover quads,
/// hamstrings, glutes and calves).
MuscleGroup muscleGroupFor(MuscleKey k) => switch (k) {
      MuscleKey.chest => MuscleGroup.chest,
      MuscleKey.back => MuscleGroup.back,
      MuscleKey.shoulders => MuscleGroup.shoulders,
      MuscleKey.arms => MuscleGroup.arms,
      MuscleKey.core => MuscleGroup.core,
      MuscleKey.quads ||
      MuscleKey.hamstrings ||
      MuscleKey.glutes ||
      MuscleKey.calves =>
        MuscleGroup.legs,
    };

/// Opens the exercise picker filtered to [key]'s muscle group, then starts a
/// workout session with the chosen exercise.
Future<void> startTrainingForMuscle(
  BuildContext context,
  WidgetRef ref,
  MuscleKey key,
) async {
  final exercise = await context.push<Exercise>(
    AppRoutes.exercisePicker,
    extra: muscleGroupFor(key),
  );
  if (exercise != null && context.mounted) {
    ref.read(workoutSessionProvider.notifier).startWorkout(exercise);
    context.push(AppRoutes.activeWorkout);
  }
}
