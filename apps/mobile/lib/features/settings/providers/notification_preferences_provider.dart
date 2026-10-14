import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/notification_service.dart';
import '../../../core/services/reminder_kind.dart';

/// One reminder: on/off and the time of day it fires.
class ReminderSetting {
  const ReminderSetting({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  final bool enabled;
  final int hour;
  final int minute;

  ReminderSetting copyWith({bool? enabled, int? hour, int? minute}) =>
      ReminderSetting(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
      );
}

class NotificationPreferences {
  const NotificationPreferences(this.reminders);

  final Map<ReminderKind, ReminderSetting> reminders;

  ReminderSetting of(ReminderKind k) => reminders[k]!;

  bool get allEnabled => reminders.values.every((r) => r.enabled);

  NotificationPreferences withSetting(ReminderKind k, ReminderSetting s) =>
      NotificationPreferences({...reminders, k: s});

  NotificationPreferences mapAll(ReminderSetting Function(ReminderSetting) f) =>
      NotificationPreferences({
        for (final e in reminders.entries) e.key: f(e.value),
      });
}

class NotificationPreferencesNotifier
    extends AsyncNotifier<NotificationPreferences> {
  @override
  Future<NotificationPreferences> build() async {
    final prefs = await SharedPreferences.getInstance();
    return NotificationPreferences({
      for (final k in ReminderKind.values)
        k: ReminderSetting(
          enabled: prefs.getBool(k.enabledKey) ?? true,
          hour: prefs.getInt(k.hourKey) ?? k.defaultHour,
          minute: prefs.getInt(k.minuteKey) ?? k.defaultMinute,
        ),
    });
  }

  /// Persists [updated] and re-applies every OS schedule.
  Future<void> save(NotificationPreferences updated) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      for (final e in updated.reminders.entries) ...[
        prefs.setBool(e.key.enabledKey, e.value.enabled),
        prefs.setInt(e.key.hourKey, e.value.hour),
        prefs.setInt(e.key.minuteKey, e.value.minute),
      ],
    ]);
    state = AsyncData(updated);
    await NotificationService.instance.restoreSchedules();
  }
}

final notificationPreferencesProvider = AsyncNotifierProvider<
    NotificationPreferencesNotifier,
    NotificationPreferences>(NotificationPreferencesNotifier.new);
