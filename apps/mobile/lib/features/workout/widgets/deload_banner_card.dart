import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/deload_check.dart';

class DeloadBannerCard extends StatelessWidget {
  const DeloadBannerCard({super.key, required this.check});

  final DeloadCheck check;

  @override
  Widget build(BuildContext context) {
    final color = check.needsDeload ? AppColors.warning : AppColors.success;
    final icon =
        check.needsDeload ? Icons.battery_alert_rounded : Icons.bolt_rounded;
    final title =
        check.needsDeload ? 'Deload Week Recommended' : 'Training Load: Good';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.labelLarge.copyWith(color: color)),
                const SizedBox(height: 4),
                Text(
                  check.reason,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
                if (check.needsDeload) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${check.consecutiveHighVolumeWeeks} high-volume weeks · '
                    '~${check.weeklyAverageSets.round()} sets/week avg',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.onSurfaceVariant),
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
