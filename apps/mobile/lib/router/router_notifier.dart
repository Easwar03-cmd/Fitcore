import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_routes.dart';
import '../features/auth/providers/auth_provider.dart';

/// Bridges Riverpod auth state changes into a [Listenable] that GoRouter
/// can subscribe to for its [GoRouter.refreshListenable].
class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this._ref) {
    // Re-evaluate redirect whenever auth state changes.
    _ref.listen(authProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;

  static const _onboardingRoutes = {
    AppRoutes.goalSelection,
    AppRoutes.bodyStats,
    AppRoutes.activityLevel,
  };

  String? redirect(BuildContext context, GoRouterState state) {
    final authAsync = _ref.read(authProvider);
    final loc = state.matchedLocation;

    // While restoring session, stay on splash; redirect anything else there.
    if (authAsync.isLoading) {
      return loc == AppRoutes.splash ? null : AppRoutes.splash;
    }

    final authState = authAsync.valueOrNull;
    final isAuthenticated = authState != null;

    // Splash has no purpose once auth is resolved — always redirect away.
    if (loc == AppRoutes.splash) {
      if (!isAuthenticated) return AppRoutes.login;
      return authState.user.hasProfile ? AppRoutes.home : AppRoutes.goalSelection;
    }

    final isAuthRoute = loc == AppRoutes.login ||
        loc == AppRoutes.signup ||
        loc == AppRoutes.forgotPassword;
    final isOnboardingRoute = _onboardingRoutes.contains(loc);

    // Not logged in → send to login (except auth routes themselves).
    if (!isAuthenticated) {
      return isAuthRoute ? null : AppRoutes.login;
    }

    // Logged in + on an auth route → route based on profile completion.
    if (isAuthRoute) {
      return authState.user.hasProfile ? AppRoutes.home : AppRoutes.goalSelection;
    }

    // Logged in, no profile, trying to access app → force onboarding.
    if (!authState.user.hasProfile && !isOnboardingRoute) {
      return AppRoutes.goalSelection;
    }

    // Logged in, profile already done, on onboarding → skip to home.
    if (authState.user.hasProfile && isOnboardingRoute) {
      return AppRoutes.home;
    }

    return null;
  }
}
