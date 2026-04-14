import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../features/nutrition/models/food_item.dart';

final _log = Logger();

final openFoodFactsServiceProvider =
    Provider<OpenFoodFactsService>((ref) => OpenFoodFactsService());

class OpenFoodFactsService {
  OpenFoodFactsService() {
    _offDio = Dio(
      BaseOptions(
        baseUrl: 'https://world.openfoodfacts.org',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'User-Agent': 'FitCore/1.0 (flutter)', 'Accept': 'application/json'},
      ),
    );
    _usdaDio = Dio(
      BaseOptions(
        baseUrl: 'https://api.nal.usda.gov',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
  }

  late final Dio _offDio;
  late final Dio _usdaDio;

  static const _offFields = 'product_name,brands,nutriments,image_url';

  // ── Public API ────────────────────────────────────────────────────────────

  /// Searches Open Food Facts + USDA in parallel and merges the results.
  /// OFF covers packaged/branded products; USDA covers raw whole foods.
  Future<List<FoodItem>> searchByName(String query) async {
    final results = await Future.wait([
      _searchOff(query),
      _searchUsda(query),
    ]);
    return _merge(results[0], results[1]);
  }

  /// Barcode lookup via Open Food Facts only (USDA has no barcode index).
  Future<FoodItem?> lookupByBarcode(String barcode) async {
    try {
      final res = await _offDio.get('/api/v0/product/$barcode.json');
      final status = res.data['status'] as int? ?? 0;
      if (status != 1) return null;
      final product = res.data['product'] as Map<String, dynamic>?;
      if (product == null) return null;
      return FoodItem.fromOpenFoodFactsJson(product);
    } on DioException catch (e, st) {
      _log.e('OpenFoodFacts barcode lookup failed', error: e, stackTrace: st);
      throw Exception('Failed to look up barcode. Please try again.');
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<List<FoodItem>> _searchOff(String query) async {
    try {
      final res = await _offDio.get(
        '/cgi/search.pl',
        queryParameters: {
          'search_terms': query,
          'json': '1',
          'fields': _offFields,
          'page_size': '15',
          'action': 'process',
        },
      );
      final products = res.data['products'] as List<dynamic>? ?? [];
      return products
          .whereType<Map<String, dynamic>>()
          .where((p) => (p['product_name'] as String? ?? '').trim().isNotEmpty)
          .map(FoodItem.fromOpenFoodFactsJson)
          .toList();
    } catch (e, st) {
      _log.w('OpenFoodFacts search failed (non-fatal)', error: e, stackTrace: st);
      return [];
    }
  }

  Future<List<FoodItem>> _searchUsda(String query) async {
    try {
      final res = await _usdaDio.get(
        '/fdc/v1/foods/search',
        queryParameters: {
          'query': query,
          'api_key': 'DEMO_KEY',
          'pageSize': '15',
          // SR Legacy = USDA standard reference (raw/whole foods)
          // Foundation = foundational foods data
          'dataType': 'SR Legacy,Foundation',
        },
      );
      final foods = res.data['foods'] as List<dynamic>? ?? [];
      return foods
          .whereType<Map<String, dynamic>>()
          .where((f) => (f['description'] as String? ?? '').trim().isNotEmpty)
          .map(FoodItem.fromUsdaJson)
          .toList();
    } catch (e, st) {
      _log.w('USDA search failed (non-fatal)', error: e, stackTrace: st);
      return [];
    }
  }

  /// Merges two lists, deduplicating by lower-cased name.
  /// USDA results come first (better raw food data), then OFF (packaged goods).
  List<FoodItem> _merge(List<FoodItem> off, List<FoodItem> usda) {
    final seen = <String>{};
    final merged = <FoodItem>[];
    for (final item in [...usda, ...off]) {
      final key = item.name.toLowerCase().trim();
      if (key.isNotEmpty && seen.add(key)) {
        merged.add(item);
      }
    }
    return merged;
  }
}
