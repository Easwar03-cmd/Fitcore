import 'package:flutter/material.dart';

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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (remainingSeconds == null) {
      return OutlinedButton.icon(
        onPressed: onSetTimer,
        icon: const Icon(Icons.timer_outlined),
        label: const Text('Start Workout Timer'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: cs.primary.withValues(alpha: 0.4), width: 1.5),
          foregroundColor: cs.primary,
        ),
      );
    }

    final r = remainingSeconds!;
    final isLastMinute = r <= 60;
    final activeColor = isLastMinute ? Colors.orange : cs.primary;
    final timeColor = isPaused ? cs.onSurface.withValues(alpha: 0.4) : activeColor;

    return Container(
      decoration: BoxDecoration(
        color: activeColor.withValues(alpha: isPaused ? 0.05 : 0.08),
        border: Border.all(
          color: activeColor.withValues(alpha: isPaused ? 0.2 : 0.35),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Icon(
            isPaused ? Icons.timer_off_rounded : Icons.timer_rounded,
            color: timeColor,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPaused ? 'Timer Paused' : 'Workout Timer',
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                Text(
                  _label,
                  style: tt.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: timeColor,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          _ControlBtn(
            icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            color: cs.primary,
            onTap: isPaused ? onResume : onPause,
          ),
          const SizedBox(width: 8),
          _ControlBtn(
            icon: Icons.stop_rounded,
            color: cs.error,
            onTap: onStop,
          ),
        ],
      ),
    );
  }
}

class _ControlBtn extends StatelessWidget {
  const _ControlBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: color),
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timer_rounded, color: cs.primary),
                const SizedBox(width: 10),
                Text(
                  'Set Workout Timer',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Tap a duration to start the countdown.',
              style: tt.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.5)),
            ),
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
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: cs.primary.withValues(alpha: 0.35), width: 1.5),
          borderRadius: BorderRadius.circular(12),
          color: cs.primary.withValues(alpha: 0.07),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: cs.primary,
          ),
        ),
      ),
    );
  }
}
