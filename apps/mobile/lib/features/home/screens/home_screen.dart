import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../constants/app_routes.dart';
import '../../../core/services/health_service.dart';
import '../../../core/services/sync_queue_service.dart' show syncServiceProvider;
import '../../../core/services/sync_status_provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/circle_icon_button.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/nutrition/models/food_log.dart';
import '../../../features/nutrition/providers/nutrition_provider.dart';
import '../providers/home_provider.dart';
import '../widgets/ad_placeholders.dart';
import '../widgets/health_permissions_dialog.dart';
import '../widgets/home_dashboard.dart';

/// SharedPreferences key — written once the health permissions dialog is shown.
const _kHealthPermsPrompted = 'health_perms_prompted';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _popupVisible = false;

  @override
  void initState() {
    super.initState();
    // Schedule the permissions check after the first frame so GoRouter has
    // finished its transition and the Navigator is fully mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybePromptHealthPermissions();
    });
    // Show the popup ad after a short delay on cold start.
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _popupVisible = true);
    });
  }

  /// Shows a one-time dialog asking the user to grant health data access.
  /// The flag is written regardless of whether the user taps Allow or Skip so
  /// they are never prompted twice from within the app.
  Future<void> _maybePromptHealthPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kHealthPermsPrompted) == true) return;

    // Save immediately so a crash / force-quit doesn't re-prompt.
    await prefs.setBool(_kHealthPermsPrompted, true);

    if (!mounted) return;

    final granted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const HealthPermissionsDialog(),
    );

    if (granted == true) {
      final ok =
          await ref.read(healthServiceProvider).requestPermissions();
      if (ok && mounted) {
        // Refresh steps (and any other health data) now that we have access.
        ref.read(homeProvider.notifier).refresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userName = ref
            .watch(authProvider)
            .valueOrNull
            ?.user
            .name
            .split(' ')
            .first ??
        'there';

    final homeAsync = ref.watch(homeProvider);
    final logsAsync = ref.watch(foodLogsProvider);
    final syncStatus = ref.watch(syncStatusProvider);

    // Once food logs are known, update streak without triggering a rebuild loop.
    // Also surface any load error as a SnackBar.
    ref.listen<AsyncValue<DayLogs>>(foodLogsProvider, (prev, next) {
      if (next is AsyncData<DayLogs>) {
        ref.read(homeProvider.notifier).updateStreakForToday(
              hasLogs: next.value.logs.isNotEmpty,
            );
      } else if (next is AsyncError && prev is! AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not load nutrition data. Pull down to retry.'),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                GreetingHeader(
                  name: userName,
                  greeting: 'Hi',
                  onAvatarTap: () => context.push(AppRoutes.profile),
                  trailing: [
                    CircleIconButton(
                      icon: PhosphorIconsRegular.bell,
                      semanticLabel: 'Notification settings',
                      showDot: syncStatus.pendingCount > 0,
                      onPressed: () =>
                          context.push(AppRoutes.notificationPrefs),
                    ),
                  ],
                ),
                if (syncStatus.pendingCount > 0)
                  SyncBanner(
                    pendingCount: syncStatus.pendingCount,
                    isSyncing: syncStatus.isSyncing,
                    onSync: () => ref.read(syncServiceProvider).flush(),
                  ),
                Expanded(
                  child: homeAsync.when(
                    loading: () => const HomeSkeleton(),
                    error: (e, _) => HomeErrorView(
                      message: e.toString(),
                      onRetry: () => ref.read(homeProvider.notifier).refresh(),
                    ),
                    data: (home) => HomeDashboard(
                      home: home,
                      totals: logsAsync.valueOrNull?.totals ?? DayTotals.zero,
                      onRefresh: () async {
                        await ref.read(homeProvider.notifier).refresh();
                      },
                      onAddWater: (ml) =>
                          ref.read(homeProvider.notifier).addWater(ml),
                    ),
                  ),
                ),
              ],
            ),
            // Popup ad — appears after a 2-second delay, bottom-left anchored.
            if (_popupVisible)
              const Positioned(
                bottom: 16,
                left: 16,
                child: AdPopupPlaceholder(),
              ),
          ],
        ),
      ),
    );
  }
}
