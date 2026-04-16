import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;


// ─── Notification IDs (stable — used to cancel/reschedule) ───────────────────

const _kWorkoutReminderId = 10;
const _kFoodLogReminderId = 11;
const _kStreakWarningId = 12;
const _kSyncFailedBaseId = 20; // 20–29 reserved for sync-failure alerts

// ─── Android notification channel IDs ────────────────────────────────────────

const _kDefaultChannelId = 'zenfit_default';
const _kDefaultChannelName = 'Zenfit Notifications';
const _kRemindersChannelId = 'zenfit_reminders';
const _kRemindersChannelName = 'Daily Reminders';

// ─── Top-level FCM background handler (must be top-level function) ────────────

@pragma('vm:entry-point')
Future<void> _fcmBackgroundHandler(RemoteMessage message) async {
  // Background FCM messages that carry only data (no notification block) are
  // handled here. Messages that already have a `notification` block are shown
  // automatically by the OS — no action needed.
}

// ─── NotificationService ─────────────────────────────────────────────────────

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _flnp = FlutterLocalNotificationsPlugin();
  bool _initialised = false;

  // ── Initialisation ─────────────────────────────────────────────────────────

  /// Call once from [main()] after Firebase.initializeApp().
  Future<void> init() async {
    if (_initialised) return;

    tz.initializeTimeZones();

    // Local notifications init
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false, // we request separately below
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _flnp.initialize(
      const InitializationSettings(android: androidInit, iOS: darwinInit),
    );

    // Android notification channels
    await _flnp
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _kDefaultChannelId,
          _kDefaultChannelName,
          importance: Importance.defaultImportance,
        ));
    await _flnp
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _kRemindersChannelId,
          _kRemindersChannelName,
          importance: Importance.high,
        ));

    // FCM background handler registration
    FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);

    // Show FCM foreground messages as local notifications
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    _initialised = true;
  }

  // ── Permission request ─────────────────────────────────────────────────────

  Future<bool> requestPermissions() async {
    // iOS / macOS / Android 13+
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Android 13+ local notifications exact alarm permission
    if (!kIsWeb) {
      await _flnp
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _flnp
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestExactAlarmsPermission();
    }

    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  // ── FCM token registration ─────────────────────────────────────────────────

  /// Fetches the current FCM token and POSTs it to the backend.
  /// Must be called after a successful login / session restore.
  /// [accessToken] is the JWT bearer token.
  Future<void> registerFcmToken(String accessToken, String apiBaseUrl) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _postToken(token, accessToken, apiBaseUrl);

      // Refresh when the token rotates
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        _postToken(newToken, accessToken, apiBaseUrl);
      });
    } catch (e) {
      debugPrint('[NotificationService] registerFcmToken error: $e');
    }
  }

  /// Clears the FCM token on the backend (call on logout).
  Future<void> clearFcmToken(String accessToken, String apiBaseUrl) async {
    try {
      await _postToken(null, accessToken, apiBaseUrl);
    } catch (_) {}
  }

  Future<void> _postToken(
    String? token,
    String accessToken,
    String apiBaseUrl,
  ) async {
    final dio = Dio(BaseOptions(
      baseUrl: apiBaseUrl,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      connectTimeout: const Duration(seconds: 10),
    ));
    await dio.post('/api/v1/user/fcm-token', data: {'token': token});
  }

  // ── Local notification scheduling ─────────────────────────────────────────

  /// Schedule a daily workout reminder at [hour]:[minute] local time.
  /// Pass [enabled] = false to cancel it.
  Future<void> scheduleWorkoutReminder({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    await _flnp.cancel(_kWorkoutReminderId);
    if (!enabled) return;

    final scheduledTime = _nextOccurrence(hour, minute);
    await _flnp.zonedSchedule(
      _kWorkoutReminderId,
      "Time to move! 💪",
      "Don't forget your workout today. Consistency is everything.",
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _kRemindersChannelId,
          _kRemindersChannelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(sound: 'default'),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // repeat daily
    );
  }

  /// Schedule a food log reminder at 20:00 local time.
  /// The app should call [cancelFoodLogReminder] once dinner is logged.
  Future<void> scheduleFoodLogReminder({required bool enabled}) async {
    await _flnp.cancel(_kFoodLogReminderId);
    if (!enabled) return;

    final scheduledTime = _nextOccurrence(20, 0); // 8pm
    await _flnp.zonedSchedule(
      _kFoodLogReminderId,
      "Log your dinner 🍽️",
      "You haven't logged dinner yet. Keep your nutrition on track!",
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _kRemindersChannelId,
          _kRemindersChannelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(sound: 'default'),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Call this when dinner is logged so the 8pm notification doesn't fire.
  Future<void> cancelFoodLogReminder() => _flnp.cancel(_kFoodLogReminderId);

  /// Schedule a streak-at-risk warning at 21:00 local time.
  /// The app should call [cancelStreakWarning] once the streak condition is met.
  Future<void> scheduleStreakWarning({required bool enabled}) async {
    await _flnp.cancel(_kStreakWarningId);
    if (!enabled) return;

    final scheduledTime = _nextOccurrence(21, 0); // 9pm
    await _flnp.zonedSchedule(
      _kStreakWarningId,
      "Your streak is at risk! 🔥",
      "Log something today to keep your streak alive. You're so close!",
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _kRemindersChannelId,
          _kRemindersChannelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(sound: 'default'),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Call when the user has met their daily streak requirement.
  Future<void> cancelStreakWarning() => _flnp.cancel(_kStreakWarningId);

  // ── Sync failure alerts ────────────────────────────────────────────────────

  /// Shows an immediate notification when a queued item has permanently failed
  /// after exhausting all retry attempts. Uses IDs 20–29 cycling so up to
  /// 10 distinct failures can be visible at once without clobbering each other.
  void showSyncFailedNotification(String endpoint) {
    // Derive a stable-ish ID in the reserved range so failures don't stack
    // unboundedly; oldest slot is reused after 10 failures.
    final notifId = _kSyncFailedBaseId + (endpoint.hashCode.abs() % 10);

    // Fire-and-forget — we're often on a background isolate path.
    _flnp.show(
      notifId,
      'Data may not be saved',
      'A record could not be synced after several attempts. '
          'Check your connection and open Zenfit to retry.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _kDefaultChannelId,
          _kDefaultChannelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(sound: 'default'),
      ),
    );
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Returns the next TZDateTime occurrence at [hour]:[minute] local time.
  /// If that time has already passed today it returns tomorrow's occurrence.
  tz.TZDateTime _nextOccurrence(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _flnp.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _kDefaultChannelId,
          _kDefaultChannelName,
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
