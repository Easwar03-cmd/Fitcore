import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/circle_icon_button.dart';
import '../../../core/widgets/hero_card.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../core/widgets/pastel_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../progress/providers/progress_provider.dart';
import '../../../core/widgets/muscle_workload_card.dart';
import '../providers/deload_check_provider.dart';
import '../providers/workout_provider.dart';
import '../widgets/deload_banner_card.dart';
import '../widgets/train_muscle.dart';

class WorkoutScreen extends ConsumerWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(workoutSessionProvider);
    final deloadAsync = ref.watch(deloadCheckProvider);

    return Scaffold(
      appBar: PageAppBar(
        showBack: false,
        title: 'Workout',
        actions: [
          CircleIconButton(
            icon: PhosphorIconsRegular.clockCounterClockwise,
            semanticLabel: 'Workout history',
            onPressed: () => context.push(AppRoutes.workoutHistory),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 4, 4, 12),
            child: _Headline(),
          ),

          // ── Resume active session ───────────────────────────────────────
          if (session.isActive) ...[
            _ResumeCard(onResume: () => context.push(AppRoutes.activeWorkout)),
            const SizedBox(height: 12),
          ],

          // ── Deload banner ───────────────────────────────────────────────
          deloadAsync.when(
            data: (check) => check != null
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DeloadBannerCard(check: check),
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          const SectionHeader('Start a workout'),

          // ── Gym ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: HeroCard(
              chipLabel: 'Gym',
              chipIcon: PhosphorIconsFill.trophy,
              title: 'Gym Workout',
              subtitle: 'AI recommendation + log sets with weights.',
              ctaLabel: 'Get started',
              onCta: () => context.push(AppRoutes.gymWorkout),
              imageName: 'hero_gym_athlete.jpg',
              fallbackIcon: PhosphorIconsRegular.barbell,
              height: 160,
            ),
          ),
          const SizedBox(height: 28),

          // ── Home ────────────────────────────────────────────────────────
          HeroCard(
            tint: PastelTint.lime,
            chipLabel: 'Home',
            chipIcon: PhosphorIconsFill.house,
            title: 'Home Workout',
            subtitle: 'AI recommendation + bodyweight & calisthenics.',
            ctaLabel: 'Get started',
            onCta: () => context.push(AppRoutes.homeWorkouts),
            imageName: 'hero_home_workout.jpg',
            fallbackIcon: PhosphorIconsRegular.personSimpleRun,
            height: 160,
          ),
          const SizedBox(height: 16),

          // ── Muscles workload picker ─────────────────────────────────────
          MuscleWorkloadCard(
            volume: ref.watch(progressProvider).valueOrNull?.muscleVolume ??
                const {},
            onTrain: (k) => startTrainingForMuscle(context, ref, k),
          ),
        ],
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text('Let’s move', style: AppTextStyles.display),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.onResume});
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return PastelCard(
      tint: PastelTint.butter,
      radius: 28,
      onTap: onResume,
      semanticLabel: 'Workout in progress. Tap to resume.',
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
                color: AppColors.ink, shape: BoxShape.circle),
            child: const Icon(PhosphorIconsFill.play,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Workout in progress', style: AppTextStyles.heading),
                Text('Tap to resume',
                    style:
                        AppTextStyles.caption.copyWith(color: AppColors.ink)),
              ],
            ),
          ),
          const Icon(PhosphorIconsRegular.caretRight, size: 20),
        ],
      ),
    );
  }
}
