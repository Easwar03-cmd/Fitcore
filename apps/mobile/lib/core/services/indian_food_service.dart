import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../features/nutrition/models/food_item.dart';

final _log = Logger();

final indianFoodServiceProvider =
    Provider<IndianFoodService>((ref) => IndianFoodService());

/// Loads the bundled Indian foods JSON asset and provides fast in-memory search.
/// The asset is loaded once on first call; subsequent calls use the cache.
class IndianFoodService {
  List<FoodItem>? _cache;

  Future<List<FoodItem>> _loadAll() async {
    if (_cache != null) return _cache!;
    try {
      final raw = await rootBundle.loadString('assets/data/indian_foods.json');
      final list = jsonDecode(raw) as List<dynamic>;
      _cache = list
          .whereType<Map<String, dynamic>>()
          .map(FoodItem.fromIndianJson)
          .toList();
    } catch (e, st) {
      _log.e('Failed to load indian_foods.json', error: e, stackTrace: st);
      _cache = [];
    }
    return _cache!;
  }

  /// Case-insensitive search on [FoodItem.name] and [FoodItem.nameHindi].
  Future<List<FoodItem>> search(String query) async {
    if (query.trim().isEmpty) return [];
    final all = await _loadAll();
    final q = query.toLowerCase().trim();
    return all.where((item) {
      final nameMatch = item.name.toLowerCase().contains(q);
      final hindiMatch = item.nameHindi?.toLowerCase().contains(q) ?? false;
      return nameMatch || hindiMatch;
    }).toList();
  }
}
