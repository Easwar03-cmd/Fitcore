import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/cutout_image.dart';

/// Sky hero panel used at the top of login / signup: lockup, display title,
/// subtitle and an inset photo on the right.
class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.imageName = 'hero_home_workout.jpg',
  });

  final String title;
  final String subtitle;
  final String imageName;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: AppColors.sky,
        borderRadius: BorderRadius.circular(AppRadius.hero),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 10, 18),
      child: Row(
        children: [
          Expanded(
            flex: 11,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BrandLockup(markSize: 34),
                const Spacer(),
                Semantics(
                  header: true,
                  child: Text(title,
                      style: AppTextStyles.title.copyWith(fontSize: 24),
                      maxLines: 2),
                ),
                const SizedBox(height: 4),
                Text(subtitle,
                    style:
                        AppTextStyles.caption.copyWith(color: AppColors.ink),
                    maxLines: 2),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 8,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.hero - 8),
              child: SizedBox.expand(
                child: CutoutImage(
                  name: imageName,
                  fallbackIcon: Icons.fitness_center_rounded,
                  alignment: Alignment.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
