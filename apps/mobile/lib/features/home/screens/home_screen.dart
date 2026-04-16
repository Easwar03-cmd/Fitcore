import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../constants/app_routes.dart';
import '../../../core/services/health_service.dart';
import '../../../core/services/sync_queue_service.dart' show syncServiceProvider;
import '../../../core/services/sync_status_provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/nutrition/models/food_log.dart';
import '../../../features/nutrition/providers/nutrition_provider.dart';
import '../models/home_state.dart';
import '../providers/home_provider.dart';
import '../widgets/ad_placeholders.dart';
import '../widgets/calorie_ring.dart';
import '../widgets/macro_bars.dart';
import '../widgets/step_counter_card.dart';
import '../widgets/streak_card.dart';
import '../widgets/water_tracker_card.dart';

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
      builder: (_) => const _HealthPermissionsDialog(),
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

    final userInitial = ref
            .watch(authProvider)
            .valueOrNull
            ?.user
            .name
            .isNotEmpty ==
        true
        ? ref.watch(authProvider).valueOrNull!.user.name[0].toUpperCase()
        : '?';

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: GestureDetector(
            onTap: () => context.push(AppRoutes.profile),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withAlpha(40),
              child: Text(
                userInitial,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ),
        title: Text(
          'Hi, $userName 👋',
          style: AppTextStyles.titleLarge
              .copyWith(color: AppColors.onBackground),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Social',
            onPressed: () => context.push(AppRoutes.social),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (syncStatus.pendingCount > 0)
                _SyncBanner(
                  pendingCount: syncStatus.pendingCount,
                  isSyncing: syncStatus.isSyncing,
                  onSync: () =>
                      ref.read(syncServiceProvider).flush(),
                ),
              Expanded(
                child: homeAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => _ErrorView(
                    message: e.toString(),
                    onRetry: () => ref.read(homeProvider.notifier).refresh(),
                  ),
                  data: (home) => _Dashboard(
                    home: home,
                    logsAsync: logsAsync,
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
    );
  }
}

// ── Sync banner ───────────────────────────────────────────────────────────────

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({
    required this.pendingCount,
    required this.isSyncing,
    required this.onSync,
  });

  final int pendingCount;
  final bool isSyncing;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withAlpha(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            if (isSyncing)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.cloud_off_rounded,
                  size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isSyncing
                    ? 'Syncing…'
                    : '$pendingCount item${pendingCount == 1 ? '' : 's'} '
                        'waiting to sync',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.primary),
              ),
            ),
            if (!isSyncing)
              TextButton(
                onPressed: onSync,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Sync now'),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Health permissions dialog ─────────────────────────────────────────────────

class _HealthPermissionsDialog extends StatelessWidget {
  const _HealthPermissionsDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.favorite_rounded,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Connect Health Data',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Zenfit would like to read and write:',
            style: TextStyle(fontSize: 14),
          ),
          SizedBox(height: 14),
          _PermissionRow(Icons.directions_walk_rounded, 'Steps',
              'Auto-fill your daily step count'),
          _PermissionRow(Icons.favorite_border_rounded, 'Heart Rate',
              'Show resting HR on your dashboard'),
          _PermissionRow(Icons.bedtime_outlined, 'Sleep',
              'Track sleep duration and stages'),
          _PermissionRow(Icons.monitor_weight_outlined, 'Weight',
              'Read body weight from your health app'),
          _PermissionRow(Icons.fitness_center_rounded, 'Workouts',
              'Write completed sessions back to your health app'),
          SizedBox(height: 10),
          Text(
            'You can change these permissions any time in your device settings.',
            style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Skip'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Allow'),
        ),
      ],
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow(this.icon, this.title, this.subtitle);

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dashboard body ────────────────────────────────────────────────────────────

class _Dashboard extends StatelessWidget {
  const _Dashboard({
    required this.home,
    required this.logsAsync,
    required this.onRefresh,
    required this.onAddWater,
  });

  final HomeDashboardState home;
  final AsyncValue<DayLogs> logsAsync;
  final Future<void> Function() onRefresh;
  final void Function(int ml) onAddWater;

  @override
  Widget build(BuildContext context) {
    final totals = logsAsync.valueOrNull?.totals ?? DayTotals.zero;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Banner ad ─────────────────────────────────────────────────
            const AdBannerPlaceholder(),

            // ── Calorie ring ──────────────────────────────────────────────
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
              child: Column(
                children: [
                  CalorieRing(
                    consumed: totals.calories,
                    target: home.tdee,
                    size: 200,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Daily target · ${home.tdee} kcal',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.08, end: 0, curve: Curves.easeOut),

            const SizedBox(height: 14),

            // ── Macro bars ────────────────────────────────────────────────
            AppCard(
              child: MacroBars(
                totals: totals,
                tdee: home.tdee,
                goal: home.goal,
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: 80.ms)
                .slideY(begin: 0.08, end: 0, curve: Curves.easeOut),

            const SizedBox(height: 14),

            // ── Steps + Streak row ────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: AppCard(
                    child: StepCounterCard(steps: home.steps),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppCard(
                    child: StreakCard(
                      streak: home.streak,
                      graceUsed: home.graceUsed,
                    ),
                  ),
                ),
              ],
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: 160.ms)
                .slideY(begin: 0.08, end: 0, curve: Curves.easeOut),

            const SizedBox(height: 14),

            // ── Water tracker ─────────────────────────────────────────────
            AppCard(
              child: WaterTrackerCard(
                waterMl: home.waterMl,
                onAdd: onAddWater,
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: 240.ms)
                .slideY(begin: 0.08, end: 0, curve: Curves.easeOut),
          ],
        ),
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 48,
              color: AppColors.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              message.replaceFirst('Exception: ', ''),
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
