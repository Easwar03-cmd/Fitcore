import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../core/widgets/pastel_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/app_routes.dart';
import '../../../core/api/api_response.dart';
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
      appBar: const PageAppBar(title: 'Gym Workout'),
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
                error: (e, __) => _GenerateButton(
                  label: 'Retry AI Recommendation',
                  subtitle: '${apiErrorMessage(e)} Tap to try again.',
                  onTap: () => ref
                      .read(workoutRecommendationProvider(WorkoutType.gym)
                          .notifier)
                      .generate(),
                  isError: true,
                ),
              ),

            // ── Browse & start ─────────────────────────────────────────────
            _ActionCard(
              icon: PhosphorIconsRegular.barbell,
              tint: PastelTint.lime,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: PastelCard(
        tint: isError ? PastelTint.salmon : PastelTint.sky,
        radius: 24,
        onTap: onTap,
        semanticLabel: '$label. $subtitle',
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
              child: Icon(
                isError
                    ? PhosphorIconsRegular.arrowClockwise
                    : PhosphorIconsRegular.sparkle,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.heading),
                  Text(subtitle,
                      style:
                          AppTextStyles.caption.copyWith(color: AppColors.ink)),
                ],
              ),
            ),
            const Icon(PhosphorIconsRegular.caretRight, size: 18),
          ],
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: PastelCard(
        tint: PastelTint.sky,
        radius: 24,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: AppTextStyles.body.copyWith(color: AppColors.ink)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final PastelTint tint;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PastelCard(
      tint: tint,
      radius: 28,
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      semanticLabel: '$title. $subtitle',
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
            child: Icon(icon, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.heading),
                const SizedBox(height: 4),
                Text(subtitle,
                    style:
                        AppTextStyles.caption.copyWith(color: AppColors.ink)),
              ],
            ),
          ),
          const Icon(PhosphorIconsRegular.caretRight, size: 18),
        ],
      ),
    );
  }
}
