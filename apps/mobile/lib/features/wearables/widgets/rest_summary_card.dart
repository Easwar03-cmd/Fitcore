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

/// Two action tiles for the Progress screen (reference "Sleep quality" /
/// "IBM"): rest & heart (opens Wearables) and body weight (opens the log).
class RestSummaryCard extends ConsumerWidget {
  const RestSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(vitalsProvider).valueOrNull;
    final bpm = ref.watch(bleHeartRateProvider.select((s) => s.bpm));

    final score = v?.restScore;
    final subtitle = bpm != null
        ? 'Live heart rate $bpm bpm'
        : score != null
            ? '${v!.restLabel} · $score'
            : 'Check your sleep quality';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _ActionTile(
              tint: PastelTint.salmon,
              icon: PhosphorIconsRegular.bed,
              title: 'Sleep & rest',
              subtitle: subtitle,
              cta: 'Check',
              onTap: () => context.push(AppRoutes.wearableIntegrations),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActionTile(
              tint: PastelTint.sky,
              icon: PhosphorIconsRegular.scales,
              title: 'Body weight',
              subtitle: 'Control your weight and body fat',
              cta: 'Log',
              onTap: () => context.push(AppRoutes.bodyLog),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.tint,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.onTap,
  });

  final PastelTint tint;
  final IconData icon;
  final String title;
  final String subtitle;
  final String cta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PastelCard(
      tint: tint,
      radius: 24,
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      semanticLabel: '$title. $subtitle. $cta.',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: AppTextStyles.heading)),
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                  child: Icon(icon, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(subtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(color: AppColors.ink)),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(cta, style: AppTextStyles.bodyStrong),
                const Spacer(),
                const Icon(PhosphorIconsBold.arrowRight, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
