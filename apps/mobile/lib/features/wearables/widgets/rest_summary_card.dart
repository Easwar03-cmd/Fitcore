import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../constants/app_routes.dart';
import '../../../core/services/ble_heart_rate_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/pastel_card.dart';
import '../providers/vitals_provider.dart';

/// Compact "Rest & heart" card for the Progress screen. Opens the full
/// wearables screen.
class RestSummaryCard extends ConsumerWidget {
  const RestSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(vitalsProvider).valueOrNull;
    final bpm = ref.watch(bleHeartRateProvider.select((s) => s.bpm));

    final score = v?.restScore;
    final night = v?.night;
    final connected = (v?.hasAnyData ?? false) || bpm != null;

    final title = !connected
        ? 'Connect your watch'
        : score != null
            ? '${v!.restLabel} · $score'
            : bpm != null
                ? 'Live heart rate $bpm bpm'
                : 'Rest & heart';
    final subtitle = !connected
        ? 'Track heart rate, sleep and rest'
        : [
            if (night != null)
              '${night.totalMinutes ~/ 60}h ${night.totalMinutes % 60}m sleep',
            if (v?.restingHeartRate != null) 'Resting ${v!.restingHeartRate} bpm',
          ].join(' · ');

    return PastelCard(
      tint: PastelTint.lime,
      radius: 28,
      padding: const EdgeInsets.all(18),
      onTap: () => context.push(AppRoutes.wearableIntegrations),
      semanticLabel: '$title. $subtitle',
      child: ExcludeSemantics(
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
              child: const Icon(PhosphorIconsRegular.heartbeat, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.heading),
                  if (subtitle.isNotEmpty)
                    Text(subtitle,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.ink)),
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
