import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/app_routes.dart';
import '../models/exercise.dart';
import '../models/workout_session_state.dart';
import '../providers/workout_provider.dart';
import '../widgets/rest_timer_widget.dart';
import '../widgets/set_logger.dart';
import '../widgets/workout_timer_widget.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/metric_list_card.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../core/widgets/pastel_card.dart';

SetInputMode _inputModeFor(Exercise exercise) {
  if (exercise.timedOnly) return SetInputMode.durationOnly;
  if (exercise.isBodyweight) return SetInputMode.repsOnly;
  return SetInputMode.repsAndWeight;
}

class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  ConsumerState<ActiveWorkoutScreen> createState() =>
      _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  Timer? _countdownTimer;
  int? _timerRemainingSeconds; // null = no timer set
  bool _timerPaused = false;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _openTimerPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => WorkoutTimerPickerSheet(onSelect: _startTimer),
    );
  }

  void _startTimer(Duration duration) {
    _countdownTimer?.cancel();
    setState(() {
      _timerRemainingSeconds = duration.inSeconds;
      _timerPaused = false;
    });
    _runCountdownTick();
  }

  void _runCountdownTick() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final r = _timerRemainingSeconds;
      if (r != null && r > 0) {
        setState(() => _timerRemainingSeconds = r - 1);
      } else {
        _countdownTimer?.cancel();
        setState(() {
          _timerRemainingSeconds = null;
          _timerPaused = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Workout timer finished!'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    });
  }

  void _pauseTimer() {
    _countdownTimer?.cancel();
    setState(() => _timerPaused = true);
  }

  void _resumeTimer() {
    setState(() => _timerPaused = false);
    _runCountdownTick();
  }

  void _stopTimer() {
    _countdownTimer?.cancel();
    setState(() {
      _timerRemainingSeconds = null;
      _timerPaused = false;
    });
  }

  Future<void> _switchExercise() async {
    final isHome =
        ref.read(workoutSessionProvider).currentExercise?.isBodyweight ?? false;

    final Exercise? exercise;
    if (isHome) {
      // Pick mode: HomeWorkoutListScreen returns an Exercise on tap instead of
      // starting a new session (signalled by passing extra: true).
      exercise = await context.push<Exercise>(
        AppRoutes.homeWorkouts,
        extra: true, // pickMode = true
      );
    } else {
      exercise = await context.push<Exercise>(AppRoutes.exercisePicker);
    }

    if (exercise != null && context.mounted) {
      ref.read(workoutSessionProvider.notifier).setExercise(exercise);
    }
  }

  Future<void> _finish() async {
    if (ref.read(workoutSessionProvider).allSets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Log at least one set before finishing.')),
      );
      return;
    }
    // finishWorkout() sets the summary in state and fires the POST in the
    // background, so navigation is immediate — no spinner needed.
    ref.read(workoutSessionProvider.notifier).finishWorkout();
    if (!mounted) return;
    context.push(AppRoutes.workoutSummary);
  }

  Future<void> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Workout?'),
        content: const Text('All logged sets will be discarded.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Going'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Cancel',
                style:
                    TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      ref.read(workoutSessionProvider.notifier).resetSession();
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(workoutSessionProvider);
    final exercise = session.currentExercise;

    return Scaffold(
      appBar: PageAppBar(
        title: exercise?.name ?? 'Workout',
        onBack: _confirmCancel,
        actions: [
          if (session.isSubmitting)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            FilledButton(
              onPressed: _finish,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              child: const Text('Finish'),
            ),
        ],
      ),
      body: exercise == null
          ? const Center(child: CircularProgressIndicator())
          : _WorkoutBody(
              session: session,
              onSwitchExercise: _switchExercise,
              onToggleOutdoor: () => ref
                  .read(workoutSessionProvider.notifier)
                  .toggleOutdoorMode(),
              onLogSet: (reps, weight, duration) =>
                  ref.read(workoutSessionProvider.notifier).logSet(
                        reps: reps,
                        weightKg: weight,
                        durationSec: duration,
                      ),
              onSkipRest: () =>
                  ref.read(workoutSessionProvider.notifier).skipRest(),
              timerRemainingSeconds: _timerRemainingSeconds,
              timerPaused: _timerPaused,
              onTimerOpen: _openTimerPicker,
              onTimerPause: _pauseTimer,
              onTimerResume: _resumeTimer,
              onTimerStop: _stopTimer,
            ),
    );
  }
}

// ── Pure body widget ─────────────────────────────────────────────────────────

class _WorkoutBody extends StatelessWidget {
  const _WorkoutBody({
    required this.session,
    required this.onSwitchExercise,
    required this.onToggleOutdoor,
    required this.onLogSet,
    required this.onSkipRest,
    required this.timerRemainingSeconds,
    required this.timerPaused,
    required this.onTimerOpen,
    required this.onTimerPause,
    required this.onTimerResume,
    required this.onTimerStop,
  });

  final WorkoutSessionState session;
  final VoidCallback onSwitchExercise;
  final VoidCallback onToggleOutdoor;
  final void Function(int? reps, double? weightKg, int? durationSec) onLogSet;
  final VoidCallback onSkipRest;
  final int? timerRemainingSeconds;
  final bool timerPaused;
  final VoidCallback onTimerOpen;
  final VoidCallback onTimerPause;
  final VoidCallback onTimerResume;
  final VoidCallback onTimerStop;

