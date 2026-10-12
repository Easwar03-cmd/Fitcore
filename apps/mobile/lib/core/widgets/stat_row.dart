import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Tinted value pill + muted label, hairline below
/// (reference screen B "Today's Activity").
class StatRow extends StatelessWidget {
  const StatRow({
    super.key,
    required this.tint,
    required this.icon,
    required this.value,
    required this.label,
    this.showDivider = true,
  });

  final PastelTint tint;
  final IconData icon;
  final String value;
  final String label;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$label: $value',
      child: ExcludeSemantics(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  ValuePill(tint: tint, icon: icon, value: value),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      label,
                      style: AppTextStyles.body
                          .copyWith(color: AppColors.inkMuted),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
            if (showDivider) const Divider(),
          ],
        ),
      ),
    );
  }
}

class ValuePill extends StatelessWidget {
  const ValuePill({
    super.key,
    required this.tint,
    required this.icon,
    required this.value,
  });

  final PastelTint tint;
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 44, minWidth: 110),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: tint.color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.ink),
          const SizedBox(width: 8),
          Text(value, style: AppTextStyles.bodyStrong),
        ],
      ),
    );
  }
}
