import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/app_routes.dart';
import '../models/exercise.dart';
import '../providers/workout_provider.dart';
import '../providers/deload_check_provider.dart';
import '../providers/workout_recommendation_provider.dart';
import '../widgets/deload_banner_card.dart';
import '../widgets/recommendation_card.dart';

class WorkoutScreen extends ConsumerWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(workoutSessionProvider);
    final recommendationAsync = ref.watch(workoutRecommendationProvider);
    final deloadAsync = ref.watch(deloadCheckProvider);

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Resume active session ─────────────────────────────────────
            if (session.isActive) ...[
              _ResumeCard(onResume: () => context.push(AppRoutes.activeWorkout)),
              const SizedBox(height: 16),
            ],

            // ── Deload banner ─────────────────────────────────────────────
            deloadAsync.when(
              data: (check) => check != null
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: DeloadBannerCard(check: check),
                    )
                  : const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // ── AI recommendation ─────────────────────────────────────────
            recommendationAsync.when(
              data: (rec) => rec != null
                  ? Column(
                      children: [
                        RecommendationCard(
                          recommendation: rec,
                          onRefresh: () => ref
                              .read(workoutRecommendationProvider.notifier)
                              .generate(),
                        ),
                        const SizedBox(height: 16),
                      ],
                    )
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _AiRecommendationButton(
                        onTap: () => ref
                            .read(workoutRecommendationProvider.notifier)
                            .generate(),
                      ),
                    ),
              loading: () => const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: _AiRecommendationLoading(),
              ),
              error: (_, __) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _AiRecommendationButton(
                  onTap: () => ref
                      .read(workoutRecommendationProvider.notifier)
                      .generate(),
                  isError: true,
                ),
              ),
            ),

            // ── Section header ────────────────────────────────────────────
            Text(
              'Start a workout',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // ── Gym workout card ──────────────────────────────────────────
            _WorkoutTypeCard(
              icon: Icons.fitness_center_rounded,
              title: 'Gym Workout',
              subtitle: 'Log sets with weights — barbell, dumbbells, machines.',
              color: Theme.of(context).colorScheme.primary,
              onTap: () => _startGym(context, ref),
            ),
            const SizedBox(height: 12),

            // ── Home / calisthenics card ──────────────────────────────────
            _WorkoutTypeCard(
              icon: Icons.sports_gymnastics_rounded,
              title: 'Home Workout',
              subtitle: 'Bodyweight & calisthenics — no equipment needed.',
              color: const Color(0xFF805AD5),
              onTap: () => context.push(AppRoutes.homeWorkouts),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startGym(BuildContext context, WidgetRef ref) async {
    final exercise = await context.push<Exercise>(AppRoutes.exercisePicker);
    if (exercise != null && context.mounted) {
      ref.read(workoutSessionProvider.notifier).startWorkout(exercise);
      context.push(AppRoutes.activeWorkout);
    }
  }
}

// ── Resume card ───────────────────────────────────────────────────────────────

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.onResume});
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: ListTile(
        leading: const Icon(Icons.play_arrow_rounded),
        title: const Text('Workout in progress',
            style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('Tap to resume'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onResume,
      ),
    );
  }
}

// ── Workout type card ─────────────────────────────────────────────────────────

class _WorkoutTypeCard extends StatelessWidget {
  const _WorkoutTypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
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

// ── AI recommendation button ──────────────────────────────────────────────────

class _AiRecommendationButton extends StatelessWidget {
  const _AiRecommendationButton({required this.onTap, this.isError = false});
  final VoidCallback onTap;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isError ? 'Try again' : 'Get AI Recommendation',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      isError
                          ? 'Could not load. Tap to retry.'
                          : 'Let AI suggest the best workout for today',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiRecommendationLoading extends StatelessWidget {
  const _AiRecommendationLoading();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
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
            Text(
              'Analysing your training history…',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
