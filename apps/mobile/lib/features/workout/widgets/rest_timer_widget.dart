import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

// Must match _kRestDurationSec in workout_provider.dart
const _kRestDurationSec = 90;

/// Butter countdown card shown between sets (ring + time + skip).
class RestTimerWidget extends StatelessWidget {
  const RestTimerWidget({
    super.key,
    required this.secondsLeft,
    required this.onSkip,
  });

  final int secondsLeft;
  final VoidCallback onSkip;

  String get _formatted {
    final m = secondsLeft ~/ 60;
    final s = secondsLeft % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = (secondsLeft / _kRestDurationSec).clamp(0.0, 1.0);

    return Semantics(
      liveRegion: true,
      label: 'Rest. $secondsLeft seconds left.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.butter,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          children: [
            Text('Rest', style: AppTextStyles.heading),
            const SizedBox(height: 14),
            SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 10,
                      strokeCap: StrokeCap.round,
                      backgroundColor: Colors.white.withValues(alpha: 0.7),
                      valueColor: AlwaysStoppedAnimation(
                        secondsLeft <= 10 ? AppColors.coral : AppColors.ink,
                      ),
                    ),
                  ),
                  Text(_formatted, style: AppTextStyles.metricXL),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onSkip,
              icon: const Icon(PhosphorIconsRegular.skipForward, size: 18),
              label: const Text('Skip rest'),
            ),
          ],
        ),
      ),
    );
  }
}
