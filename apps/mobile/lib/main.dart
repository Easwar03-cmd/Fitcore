import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app.dart';
import 'core/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment-specific .env file.
  // .env.production must be created (never committed with real secrets).
  // In release builds the CI/CD pipeline injects .env.production at build time.
  const envFile = kReleaseMode ? '.env.production' : '.env';
  try {
    await dotenv.load(fileName: envFile);
  } catch (_) {
    // Fallback: .env.production missing in local release test — load default.
    if (kReleaseMode) await dotenv.load(fileName: '.env');
  }

  // Firebase must be initialised before any Firebase service is used.
  await Firebase.initializeApp();

  // Set up local notification channels and FCM background handler.
  await NotificationService.instance.init();

  // Request permission once on first launch (no-op on subsequent launches).
  await NotificationService.instance.requestPermissions();

  // Restore scheduled local notifications — a device reboot clears all pending
  // OS alarms so we must re-schedule them every time the app starts.
  await NotificationService.instance.restoreSchedules();

  final sentryDsn = dotenv.env['FLUTTER_SENTRY_DSN'] ?? '';
  // A valid Sentry DSN starts with "https://". Stub/placeholder values would
  // cause SentryFlutter.init() to throw an ArgumentError, which prevents
  // appRunner from being called and silently kills the app. Skip Sentry
  // entirely when the DSN is missing or not a real URL.
  final sentryEnabled = sentryDsn.startsWith('https://');

  if (sentryEnabled) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.tracesSampleRate = kReleaseMode ? 0.2 : 0.0;
        options.environment = kReleaseMode ? 'production' : 'debug';
        options.sendDefaultPii = false;
      },
      appRunner: () => runApp(const ProviderScope(child: ZenfitApp())),
    );
  } else {
    runApp(const ProviderScope(child: ZenfitApp()));
  }
}
