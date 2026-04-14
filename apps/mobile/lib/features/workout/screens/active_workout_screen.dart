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

class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  ConsumerState<ActiveWorkoutScreen> createState() =>
      _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final startedAt = ref.read(workoutSessionProvider).startedAt;
      if (startedAt != null && mounted) {
        setState(() => _elapsed = DateTime.now().difference(startedAt));
      }
    });
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    super.dispose();
  }

  String get _elapsedLabel {
    final h = _elapsed.inHours;
    final m = _elapsed.inMinutes % 60;
    final s = _elapsed.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _switchExercise() async {
    final exercise =
        await context.push<Exercise>(AppRoutes.exercisePicker);
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
    setState(() => _finishing = true);
    await ref.read(workoutSessionProvider.notifier).finishWorkout();
    if (!mounted) return;
    context.push(AppRoutes.workoutSummary);
    setState(() => _finishing = false);
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_elapsedLabel),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _confirmCancel,
        ),
        actions: [
          if (_finishing || session.isSubmitting)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _finish,
              child: const Text('Finish'),
            ),
        ],
      ),
      body: session.currentExercise == null
          ? const Center(child: CircularProgressIndicator())
          : _WorkoutBody(
              session: session,
              onSwitchExercise: _switchExercise,
              onToggleOutdoor: () => ref
                  .read(workoutSessionProvider.notifier)
                  .toggleOutdoorMode(),
              onLogSet: (reps, weight) =>
                  ref.read(workoutSessionProvider.notifier).logSet(
                        reps: reps,
                        weightKg: weight,
                      ),
              onSkipRest: () =>
                  ref.read(workoutSessionProvider.notifier).skipRest(),
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
  });

  final WorkoutSessionState session;
  final VoidCallback onSwitchExercise;
  final VoidCallback onToggleOutdoor;
  final void Function(int? reps, double? weightKg) onLogSet;
  final VoidCallback onSkipRest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exercise = session.currentExercise!;
    final sets = session.setsForCurrentExercise;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Current exercise card ────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        exercise.muscleGroup.color.withValues(alpha: 0.15),
                    child: Icon(exercise.muscleGroup.icon,
                        color: exercise.muscleGroup.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exercise.name,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          exercise.muscleGroup.label,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
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
          ),
          const SizedBox(height: 12),

          // ── Outdoor mode toggle (all exercises) ──────────────────────────
          _OutdoorToggle(
            isOutdoorMode: session.isOutdoorMode,
            onToggle: onToggleOutdoor,
          ),
          const SizedBox(height: 12),

          // ── Live GPS stats (shown once outdoor mode is on) ───────────────
          if (session.isOutdoorMode) ...[
            _GpsStatsBar(
              distanceKm: session.distanceKm,
              paceMinPerKm: session.paceMinPerKm,
            ),
            const SizedBox(height: 12),
          ],

          // ── Logged sets for this exercise ────────────────────────────────
          if (sets.isNotEmpty) ...[
            Text('Sets logged', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            ...sets.map((s) => _SetRow(set: s)),
            const SizedBox(height: 20),
          ],

          // ── Rest timer OR set logger ─────────────────────────────────────
          if (session.isResting)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: RestTimerWidget(
                  secondsLeft: session.restSecondsLeft,
                  onSkip: onSkipRest,
                ),
              ),
            )
          else
            SetLogger(
              setNumber: session.nextSetNumber,
              onLog: onLogSet,
              lastReps: sets.isNotEmpty ? sets.last.reps : null,
              lastWeightKg: sets.isNotEmpty ? sets.last.weightKg : null,
            ),
        ],
      ),
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
    final theme = Theme.of(context);
    final color = isOutdoorMode
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.map_rounded, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Outdoor Mode',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(color: color, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      isOutdoorMode
                          ? 'GPS tracking active'
                          : 'Tap to track route & distance',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isOutdoorMode,
                onChanged: (_) => onToggle(),
              ),
            ],
          ),
        ),
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
    return "$mins'${secs.toString().padLeft(2, '0')}\"";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // ── Distance ────────────────────────────────────────────────────
            const Icon(Icons.straighten_rounded, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _distanceLabel,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text('Distance',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // ── Pace ─────────────────────────────────────────────────────────
            const Icon(Icons.speed_rounded, size: 18),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _paceLabel,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text('min/km',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              '${set.setNumber}',
              style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer),
            ),
          ),
          const SizedBox(width: 12),
          Text(_detail, style: theme.textTheme.bodyMedium),
          const Spacer(),
          Icon(Icons.check_circle_rounded,
              size: 18, color: theme.colorScheme.primary),
        ],
      ),
    );
  }
}
