import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/app_routes.dart';
import '../../subscription/providers/subscription_provider.dart';
import '../models/exercise.dart';
import '../providers/workout_provider.dart';
import '../providers/workout_recommendation_provider.dart';
import '../widgets/locked_feature_card.dart';
import '../widgets/recommendation_card.dart';

class GymWorkoutScreen extends ConsumerWidget {
  const GymWorkoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recAsync =
        ref.watch(workoutRecommendationProvider(WorkoutType.gym));
    final canUseAiFeatures = ref
            .watch(subscriptionProvider)
            .valueOrNull
            ?.canUseAiWorkoutFeatures ??
        false;

    return Scaffold(
      appBar: AppBar(title: const Text('Gym Workout')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── AI recommendation ──────────────────────────────────────────
            if (!canUseAiFeatures)
              const LockedFeatureCard(featureName: 'AI Workout Recommendations')
            else
              recAsync.when(
                data: (rec) => rec != null
                    ? Column(children: [
                        RecommendationCard(
                          recommendation: rec,
                          onRefresh: () => ref
                              .read(
                                  workoutRecommendationProvider(WorkoutType.gym)
                                      .notifier)
                              .generate(),
                        ),
                        const SizedBox(height: 16),
                      ])
                    : _GenerateButton(
                        label: 'Get AI Gym Recommendation',
                        subtitle:
                            'Personalised gym workout based on your training history',
                        onTap: () => ref
                            .read(
                                workoutRecommendationProvider(WorkoutType.gym)
                                    .notifier)
                            .generate(),
                      ),
                loading: () => const _LoadingCard(
                    label: 'Analysing your gym training history…'),
                error: (_, __) => _GenerateButton(
                  label: 'Retry AI Recommendation',
                  subtitle: 'Could not load — tap to try again',
                  onTap: () => ref
                      .read(workoutRecommendationProvider(WorkoutType.gym)
                          .notifier)
                      .generate(),
                  isError: true,
                ),
              ),

            // ── Browse & start ─────────────────────────────────────────────
            _ActionCard(
              icon: Icons.fitness_center_rounded,
              color: Theme.of(context).colorScheme.primary,
              title: 'Browse Exercises',
              subtitle: 'Pick any exercise and start logging sets',
              onTap: () => _startFromPicker(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startFromPicker(BuildContext context, WidgetRef ref) async {
    final exercise = await context.push<Exercise>(AppRoutes.exercisePicker);
    if (exercise != null && context.mounted) {
      ref.read(workoutSessionProvider.notifier).startWorkout(exercise);
      context.push(AppRoutes.activeWorkout);
    }
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _GenerateButton extends StatelessWidget {
  const _GenerateButton({
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.isError = false,
  });

  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: isError
                      ? theme.colorScheme.errorContainer
                      : theme.colorScheme.primaryContainer,
                  child: Icon(
                    isError
                        ? Icons.refresh_rounded
                        : Icons.auto_awesome_rounded,
                    color: isError
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Text(subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
