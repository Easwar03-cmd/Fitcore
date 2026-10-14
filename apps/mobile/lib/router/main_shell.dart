import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../constants/app_routes.dart';
import '../core/services/sync_queue_service.dart' show syncServiceProvider;
import '../core/widgets/floating_nav.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  static const _tabs = [
    AppRoutes.home,
    AppRoutes.nutrition,
    AppRoutes.workout,
    AppRoutes.progress,
    AppRoutes.community,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(syncServiceProvider).flush();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(syncServiceProvider).flush();
    }
  }

  /// Fallback for system back when nothing in the navigators can pop: any tab
  /// other than Home goes to Home first; only Home lets the app close.
  @override
  Future<bool> didPopRoute() async {
    if (!mounted) return false;
    if (_tabIndex(context) != 0) {
      context.go(AppRoutes.home);
      return true;
    }
    return false;
  }

  int _tabIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i])) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final onHome = _tabIndex(context) == 0;

    return NotificationListener<NavigationNotification>(
      // Android predictive back: tell the OS Flutter handles back whenever we
      // are not on Home, otherwise the OS closes the app directly.
      onNotification: (n) {
        SystemNavigator.setFrameworkHandlesBack(!onHome || n.canHandlePop);
        return true;
      },
      child: PopScope(
        // Allow system back to exit only when already on the Home tab.
        canPop: onHome,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) context.go(AppRoutes.home);
        },
        child: Scaffold(
          body: widget.child,
          bottomNavigationBar: FloatingNav(
            currentIndex: _tabIndex(context),
            onTap: (i) => context.go(_tabs[i]),
            items: const [
              FloatingNavItem(
                icon: PhosphorIconsRegular.house,
                activeIcon: PhosphorIconsFill.house,
                label: 'Home',
              ),
              FloatingNavItem(
                icon: PhosphorIconsRegular.forkKnife,
                activeIcon: PhosphorIconsFill.forkKnife,
                label: 'Nutrition',
              ),
              FloatingNavItem(
                icon: PhosphorIconsRegular.barbell,
                activeIcon: PhosphorIconsFill.barbell,
                label: 'Workout',
              ),
              FloatingNavItem(
                icon: PhosphorIconsRegular.chartLineUp,
                activeIcon: PhosphorIconsFill.chartLineUp,
                label: 'Progress',
              ),
              FloatingNavItem(
                icon: PhosphorIconsRegular.usersThree,
                activeIcon: PhosphorIconsFill.usersThree,
                label: 'Community',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
