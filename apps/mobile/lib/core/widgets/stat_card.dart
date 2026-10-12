import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'pastel_card.dart';

/// Small metric tile: icon top-left, value + unit below
/// (reference "Heart pressure 123 / 80").
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
    this.tint = PastelTint.grey,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final PastelTint tint;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return PastelCard(
      tint: tint,
      onTap: onTap,
      semanticLabel: '$label $value${unit == null ? '' : ' $unit'}',
      padding: const EdgeInsets.all(14),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                  child: Icon(icon, size: 18),
                ),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 10),
            Text(label, style: AppTextStyles.caption),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value, style: AppTextStyles.metricM),
                  ),
                ),
                if (unit != null) ...[
                  const SizedBox(width: 4),
                  Text(unit!, style: AppTextStyles.caption),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
