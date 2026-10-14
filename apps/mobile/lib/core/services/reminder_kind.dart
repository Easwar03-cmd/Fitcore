/// Every daily local reminder the app can schedule.
///
/// [prefix] names the SharedPreferences keys; the enabled/hour/minute keys of
/// the original five reminders keep their historical names so existing
/// settings survive the move to user-editable times.
enum ReminderKind {
  workout(
    id: 10,
    enabledKey: 'notif_workout_enabled',
    hourKey: 'notif_workout_hour',
    minuteKey: 'notif_workout_minute',
    defaultHour: 9,
    defaultMinute: 0,
    label: 'Workout',
    description: 'Reminds you to work out',
    title: 'Time to move! 💪',
    body: "Don't forget your workout today. Consistency is everything.",
  ),
  breakfast(
    id: 13,
    enabledKey: 'notif_breakfast_enabled',
    hourKey: 'notif_breakfast_hour',
    minuteKey: 'notif_breakfast_minute',
    defaultHour: 8,
    defaultMinute: 0,
    label: 'Breakfast',
    description: 'Log your breakfast',
    title: 'Good morning! Log your breakfast 🍳',
    body: "Start your day right — log what you're eating for breakfast.",
  ),
  lunch(
    id: 14,
    enabledKey: 'notif_lunch_enabled',
    hourKey: 'notif_lunch_hour',
    minuteKey: 'notif_lunch_minute',
    defaultHour: 13,
    defaultMinute: 0,
    label: 'Lunch',
    description: 'Log your lunch',
    title: "Lunchtime! Don't forget to log 🥗",
    body: 'Keep your nutrition on track — log your lunch now.',
  ),
  dinner(
    id: 11,
    enabledKey: 'notif_food_log_enabled',
    hourKey: 'notif_dinner_hour',
    minuteKey: 'notif_dinner_minute',
    defaultHour: 20,
    defaultMinute: 0,
    label: 'Dinner',
    description: 'Log your dinner',
    title: 'Log your dinner 🍽️',
    body: "You haven't logged dinner yet. Keep your nutrition on track!",
  ),
  streak(
    id: 12,
    enabledKey: 'notif_streak_warning_enabled',
    hourKey: 'notif_streak_hour',
    minuteKey: 'notif_streak_minute',
    defaultHour: 21,
    defaultMinute: 0,
    label: 'Streak',
    description: 'Warns you before your streak breaks',
    title: 'Your streak is at risk! 🔥',
    body: "Log something today to keep your streak alive. You're so close!",
  );

  const ReminderKind({
    required this.id,
    required this.enabledKey,
    required this.hourKey,
    required this.minuteKey,
    required this.defaultHour,
    required this.defaultMinute,
    required this.label,
    required this.description,
    required this.title,
    required this.body,
  });

  /// Stable local-notification id (used to cancel / reschedule).
  final int id;
  final String enabledKey;
  final String hourKey;
  final String minuteKey;
  final int defaultHour;
  final int defaultMinute;
  final String label;
  final String description;
  final String title;
  final String body;
}
