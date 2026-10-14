import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/pastel_card.dart';

/// Current activity streak with a shield indicator.
///
/// Pure StatelessWidget — receives [streak] and [graceUsed] from parent.
class StreakCard extends StatelessWidget {
  const StreakCard({
    super.key,
    required this.streak,
    required this.graceUsed,
  });

  final int streak;
  final bool graceUsed;

  @override
  Widget build(BuildContext context) {
    final unit = streak == 1 ? 'day' : 'days';

    return PastelCard(
      tint: PastelTint.butter,
      padding: const EdgeInsets.all(14),
      semanticLabel:
          'Streak $streak $unit, shield ${graceUsed ? 'used' : 'ready'}',
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
                  child: const Icon(PhosphorIconsRegular.flame, size: 18),
                ),
                const Spacer(),
                Icon(
                  graceUsed
                      ? PhosphorIconsRegular.shield
                      : PhosphorIconsFill.shieldCheck,
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Streak', style: AppTextStyles.caption.copyWith(color: AppColors.ink)),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.8, end: 1.0),
              duration: const Duration(milliseconds: 500),
              curve: Curves.elasticOut,
              builder: (_, scale, child) => Transform.scale(
                scale: scale,
                alignment: Alignment.centerLeft,
                child: child,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('$streak', style: AppTextStyles.metricM),
                  const SizedBox(width: 4),
                  Text(unit,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.ink)),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              graceUsed ? 'Shield used' : 'Shield ready',
              style: AppTextStyles.micro,
            ),
          ],
        ),
      ),
    );
  }
}
