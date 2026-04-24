import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Keys ─────────────────────────────────────────────────────────────────────

const _kWorkoutEnabled = 'notif_workout_enabled';
const _kWorkoutHour = 'notif_workout_hour';
const _kWorkoutMinute = 'notif_workout_minute';
const _kFoodLogEnabled = 'notif_food_log_enabled';
const _kStreakWarningEnabled = 'notif_streak_warning_enabled';
const _kBreakfastEnabled = 'notif_breakfast_enabled';
const _kLunchEnabled = 'notif_lunch_enabled';

// ─── Model ────────────────────────────────────────────────────────────────────

class NotificationPreferences {
  final bool workoutReminderEnabled;
  final int workoutReminderHour;
  final int workoutReminderMinute;
  final bool breakfastReminderEnabled;
  final bool lunchReminderEnabled;
  final bool foodLogReminderEnabled;
  final bool streakWarningEnabled;

  const NotificationPreferences({
    required this.workoutReminderEnabled,
    required this.workoutReminderHour,
    required this.workoutReminderMinute,
    required this.breakfastReminderEnabled,
    required this.lunchReminderEnabled,
    required this.foodLogReminderEnabled,
    required this.streakWarningEnabled,
  });

  /// Default preferences used on first launch.
  const NotificationPreferences.defaults()
      : workoutReminderEnabled = true,
        workoutReminderHour = 9,
        workoutReminderMinute = 0,
        breakfastReminderEnabled = true,
        lunchReminderEnabled = true,
        foodLogReminderEnabled = true,
        streakWarningEnabled = true;

  NotificationPreferences copyWith({
    bool? workoutReminderEnabled,
    int? workoutReminderHour,
    int? workoutReminderMinute,
    bool? breakfastReminderEnabled,
    bool? lunchReminderEnabled,
    bool? foodLogReminderEnabled,
    bool? streakWarningEnabled,
  }) =>
      NotificationPreferences(
        workoutReminderEnabled: workoutReminderEnabled ?? this.workoutReminderEnabled,
        workoutReminderHour: workoutReminderHour ?? this.workoutReminderHour,
        workoutReminderMinute: workoutReminderMinute ?? this.workoutReminderMinute,
        breakfastReminderEnabled: breakfastReminderEnabled ?? this.breakfastReminderEnabled,
        lunchReminderEnabled: lunchReminderEnabled ?? this.lunchReminderEnabled,
        foodLogReminderEnabled: foodLogReminderEnabled ?? this.foodLogReminderEnabled,
        streakWarningEnabled: streakWarningEnabled ?? this.streakWarningEnabled,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class NotificationPreferencesNotifier
    extends AsyncNotifier<NotificationPreferences> {
  @override
  Future<NotificationPreferences> build() async {
    final prefs = await SharedPreferences.getInstance();
    return NotificationPreferences(
      workoutReminderEnabled: prefs.getBool(_kWorkoutEnabled) ?? true,
      workoutReminderHour: prefs.getInt(_kWorkoutHour) ?? 9,
      workoutReminderMinute: prefs.getInt(_kWorkoutMinute) ?? 0,
      breakfastReminderEnabled: prefs.getBool(_kBreakfastEnabled) ?? true,
      lunchReminderEnabled: prefs.getBool(_kLunchEnabled) ?? true,
      foodLogReminderEnabled: prefs.getBool(_kFoodLogEnabled) ?? true,
      streakWarningEnabled: prefs.getBool(_kStreakWarningEnabled) ?? true,
    );
  }

  Future<void> save(NotificationPreferences updated) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setBool(_kWorkoutEnabled, updated.workoutReminderEnabled),
      prefs.setInt(_kWorkoutHour, updated.workoutReminderHour),
      prefs.setInt(_kWorkoutMinute, updated.workoutReminderMinute),
      prefs.setBool(_kBreakfastEnabled, updated.breakfastReminderEnabled),
      prefs.setBool(_kLunchEnabled, updated.lunchReminderEnabled),
      prefs.setBool(_kFoodLogEnabled, updated.foodLogReminderEnabled),
      prefs.setBool(_kStreakWarningEnabled, updated.streakWarningEnabled),
    ]);
    state = AsyncData(updated);
  }
}

final notificationPreferencesProvider = AsyncNotifierProvider<
    NotificationPreferencesNotifier,
    NotificationPreferences>(NotificationPreferencesNotifier.new);
