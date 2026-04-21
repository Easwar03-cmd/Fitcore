import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/meal_plan.dart';

final _log = Logger();

// Whether the user hit the Pro paywall (403 UPGRADE_REQUIRED).
// Separate from the plan state so the screen can show the banner immediately.
final mealPlanUpgradeRequiredProvider = StateProvider<bool>((ref) => false);

class MealPlanNotifier extends AsyncNotifier<WeeklyMealPlan?> {
  // Use ref.read — safe to call from action methods too.
  String get _cacheKey {
    final userId = ref.read(authProvider).valueOrNull?.user.id ?? 'anonymous';
    return 'meal_plan_v1_$userId';
  }

  @override
  Future<WeeklyMealPlan?> build() async {
    // Watch authProvider so this rebuilds when the logged-in user changes.
    ref.watch(authProvider);
    final cacheKey = _cacheKey;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(cacheKey);
    if (raw != null) {
      try {
        return WeeklyMealPlan.fromJson(
            jsonDecode(raw) as Map<String, dynamic>);
      } catch (e) {
        _log.w('Cached meal plan corrupt — clearing', error: e);
        await prefs.remove(cacheKey);
      }
    }
    return null;
  }

  Future<void> generate() async {
    state = const AsyncLoading();
    try {
      final res = await ref.read(apiClientProvider).dio.post('/ai/meal-plan');
      final plan =
          WeeklyMealPlan.fromJson(res.data['data'] as Map<String, dynamic>);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(plan.toJson()));

      ref.read(mealPlanUpgradeRequiredProvider.notifier).state = false;
      state = AsyncData(plan);
    } on DioException catch (e, st) {
      if (e.response?.statusCode == 403) {
        ref.read(mealPlanUpgradeRequiredProvider.notifier).state = true;
        state = const AsyncData(null);
        return;
      }
      _log.e('Failed to generate meal plan', error: e, stackTrace: st);
      state = AsyncError(
        Exception(
          e.response?.data?['error']?['message'] ??
              'Failed to generate meal plan. Please try again.',
        ),
        st,
      );
    }
  }

  Future<void> clearPlan() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    state = const AsyncData(null);
  }
}

final mealPlanProvider =
    AsyncNotifierProvider<MealPlanNotifier, WeeklyMealPlan?>(
        MealPlanNotifier.new);
