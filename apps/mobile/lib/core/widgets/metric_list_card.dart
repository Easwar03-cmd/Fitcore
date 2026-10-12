import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import 'cutout_image.dart';
import 'pastel_chip.dart';

class MetricItem {
  const MetricItem({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor = AppColors.ink,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
}

/// Sky card listing label/value rows on the left and a cut-out image on the
/// right, with an optional chip top-right (reference screen C "Steps / HR").
class MetricListCard extends StatelessWidget {
  const MetricListCard({
    super.key,
    required this.items,
    this.tint = PastelTint.sky,
    this.chipLabel,
    this.chipIcon,
    this.imageName,
    this.fallbackIcon = Icons.directions_run_rounded,
    this.minHeight = 230,
  });

  final List<MetricItem> items;
  final PastelTint tint;
  final String? chipLabel;
  final IconData? chipIcon;
  final String? imageName;
  final IconData fallbackIcon;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      decoration: BoxDecoration(
        color: tint.color,
        borderRadius: BorderRadius.circular(AppRadius.hero),
      ),
      child: Stack(
        children: [
          if (imageName != null)
            Positioned(
              right: 0,
              bottom: 0,
              top: 24,
              width: 150,
              child: CutoutImage(name: imageName!, fallbackIcon: fallbackIcon),
            ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final m in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Semantics(
                      label: '${m.label} ${m.value}',
                      child: ExcludeSemantics(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(m.icon, size: 20, color: m.iconColor),
                            const SizedBox(width: 8),
                            Text(m.label,
                                style: AppTextStyles.caption
                                    .copyWith(color: AppColors.ink)),
                            const SizedBox(width: 10),
                            Text(m.value, style: AppTextStyles.metricM),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (chipLabel != null)
            Positioned(
              top: 14,
              right: 14,
              child: PastelChip(
                  label: chipLabel!, icon: chipIcon, filled: true),
            ),
        ],
      ),
    );
  }
}
