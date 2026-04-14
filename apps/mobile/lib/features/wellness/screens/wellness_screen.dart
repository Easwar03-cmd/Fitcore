import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../models/wellness_state.dart';
import '../providers/wellness_provider.dart';
import '../widgets/heart_rate_card.dart';
import '../widgets/mood_logger_card.dart';
import '../widgets/readiness_ring.dart';
import '../widgets/sleep_card.dart';

class WellnessScreen extends ConsumerWidget {
  const WellnessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wellnessAsync = ref.watch(wellnessProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Wellness',
            style: AppTextStyles.titleLarge
                .copyWith(color: AppColors.onBackground)),
      ),
      body: wellnessAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: e.toString(),
          onRetry: () => ref.read(wellnessProvider.notifier).refresh(),
        ),
        data: (wellness) => _WellnessDashboard(
          wellness: wellness,
          onLogMood: (score) =>
              ref.read(wellnessProvider.notifier).logMood(score),
          onRefresh: () async =>
              ref.read(wellnessProvider.notifier).refresh(),
        ),
      ),
    );
  }
}

// ── Dashboard body ────────────────────────────────────────────────────────────

class _WellnessDashboard extends StatelessWidget {
  const _WellnessDashboard({
    required this.wellness,
    required this.onLogMood,
    required this.onRefresh,
  });

  final WellnessState wellness;
  final void Function(int score) onLogMood;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ── Readiness ring ────────────────────────────────────────────────
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
            child: Column(
              children: [
                Text(
                  'Today\'s Readiness',
                  style: AppTextStyles.titleMedium
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                ReadinessRing(
                  score: wellness.readinessScore,
                  label: wellness.readinessLabel,
                  level: wellness.readinessLevel,
                ),
                const SizedBox(height: 16),
                _ReadinessBreakdown(wellness: wellness),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.08, end: 0, curve: Curves.easeOut),

          const SizedBox(height: 14),

          // ── Sleep card ────────────────────────────────────────────────────
          AppCard(
            child: SleepCard(
              sleepMinutes: wellness.sleepMinutes,
              sleepScore: wellness.sleepScore,
              sleepTrend: wellness.sleepTrend,
              stages: wellness.sleepStages,
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms, delay: 80.ms)
              .slideY(begin: 0.08, end: 0, curve: Curves.easeOut),

          const SizedBox(height: 14),

          // ── Heart rate card ───────────────────────────────────────────────
          AppCard(
            child: HeartRateCard(
              restingHr: wellness.restingHr,
              hrZoneLabel: wellness.hrZoneLabel,
              hrTrend: wellness.hrTrend,
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms, delay: 160.ms)
              .slideY(begin: 0.08, end: 0, curve: Curves.easeOut),

          const SizedBox(height: 14),

          // ── Mood logger card ──────────────────────────────────────────────
          AppCard(
            child: MoodLoggerCard(
              todayMood: wellness.todayMood,
              moodHistory: wellness.moodHistory,
              onLog: onLogMood,
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms, delay: 240.ms)
              .slideY(begin: 0.08, end: 0, curve: Curves.easeOut),
        ],
      ),
    );
  }
}

// ── Readiness breakdown ───────────────────────────────────────────────────────

/// Three small contribution pills showing what drove the readiness score.
class _ReadinessBreakdown extends StatelessWidget {
  const _ReadinessBreakdown({required this.wellness});

  final WellnessState wellness;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Pill(
          label: 'Sleep',
          value: '${wellness.sleepScore}',
          color: AppColors.info,
        ),
        const SizedBox(width: 8),
        _Pill(
          label: 'HR',
          value: wellness.restingHr != null
              ? '${wellness.restingHr} bpm'
              : '—',
          color: AppColors.error,
        ),
        const SizedBox(width: 8),
        _Pill(
          label: 'Recovery',
          value: wellness.readinessLevel == ReadinessLevel.rest
              ? 'Low'
              : wellness.readinessLevel == ReadinessLevel.light
                  ? 'Med'
                  : 'High',
          color: AppColors.success,
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(
      {required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: AppTextStyles.labelLarge.copyWith(color: color)),
          Text(label,
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 48, color: AppColors.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              message.replaceFirst('Exception: ', ''),
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
                onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
