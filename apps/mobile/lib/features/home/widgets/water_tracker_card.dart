import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/pastel_card.dart';
import '../../../core/widgets/cutout_image.dart';

/// Water intake: progress, glass row and +ml quick-add circles.
///
/// Pure StatelessWidget — receives [waterMl], [waterTargetMl], and [onAdd].
class WaterTrackerCard extends StatelessWidget {
  const WaterTrackerCard({
    super.key,
    required this.waterMl,
    required this.waterTargetMl,
    required this.onAdd,
  });

  final int waterMl;

  /// Daily water target in ml — computed from the user's activity level.
  final int waterTargetMl;

  final void Function(int ml) onAdd;

  static const int _glassSize = 250; // ml per glass icon
  static const int _totalGlasses = 8;

  @override
  Widget build(BuildContext context) {
    final glasses = (waterMl / _glassSize).floor().clamp(0, _totalGlasses);
    final fraction = waterTargetMl > 0
        ? (waterMl / waterTargetMl).clamp(0.0, 1.0)
        : 0.0;

    return PastelCard(
      tint: PastelTint.sky,
      radius: 28,
      semanticLabel: 'Water $waterMl of $waterTargetMl millilitres',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CutoutImage(
                name: 'obj_drop.png',
                fallbackIcon: PhosphorIconsRegular.drop,
                width: 30,
                height: 30,
                alignment: Alignment.center,
              ),
              const SizedBox(width: 8),
              Text('Water', style: AppTextStyles.heading),
              const Spacer(),
              Text('$waterMl / $waterTargetMl ml', style: AppTextStyles.micro),
            ],
          ),
          const SizedBox(height: 14),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: fraction),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (_, value, __) => ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.7),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.ink),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 4,
                  children: List.generate(_totalGlasses, (i) {
                    final filled = i < glasses;
                    return Icon(
                      filled ? PhosphorIconsFill.drop : PhosphorIconsRegular.drop,
                      size: 20,
                      color: filled
                          ? AppColors.ink
                          : AppColors.ink.withValues(alpha: 0.3),
                    );
                  }),
                ),
              ),
              _AddChip(ml: 250, onAdd: onAdd),
              const SizedBox(width: 8),
              _AddChip(ml: 500, onAdd: onAdd),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddChip extends StatelessWidget {
  const _AddChip({required this.ml, required this.onAdd});

  final int ml;
  final void Function(int ml) onAdd;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add $ml millilitres of water',
      child: GestureDetector(
        onTap: () => onAdd(ml),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(Radius.circular(999)),
            ),
            child: Text('+$ml', style: AppTextStyles.bodyStrong.copyWith(fontSize: 13)),
          ),
        ),
      ),
    );
  }
}
