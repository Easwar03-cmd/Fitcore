import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/services/sync_queue_service.dart' show syncServiceProvider;
import 'core/services/sync_status_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'router/app_router.dart';

class ReviveApp extends ConsumerStatefulWidget {
  const ReviveApp({super.key});

  @override
  ConsumerState<ReviveApp> createState() => _ReviveAppState();
}

class _ReviveAppState extends ConsumerState<ReviveApp> {
  @override
  void initState() {
    super.initState();
    // Force the SyncService into existence so its AppLifecycleListener and
    // connectivity subscription are active for the full app lifetime.
    // Also seed the pending count so the banner shows immediately on launch.
    final service = ref.read(syncServiceProvider);
    ref.read(syncStatusProvider.notifier).refreshCount().then((_) {
      // Flush any items that are due immediately (e.g. from last session).
      service.flush();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
final themeMode = ref.watch(effectiveThemeModeProvider);
    return MaterialApp.router(
      title: 'Revive',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      themeAnimationDuration: const Duration(milliseconds: 400),
      themeAnimationCurve: Curves.easeInOut,
      routerConfig: router,
    );
  }
}
