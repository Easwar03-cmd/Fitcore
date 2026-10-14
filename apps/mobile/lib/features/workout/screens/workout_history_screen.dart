import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../core/widgets/pastel_card.dart';
import '../../../core/widgets/pastel_chip.dart';
import '../../../core/widgets/skeleton.dart';

import '../models/workout_log.dart';
import '../providers/workout_history_provider.dart';

class WorkoutHistoryScreen extends ConsumerStatefulWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  ConsumerState<WorkoutHistoryScreen> createState() =>
      _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends ConsumerState<WorkoutHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
      // Retry at +2 s and +5 s to catch workouts whose background POST
      // hasn't landed on the server yet when the screen first mounts.
      Future.delayed(const Duration(seconds: 2), () { if (mounted) _refresh(); });
      Future.delayed(const Duration(seconds: 5), () { if (mounted) _refresh(); });
    });
  }

  void _refresh() => ref.read(workoutHistoryProvider.notifier).refresh();

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(workoutHistoryProvider);

    return Scaffold(
      appBar: const PageAppBar(title: 'Workout History'),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: PhosphorIconsRegular.warningCircle,
          title: e.toString().replaceAll('Exception: ', ''),
          actionLabel: 'Retry',
          onAction: () => ref.read(workoutHistoryProvider.notifier).refresh(),
        ),
        data: (logs) => logs.isEmpty
            ? const EmptyState(
                icon: PhosphorIconsRegular.barbell,
                imageName: 'obj_dumbbell.png',
                title: 'No workouts yet',
                message: 'Finish your first workout to see it here.',
              )
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
    final grouped = log.setsByExercise;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PastelCard(
        radius: 24,
        padding: EdgeInsets.zero,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            shape: const Border(),
            collapsedShape: const Border(),
            title: Text(log.name, style: AppTextStyles.heading),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _StatChips(log: log),
            ),
            trailing: Text(_formatDate(log.startedAt),
                style: AppTextStyles.caption),
            children: grouped.entries
                .map((entry) => _ExerciseGroup(
                      exerciseName: entry.key,
                      sets: entry.value,
                    ))
                .toList(),
          ),
        ),
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
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (log.durationMin != null)
          PastelChip(
            label: '${log.durationMin} min',
            icon: PhosphorIconsRegular.timer,
            background: AppColors.sky,
          ),
        PastelChip(
          label: '${log.sets.length} sets',
          icon: PhosphorIconsRegular.listNumbers,
          background: AppColors.lime,
        ),
        if (log.caloriesBurned != null)
          PastelChip(
            label: '~${log.caloriesBurned} kcal',
            icon: PhosphorIconsRegular.flame,
            background: AppColors.salmon,
          ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 20),
        Text(exerciseName, style: AppTextStyles.bodyStrong),
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
                    style: AppTextStyles.caption,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 8),
                Text(s.detail, style: AppTextStyles.body),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
