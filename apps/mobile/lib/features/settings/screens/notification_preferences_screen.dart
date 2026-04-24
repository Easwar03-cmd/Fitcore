import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/notification_preferences_provider.dart';

class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(notificationPreferencesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: prefsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (prefs) => _PrefsBody(prefs: prefs),
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _PrefsBody extends ConsumerWidget {
  const _PrefsBody({required this.prefs});
  final NotificationPreferences prefs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      children: [
        const _SectionHeader('Workout Reminders'),
        SwitchListTile(
          secondary: const Icon(Icons.fitness_center_rounded),
          title: const Text('Daily workout reminder'),
          subtitle: const Text('Reminds you to work out each day'),
          value: prefs.workoutReminderEnabled,
          onChanged: (val) => _update(
            ref,
            prefs.copyWith(workoutReminderEnabled: val),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: prefs.workoutReminderEnabled
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: _TimePickerTile(
            label: 'Reminder time',
            hour: prefs.workoutReminderHour,
            minute: prefs.workoutReminderMinute,
            onPicked: (hour, minute) => _update(
              ref,
              prefs.copyWith(
                workoutReminderHour: hour,
                workoutReminderMinute: minute,
              ),
            ),
          ),
          secondChild: const SizedBox.shrink(),
        ),
        const Divider(height: 1),
        const _SectionHeader('Nutrition Reminders'),
        SwitchListTile(
          secondary: const Icon(Icons.free_breakfast_rounded),
          title: const Text('Breakfast reminder'),
          subtitle: const Text('Daily at 8:00 AM — log your breakfast'),
          value: prefs.breakfastReminderEnabled,
          onChanged: (val) => _update(
            ref,
            prefs.copyWith(breakfastReminderEnabled: val),
          ),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.lunch_dining_rounded),
          title: const Text('Lunch reminder'),
          subtitle: const Text('Daily at 1:00 PM — log your lunch'),
          value: prefs.lunchReminderEnabled,
          onChanged: (val) => _update(
            ref,
            prefs.copyWith(lunchReminderEnabled: val),
          ),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.restaurant_menu_rounded),
          title: const Text('Dinner log reminder'),
          subtitle: const Text('Fires at 8 pm if no dinner is logged'),
          value: prefs.foodLogReminderEnabled,
          onChanged: (val) => _update(
            ref,
            prefs.copyWith(foodLogReminderEnabled: val),
          ),
        ),
        const Divider(height: 1),
        const _SectionHeader('Streak & Motivation'),
        SwitchListTile(
          secondary: const Icon(Icons.local_fire_department_rounded,
              color: AppColors.warning),
          title: const Text('Streak at-risk warning'),
          subtitle: const Text('Fires at 9 pm if your streak would break tonight'),
          value: prefs.streakWarningEnabled,
          onChanged: (val) => _update(
            ref,
            prefs.copyWith(streakWarningEnabled: val),
          ),
        ),
        const Divider(height: 1),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Weekly summary push notifications are sent every Sunday at 6 pm '
            'and cannot be disabled here — use your device settings to silence them.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Future<void> _update(WidgetRef ref, NotificationPreferences updated) async {
    await ref.read(notificationPreferencesProvider.notifier).save(updated);
    // Re-apply schedules whenever a preference changes
    await _applySchedules(updated);
  }

  Future<void> _applySchedules(NotificationPreferences p) async {
    final svc = NotificationService.instance;
    await Future.wait([
      svc.scheduleWorkoutReminder(
        enabled: p.workoutReminderEnabled,
        hour: p.workoutReminderHour,
        minute: p.workoutReminderMinute,
      ),
      svc.scheduleBreakfastReminder(enabled: p.breakfastReminderEnabled),
      svc.scheduleLunchReminder(enabled: p.lunchReminderEnabled),
      svc.scheduleFoodLogReminder(enabled: p.foodLogReminderEnabled),
      svc.scheduleStreakWarning(enabled: p.streakWarningEnabled),
    ]);
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

class _TimePickerTile extends StatelessWidget {
  const _TimePickerTile({
    required this.label,
    required this.hour,
    required this.minute,
    required this.onPicked,
  });

  final String label;
  final int hour;
  final int minute;
  final void Function(int hour, int minute) onPicked;

  String _formatted() {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final m = minute.toString().padLeft(2, '0');
    final period = hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 72, right: 16),
      title: Text(label),
      trailing: TextButton(
        onPressed: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: TimeOfDay(hour: hour, minute: minute),
          );
          if (picked != null) {
            onPicked(picked.hour, picked.minute);
          }
        },
        child: Text(
          _formatted(),
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
