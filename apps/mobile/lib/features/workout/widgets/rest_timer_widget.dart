import 'package:flutter/material.dart';

// Must match _kRestDurationSec in workout_provider.dart
const _kRestDurationSec = 90;

/// Circular countdown timer shown between sets.
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
    final theme = Theme.of(context);
    final progress = (secondsLeft / _kRestDurationSec).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Rest',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
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
                  backgroundColor:
                      theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(
                    secondsLeft <= 10
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                  ),
                ),
              ),
              Text(
                _formatted,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: onSkip,
          icon: const Icon(Icons.skip_next_rounded),
          label: const Text('Skip Rest'),
        ),
      ],
    );
  }
}
