import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/pastel_card.dart';
import '../../../core/widgets/pastel_chip.dart';

/// Shown in place of a Coach-gated feature section when the user is on Free/Pro.
class LockedFeatureCard extends StatelessWidget {
  const LockedFeatureCard({super.key, required this.featureName});

  final String featureName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: PastelCard(
        tint: PastelTint.butter,
        radius: 24,
        onTap: () => context.push(AppRoutes.paywall, extra: featureName),
        semanticLabel: '$featureName. Coach plan required. Tap to upgrade.',
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
              child: const Icon(PhosphorIconsRegular.lock, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(featureName, style: AppTextStyles.heading),
                  const SizedBox(height: 2),
                  Text('Coach plan required — tap to upgrade',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.ink)),
                ],
              ),
            ),
            const PastelChip(label: 'Coach', filled: true),
          ],
        ),
      ),
    );
  }
}
