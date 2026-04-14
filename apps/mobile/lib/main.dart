import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import 'app.dart';
import 'core/services/notification_service.dart';

final log = Logger();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // Firebase must be initialised before any Firebase service is used.
  await Firebase.initializeApp();

  // Set up local notification channels and FCM background handler.
  await NotificationService.instance.init();

  // Request permission once on first launch (no-op on subsequent launches).
  await NotificationService.instance.requestPermissions();

  runApp(const ProviderScope(child: FitCoreApp()));
}
