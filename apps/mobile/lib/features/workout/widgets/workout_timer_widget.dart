import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/circle_icon_button.dart';

// ─── In-page timer card ───────────────────────────────────────────────────────

class WorkoutTimerWidget extends StatelessWidget {
  const WorkoutTimerWidget({
    super.key,
    required this.remainingSeconds,
    required this.isPaused,
    required this.onSetTimer,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  final int? remainingSeconds; // null = no timer set
  final bool isPaused;
  final VoidCallback onSetTimer;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  String get _label {
    final r = remainingSeconds!;
    final h = r ~/ 3600;
    final m = (r % 3600) ~/ 60;
    final s = r % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (remainingSeconds == null) {
      return OutlinedButton.icon(
        onPressed: onSetTimer,
        icon: const Icon(PhosphorIconsRegular.timer),
        label: const Text('Start Workout Timer'),
      );
    }

    final isLastMinute = remainingSeconds! <= 60;
    final tint = isLastMinute ? AppColors.butter : AppColors.sky;

    return Semantics(
      label: '${isPaused ? 'Timer paused' : 'Workout timer'} $_label',
      child: Container(
        decoration: BoxDecoration(
          color: isPaused ? AppColors.surfaceMuted : tint,
          borderRadius: BorderRadius.circular(28),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 14, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPaused ? 'Timer paused' : 'Workout timer',
                    style: AppTextStyles.caption.copyWith(color: AppColors.ink),
                  ),
                  Text(_label, style: AppTextStyles.metricL),
                ],
              ),
            ),
            CircleIconButton(
              icon: isPaused ? PhosphorIconsFill.play : PhosphorIconsFill.pause,
              semanticLabel: isPaused ? 'Resume timer' : 'Pause timer',
              onPressed: isPaused ? onResume : onPause,
            ),
            const SizedBox(width: 8),
            CircleIconButton(
              icon: PhosphorIconsFill.stop,
              semanticLabel: 'Stop timer',
              onPressed: onStop,
              selected: true,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Timer picker bottom sheet ────────────────────────────────────────────────

class WorkoutTimerPickerSheet extends StatelessWidget {
  const WorkoutTimerPickerSheet({super.key, required this.onSelect});

  final void Function(Duration) onSelect;

  static const _presets = [
    ('20 min', Duration(minutes: 20)),
    ('30 min', Duration(minutes: 30)),
    ('45 min', Duration(minutes: 45)),
    ('1 hr', Duration(hours: 1)),
    ('1h 30m', Duration(hours: 1, minutes: 30)),
    ('2 hr', Duration(hours: 2)),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(PhosphorIconsRegular.timer),
                const SizedBox(width: 10),
                Text('Set Workout Timer', style: AppTextStyles.heading),
              ],
            ),
            const SizedBox(height: 6),
            Text('Tap a duration to start the countdown.',
                style: AppTextStyles.caption),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.4,
              children: _presets.map(((String label, Duration dur) preset) {
                return _PresetTile(
                  label: preset.$1,
                  // pop first, then start timer — fixes sheet staying open
                  onTap: () {
                    Navigator.of(context).pop();
                    onSelect(preset.$2);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.sky,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Center(child: Text(label, style: AppTextStyles.bodyStrong)),
      ),
    );
  }
}
