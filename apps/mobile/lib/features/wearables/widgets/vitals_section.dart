import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/services/health_service.dart' show SleepNight;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/half_donut_gauge.dart';
import '../../../core/widgets/pastel_card.dart';
import '../../../core/widgets/stat_card.dart';
import '../providers/vitals_provider.dart';

String _hm(int minutes) => '${minutes ~/ 60}h ${minutes % 60}m';

/// Sleep, rest score and heart metrics read from Health Connect / Apple Health.
class VitalsSection extends ConsumerWidget {
  const VitalsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vitals = ref.watch(vitalsProvider);
    final store = Platform.isIOS ? 'Apple Health' : 'Health Connect';

    return vitals.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _ConnectCard(
        store: store,
        busy: false,
        message: 'Could not read health data. Try again.',
        onConnect: () => ref.read(vitalsProvider.notifier).connect(),
      ),
      data: (v) {
        if (!v.hasAccess) {
          return _ConnectCard(
            store: store,
            busy: false,
            onConnect: () async {
              final ok = await ref.read(vitalsProvider.notifier).connect();
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Access not granted. You can allow it any '
                      'time in $store settings.'),
                ));
              }
            },
          );
        }
        if (!v.hasAnyData) {
          return PastelCard(
            radius: 24,
            child: Text(
              'Connected to $store, but no sleep or heart-rate data was found '
              'yet. Wear your watch overnight and make sure its app syncs to '
              '$store.',
              style: AppTextStyles.body,
            ),
          );
        }
        return _Data(v: v);
      },
    );
  }
}

class _ConnectCard extends StatelessWidget {
  const _ConnectCard({
    required this.store,
    required this.busy,
    required this.onConnect,
    this.message,
  });

  final String store;
  final bool busy;
  final VoidCallback onConnect;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return PastelCard(
      tint: PastelTint.lime,
      radius: 28,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                child: const Icon(PhosphorIconsRegular.moonStars, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Sleep, rest & heart rate',
                    style: AppTextStyles.heading),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message ??
                'Allow Revive to read sleep, heart rate and HRV from $store. '
                    'Most watches (Galaxy Watch, Fitbit, Garmin, Amazfit, '
                    'Xiaomi, Oura, WHOOP, Apple Watch) save their data there. '
                    'It stays on your device.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: busy ? null : onConnect,
            child: Text('Allow access to $store'),
          ),
        ],
      ),
    );
  }
}

class _Data extends StatelessWidget {
  const _Data({required this.v});
  final VitalsSummary v;

  @override
  Widget build(BuildContext context) {
    final n = v.night;
    final score = v.restScore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (score != null)
          PastelCard(
            radius: 28,
            padding: const EdgeInsets.all(18),
            child: HalfDonutGauge(
              title: 'Rest score',
              caption: v.restLabel ?? '',
              fraction: score / 100,
              valueLabel: '$score',
              positive: score >= 50,
            ),
          ),
        if (n != null) ...[
          const SizedBox(height: 12),
          _SleepCard(night: n, history: v.sleepHistoryMin),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: PhosphorIconsRegular.heartbeat,
                label: 'Avg today',
                value: v.avgHeartRate?.toString() ?? '—',
                unit: 'bpm',
                tint: PastelTint.salmon,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                icon: PhosphorIconsRegular.heart,
                label: 'Resting',
                value: v.restingHeartRate?.toString() ?? '—',
                unit: 'bpm',
                tint: PastelTint.sky,
              ),
            ),
          ],
        ),
        if (v.hrvMs != null) ...[
          const SizedBox(height: 12),
          StatCard(
            icon: PhosphorIconsRegular.waveform,
            label: 'Heart-rate variability',
            value: v.hrvMs!.round().toString(),
            unit: 'ms',
            tint: PastelTint.lime,
          ),
        ],
      ],
    );
  }
}

class _SleepCard extends StatelessWidget {
  const _SleepCard({required this.night, required this.history});
  final SleepNight night;
  final List<int> history;

  @override
  Widget build(BuildContext context) {
    final maxMin = history.fold<int>(480, (m, e) => e > m ? e : m);
    return PastelCard(
      tint: PastelTint.butter,
      radius: 28,
      padding: const EdgeInsets.all(18),
      semanticLabel: 'Last night you slept ${_hm(night.totalMinutes)}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(PhosphorIconsRegular.moon, size: 20),
                const SizedBox(width: 8),
                Text('Last night', style: AppTextStyles.heading),
              ],
            ),
            const SizedBox(height: 8),
            Text(_hm(night.totalMinutes), style: AppTextStyles.metricXL),
            if (night.hasStages) ...[
              const SizedBox(height: 14),
              _StageBar(night: night),
            ],
            if (history.any((m) => m > 0)) ...[
              const SizedBox(height: 16),
              Text('Last 7 nights', style: AppTextStyles.caption
                  .copyWith(color: AppColors.ink)),
              const SizedBox(height: 8),
              SizedBox(
                height: 64,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final m in history)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Container(
                            height: 6 + 58 * (m / maxMin).clamp(0.0, 1.0),
                            decoration: BoxDecoration(
                              color: m == 0 ? Colors.white54 : AppColors.ink,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StageBar extends StatelessWidget {
  const _StageBar({required this.night});
  final SleepNight night;

  @override
  Widget build(BuildContext context) {
    final parts = <(String, int, Color)>[
      ('Deep', night.deepMinutes, AppColors.ink),
      ('REM', night.remMinutes, AppColors.tealBright),
      ('Light', night.lightMinutes, AppColors.sky),
      if (night.awakeMinutes > 0) ('Awake', night.awakeMinutes, AppColors.salmon),
    ];
    final total = parts.fold<int>(0, (a, p) => a + p.$2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 12,
            child: Row(
              children: [
                for (final p in parts)
                  if (p.$2 > 0)
                    Expanded(flex: p.$2, child: ColoredBox(color: p.$3)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (final p in parts)
              if (p.$2 > 0 && total > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration:
                          BoxDecoration(color: p.$3, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text('${p.$1} ${_hm(p.$2)}', style: AppTextStyles.micro),
                  ],
                ),
          ],
        ),
      ],
    );
  }
}
