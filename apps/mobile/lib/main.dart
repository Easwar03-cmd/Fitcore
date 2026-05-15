import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'app.dart';
import 'core/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment-specific .env file.
  // In release builds the CI/CD pipeline injects .env.production at build time.
  const envFile = kReleaseMode ? '.env.production' : '.env';
  try {
    await dotenv.load(fileName: envFile);
  } catch (_) {
    if (kReleaseMode) await dotenv.load(fileName: '.env');
  }

  // Firebase must be initialised before any Firebase service is used.
  await Firebase.initializeApp();

  // Crashlytics: forward all Flutter framework errors automatically.
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  // Crashlytics: catch errors that fall outside the Flutter framework
  // (e.g. errors in platform channels, isolates).
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  // Disable Crashlytics data collection in debug builds.
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(kReleaseMode);

  // Analytics: disable data collection in debug builds.
  await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(kReleaseMode);

  await MobileAds.instance.initialize();

  // Set up local notification channels and FCM background handler.
  await NotificationService.instance.init();

  // Request permission once on first launch (no-op on subsequent launches).
  await NotificationService.instance.requestPermissions();

  // Restore scheduled local notifications — a device reboot clears all pending
  // OS alarms so we must re-schedule them every time the app starts.
  await NotificationService.instance.restoreSchedules();

  runApp(const ProviderScope(child: ReviveApp()));
}
