import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../features/nutrition/models/food_item.dart';

final _log = Logger();

final indianFoodServiceProvider =
    Provider<IndianFoodService>((ref) => IndianFoodService());

/// Loads the bundled multi-cuisine food database and provides fast in-memory search.
/// Covers Indian, American, Italian, Chinese, fruits, vegetables, proteins, and beverages.
class IndianFoodService {
  List<FoodItem>? _cache;

  Future<List<FoodItem>> _loadAll() async {
    if (_cache != null) return _cache!;
    try {
      // local_foods.json is the comprehensive multi-cuisine database (replaces indian_foods.json)
      final raw = await rootBundle.loadString('assets/data/local_foods.json');
      final list = jsonDecode(raw) as List<dynamic>;
      _cache = list
          .whereType<Map<String, dynamic>>()
          .map<FoodItem>(FoodItem.fromLocalJson)
          .toList();
    } catch (e, st) {
      _log.e('Failed to load local_foods.json', error: e, stackTrace: st);
      _cache = [];
    }
    return _cache!;
  }

  /// Bundled foods tagged for [meal] (breakfast | lunch | dinner | snack),
  /// Indian dishes first, for the one-tap menus on the search screen.
  Future<List<FoodItem>> menuFor(String meal) async {
    final all = await _loadAll();
    final items = all.where((i) => i.mealTags.contains(meal)).toList();
    items.sort((a, b) {
      if (a.isIndian != b.isIndian) return a.isIndian ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    return items;
  }

  /// Case-insensitive search on name, nameHindi, category, and cuisine.
  Future<List<FoodItem>> search(String query) async {
    if (query.trim().isEmpty) return [];
    final all = await _loadAll();
    final q = query.toLowerCase().trim();
    return all.where((item) {
      return item.name.toLowerCase().contains(q) ||
          (item.nameHindi?.toLowerCase().contains(q) ?? false) ||
          (item.category?.toLowerCase().contains(q) ?? false);
    }).toList();
  }
}
