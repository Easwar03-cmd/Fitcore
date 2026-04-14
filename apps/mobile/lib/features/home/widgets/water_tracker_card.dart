import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Water intake tracker with animated glass icons and +ml buttons.
///
/// Pure StatelessWidget — receives [waterMl] and [onAdd] callback from parent.
class WaterTrackerCard extends StatelessWidget {
  const WaterTrackerCard({
    super.key,
    required this.waterMl,
    required this.onAdd,
  });

  final int waterMl;
  final void Function(int ml) onAdd;

  static const int _goalMl = 2000;
  static const int _glassSize = 250; // ml per glass icon
  static const int _totalGlasses = 8;

  @override
  Widget build(BuildContext context) {
    final glassesConsumed = (waterMl / _glassSize).floor().clamp(0, _totalGlasses);
    final fraction = (waterMl / _goalMl).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Icon(Icons.water_drop_rounded, color: AppColors.info, size: 18),
            const SizedBox(width: 6),
            Text(
              'Water',
              style: AppTextStyles.titleMedium
                  .copyWith(color: AppColors.onBackground),
            ),
            const Spacer(),
            Text(
              '${waterMl}ml / ${_goalMl}ml',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Progress bar
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: fraction),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (_, value, __) => ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.info),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Glass icons row
        Row(
          children: List.generate(_totalGlasses, (i) {
            final filled = i < glassesConsumed;
            return Padding(
              padding: const EdgeInsets.only(right: 5),
              child: Icon(
                filled
                    ? Icons.water_drop_rounded
                    : Icons.water_drop_outlined,
                color: filled ? AppColors.info : AppColors.surfaceVariant,
                size: 22,
              ),
            );
          }),
        ),
        const SizedBox(height: 12),

        // Add buttons
        Row(
          children: [
            _AddButton(ml: 250, onAdd: onAdd),
            const SizedBox(width: 8),
            _AddButton(ml: 500, onAdd: onAdd),
          ],
        ),
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.ml, required this.onAdd});

  final int ml;
  final void Function(int ml) onAdd;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => onAdd(ml),
      icon: const Icon(Icons.add, size: 14),
      label: Text(
        '+${ml}ml',
        style: AppTextStyles.labelLarge.copyWith(fontSize: 12),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.info,
        side: const BorderSide(color: AppColors.info),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
