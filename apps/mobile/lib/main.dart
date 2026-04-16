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

  final sentryDsn = dotenv.env['FLUTTER_SENTRY_DSN'] ?? '';

  await SentryFlutter.init(
    (options) {
      options.dsn = sentryDsn;
      // Only trace in production; zero overhead during development.
      options.tracesSampleRate = kReleaseMode ? 0.2 : 0.0;
      options.environment = kReleaseMode ? 'production' : 'debug';
      // Never send PII to Sentry.
      options.sendDefaultPii = false;
    },
    appRunner: () => runApp(const ProviderScope(child: ZenfitApp())),
  );
}