  @override
  Widget build(BuildContext context) {
    final exercise = session.currentExercise!;
    final sets = session.setsForCurrentExercise;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        // ── Title row: ink circle + exercise ───────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.salmon, width: 3),
                ),
                child: Icon(exercise.muscleGroup.icon,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exercise.name,
                        style: AppTextStyles.title.copyWith(fontSize: 22)),
                    Text(exercise.muscleGroup.label,
                        style: AppTextStyles.caption),
                  ],
                ),
              ),
              TextButton(
                onPressed: onSwitchExercise,
                child: const Text('Switch'),
              ),
            ],
          ),
        ),

        // ── Workout timer ──────────────────────────────────────────────────
        WorkoutTimerWidget(
          remainingSeconds: timerRemainingSeconds,
          isPaused: timerPaused,
          onSetTimer: onTimerOpen,
          onPause: onTimerPause,
          onResume: onTimerResume,
          onStop: onTimerStop,
        ),
        const SizedBox(height: 12),

        // ── Outdoor mode toggle (all exercises) ────────────────────────────
        _OutdoorToggle(
          isOutdoorMode: session.isOutdoorMode,
          onToggle: onToggleOutdoor,
        ),
        const SizedBox(height: 12),

        // ── Live GPS stats ─────────────────────────────────────────────────
        if (session.isOutdoorMode) ...[
          _GpsStatsBar(
            distanceKm: session.distanceKm,
            paceMinPerKm: session.paceMinPerKm,
          ),
          const SizedBox(height: 12),
        ],

        // ── Logged sets for this exercise ──────────────────────────────────
        if (sets.isNotEmpty) ...[
          PastelCard(
            radius: 28,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sets logged', style: AppTextStyles.heading),
                const SizedBox(height: 8),
                ...sets.map((s) => _SetRow(set: s)),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── Rest timer OR set logger ───────────────────────────────────────
        if (session.isResting)
          RestTimerWidget(
            secondsLeft: session.restSecondsLeft,
            onSkip: onSkipRest,
          )
        else
          PastelCard(
            tint: PastelTint.sky,
            radius: 28,
            padding: const EdgeInsets.all(18),
            child: SetLogger(
              setNumber: session.nextSetNumber,
              inputMode: _inputModeFor(exercise),
              onLog: onLogSet,
              lastReps: sets.isNotEmpty ? sets.last.reps : null,
              lastWeightKg: sets.isNotEmpty ? sets.last.weightKg : null,
              lastDurationSec: sets.isNotEmpty ? sets.last.durationSec : null,
            ),
          ),
      ],
    );
  }
}

// ── Outdoor toggle card ───────────────────────────────────────────────────────

class _OutdoorToggle extends StatelessWidget {
  const _OutdoorToggle({
    required this.isOutdoorMode,
    required this.onToggle,
  });

  final bool isOutdoorMode;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return PastelCard(
      tint: isOutdoorMode ? PastelTint.lime : PastelTint.white,
      radius: 24,
      onTap: onToggle,
      semanticLabel:
          'Outdoor mode, ${isOutdoorMode ? 'GPS tracking active' : 'off'}',
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
                color: AppColors.surfaceMuted, shape: BoxShape.circle),
            child: const Icon(PhosphorIconsRegular.mapTrifold, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Outdoor Mode', style: AppTextStyles.heading),
                Text(
                  isOutdoorMode
                      ? 'GPS tracking active'
                      : 'Tap to track route & distance',
                  style: AppTextStyles.caption.copyWith(color: AppColors.ink),
                ),
              ],
            ),
          ),
          Switch(value: isOutdoorMode, onChanged: (_) => onToggle()),
        ],
      ),
    );
  }
}

// ── Live GPS stats bar ────────────────────────────────────────────────────────

class _GpsStatsBar extends StatelessWidget {
  const _GpsStatsBar({
    required this.distanceKm,
    this.paceMinPerKm,
  });

  final double distanceKm;
  final double? paceMinPerKm;

  String get _distanceLabel {
    if (distanceKm < 1.0) {
      return '${(distanceKm * 1000).round()} m';
    }
    return '${distanceKm.toStringAsFixed(2)} km';
  }

  String get _paceLabel {
    final pace = paceMinPerKm;
    if (pace == null) return '—';
    final mins = pace.floor();
    final secs = ((pace - mins) * 60).round();
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return MetricListCard(
      minHeight: 150,
      items: [
        MetricItem(
          icon: PhosphorIconsRegular.path,
          label: 'Distance',
          value: _distanceLabel,
          iconColor: AppColors.teal,
        ),
        MetricItem(
          icon: PhosphorIconsRegular.gauge,
          label: 'Pace min/km',
          value: _paceLabel,
          iconColor: AppColors.coralText,
        ),
      ],
      imageName: 'workout_runner.png',
      fallbackIcon: PhosphorIconsRegular.personSimpleRun,
    );
  }
}

// ── Set row ───────────────────────────────────────────────────────────────────

class _SetRow extends StatelessWidget {
  const _SetRow({required this.set});

  final LoggedSet set;

  String get _detail {
    if (set.reps != null && set.weightKg != null) {
      return '${set.reps} reps × ${set.weightKg} kg';
    } else if (set.reps != null) {
      return '${set.reps} reps';
    } else if (set.weightKg != null) {
      return '${set.weightKg} kg';
    } else if (set.durationSec != null) {
      return '${set.durationSec}s';
    }
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
                color: AppColors.sky, shape: BoxShape.circle),
            child: Text('${set.setNumber}', style: AppTextStyles.micro),
          ),
          const SizedBox(width: 12),
          Text(_detail, style: AppTextStyles.body),
          const Spacer(),
          const Icon(PhosphorIconsFill.checkCircle, size: 20),
        ],
      ),
    );
  }
}
