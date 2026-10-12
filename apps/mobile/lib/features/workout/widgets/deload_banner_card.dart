import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/pastel_card.dart';
import '../models/deload_check.dart';

/// Butter (deload recommended) or lime (load is good) status card.
class DeloadBannerCard extends StatelessWidget {
  const DeloadBannerCard({super.key, required this.check});

  final DeloadCheck check;

  @override
  Widget build(BuildContext context) {
    final warn = check.needsDeload;
    final title = warn ? 'Deload Week Recommended' : 'Training Load: Good';

    return PastelCard(
      tint: warn ? PastelTint.butter : PastelTint.lime,
      radius: 24,
      semanticLabel: title,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
            child: Icon(
              warn
                  ? PhosphorIconsRegular.batteryWarning
                  : PhosphorIconsRegular.lightning,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.heading),
                const SizedBox(height: 4),
                Text(check.reason,
                    style:
                        AppTextStyles.caption.copyWith(color: AppColors.ink)),
                if (warn) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${check.consecutiveHighVolumeWeeks} high-volume weeks · '
                    '~${check.weeklyAverageSets.round()} sets/week avg',
                    style: AppTextStyles.micro,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
