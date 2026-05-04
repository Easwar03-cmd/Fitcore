import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fitness_center_rounded, size: 64, color: AppColors.primary),
            SizedBox(height: 24),
            CircularProgressIndicator(color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
