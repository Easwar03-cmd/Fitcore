import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/services/reminder_kind.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/pastel_card.dart';
import '../providers/notification_preferences_provider.dart';

String formatTime(int hour, int minute) {
  final h = hour % 12 == 0 ? 12 : hour % 12;
  final m = minute.toString().padLeft(2, '0');
  return '$h:$m ${hour < 12 ? 'AM' : 'PM'}';
}

/// Pick a reminder from the dropdown, pick its time, and only that reminder
/// changes — so each activity can have its own time.
class QuickSetCard extends StatefulWidget {
  const QuickSetCard({
    super.key,
    required this.prefs,
    required this.onSet,
    required this.onToggleAll,
  });

  final NotificationPreferences prefs;
  final void Function(ReminderKind kind, int hour, int minute) onSet;
  final ValueChanged<bool> onToggleAll;

  @override
  State<QuickSetCard> createState() => _QuickSetCardState();
}

class _QuickSetCardState extends State<QuickSetCard> {
  ReminderKind _kind = ReminderKind.breakfast;

  @override
  Widget build(BuildContext context) {
    final current = widget.prefs.of(_kind);
    return PastelCard(
      tint: PastelTint.sky,
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Set a reminder time', style: AppTextStyles.heading),
          const SizedBox(height: 4),
          Text(
            'Choose the reminder, then its time. Each reminder keeps its own time.',
            style: AppTextStyles.caption.copyWith(color: AppColors.ink),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ReminderKind>(
            initialValue: _kind,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Reminder',
              filled: true,
              fillColor: Colors.white,
            ),
            items: [
              for (final k in ReminderKind.values)
                DropdownMenuItem(value: k, child: Text(k.label)),
            ],
            onChanged: (k) => setState(() => _kind = k ?? _kind),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                onPressed: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime:
                        TimeOfDay(hour: current.hour, minute: current.minute),
                  );
                  if (t != null) widget.onSet(_kind, t.hour, t.minute);
                },
                icon: const Icon(PhosphorIconsBold.clock, size: 18),
                label: Text(formatTime(current.hour, current.minute)),
              ),
              const Spacer(),
              Text('All on', style: AppTextStyles.bodyStrong),
              Switch(
                value: widget.prefs.allEnabled,
                onChanged: widget.onToggleAll,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
