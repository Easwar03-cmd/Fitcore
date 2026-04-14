import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../../core/api/api_client.dart';
import '../../../core/services/open_food_facts_service.dart';
import '../../../core/services/sync_queue_service.dart' show syncServiceProvider;
import '../models/food_item.dart';
import '../models/food_log.dart';

final _log = Logger();

// ── Food search ──────────────────────────────────────────────────────────────

class FoodSearchNotifier extends AsyncNotifier<List<FoodItem>> {
  @override
  Future<List<FoodItem>> build() => Future.value([]);

  Future<void> search(String query) async {
    final q = query.trim();
    if (q.length < 2) {
      state = const AsyncData([]);
      return;
    }
    state = const AsyncLoading();
    try {
      final results =
          await ref.read(openFoodFactsServiceProvider).searchByName(q);
      state = AsyncData(results);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void clear() => state = const AsyncData([]);
}

final foodSearchProvider =
    AsyncNotifierProvider<FoodSearchNotifier, List<FoodItem>>(
        FoodSearchNotifier.new);

// ── Barcode lookup ───────────────────────────────────────────────────────────

class FoodBarcodeNotifier extends AsyncNotifier<FoodItem?> {
  @override
  Future<FoodItem?> build() => Future.value(null);

  Future<void> lookupBarcode(String barcode) async {
    state = const AsyncLoading();
    try {
      final result =
          await ref.read(openFoodFactsServiceProvider).lookupByBarcode(barcode);
      state = AsyncData(result);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void reset() => state = const AsyncData(null);
}

final foodBarcodeProvider =
    AsyncNotifierProvider<FoodBarcodeNotifier, FoodItem?>(
        FoodBarcodeNotifier.new);

// ── Food logs (today) ────────────────────────────────────────────────────────

class FoodLogsNotifier extends AsyncNotifier<DayLogs> {
  @override
  Future<DayLogs> build() => _fetchToday();

  Future<DayLogs> _fetchToday() async {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    try {
      final res = await ref
          .read(apiClientProvider)
          .dio
          .get('/nutrition/food-logs', queryParameters: {'date': dateStr});
      final data = res.data['data'] as Map<String, dynamic>;
      final logs = (data['logs'] as List<dynamic>)
          .map((e) => FoodLog.fromJson(e as Map<String, dynamic>))
          .toList();
      final totals = DayTotals.fromJson(data['totals'] as Map<String, dynamic>);
      return DayLogs(logs: logs, totals: totals);
    } on DioException catch (e, st) {
      _log.e('Failed to load food logs', error: e, stackTrace: st);
      throw Exception('Failed to load today\'s logs. Pull down to retry.');
    }
  }

  Future<void> logFood({
    required FoodItem item,
    required double servingG,
    required String mealType,
  }) async {
    final factor = servingG / 100.0;
    final payload = <String, dynamic>{
      'foodId': item.name.toLowerCase().replaceAll(RegExp(r'\s+'), '_'),
      'foodName': item.name,
      'mealType': mealType,
      'servingG': servingG,
      'calories': double.parse(
          (item.caloriesPer100g * factor).toStringAsFixed(1)),
      'proteinG': double.parse(
          (item.proteinPer100g * factor).toStringAsFixed(1)),
      'carbsG': double.parse(
          (item.carbsPer100g * factor).toStringAsFixed(1)),
      'fatG': double.parse(
          (item.fatPer100g * factor).toStringAsFixed(1)),
      if (item.fiberPer100g != null)
        'fiberG': double.parse(
            (item.fiberPer100g! * factor).toStringAsFixed(1)),
    };
    try {
      await ref
          .read(apiClientProvider)
          .dio
          .post('/nutrition/food-logs', data: payload);
      state = AsyncData(await _fetchToday());
    } on DioException catch (e, st) {
      // No response → network error. Queue for retry and treat as accepted.
      if (e.response == null) {
        await ref
            .read(syncServiceProvider)
            .enqueue('/nutrition/food-logs', payload);
        _log.w('Food log queued for sync (offline)', error: e);
        return;
      }
      _log.e('Failed to log food', error: e, stackTrace: st);
      throw Exception('Failed to save food log. Please try again.');
    }
  }

  /// Calls the DELETE API; queues the delete offline if there is no network.
  Future<void> deleteLog(String id) async {
    try {
      await ref
          .read(apiClientProvider)
          .dio
          .delete('/nutrition/food-logs/$id');
    } on DioException catch (e, st) {
      if (e.response == null) {
        await ref
            .read(syncServiceProvider)
            .enqueue('/nutrition/food-logs/$id', {}, httpMethod: 'DELETE');
        _log.w('Food log delete queued for sync (offline)', error: e);
        return;
      }
      _log.e('Failed to delete food log', error: e, stackTrace: st);
      throw Exception('Failed to delete log entry. Please try again.');
    }
  }

  /// Removes a log from local state immediately (called after a confirmed delete).
  void removeLogLocally(String id) {
    final current = state.valueOrNull;
    if (current == null) return;
    final newLogs = current.logs.where((l) => l.id != id).toList();
    final newTotals = newLogs.fold(
      DayTotals.zero,
      (acc, l) => DayTotals(
        calories: acc.calories + l.calories,
        proteinG: acc.proteinG + l.proteinG,
        carbsG: acc.carbsG + l.carbsG,
        fatG: acc.fatG + l.fatG,
      ),
    );
    state = AsyncData(DayLogs(logs: newLogs, totals: newTotals));
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchToday);
  }
}

final foodLogsProvider =
    AsyncNotifierProvider<FoodLogsNotifier, DayLogs>(FoodLogsNotifier.new);
