class ServingOption {
  const ServingOption({required this.label, required this.grams});

  final String label;
  final double grams;

  factory ServingOption.fromJson(Map<String, dynamic> json) => ServingOption(
        label: json['label'] as String,
        grams: _toDouble(json['grams']),
      );

  static double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }
}

class FoodItem {
  const FoodItem({
    required this.name,
    this.nameHindi,
    this.brand,
    this.imageUrl,
    this.category,
    this.cuisine,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.fiberPer100g,
    this.commonServings,
    this.isIndian = false,
    this.isLiquid = false,
  });

  final String name;
  final String? nameHindi;
  final String? brand;
  final String? imageUrl;
  final String? category;
  final String? cuisine;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final double? fiberPer100g;
  final List<ServingOption>? commonServings;
  final bool isIndian;
  final bool isLiquid;

  factory FoodItem.fromOpenFoodFactsJson(Map<String, dynamic> json) {
    final n = json['nutriments'] as Map<String, dynamic>? ?? {};
    return FoodItem(
      name: _cleanOffName(json['product_name'] as String? ?? ''),
      brand: json['brands'] as String?,
      imageUrl: json['image_url'] as String?,
      caloriesPer100g: _toDouble(n['energy-kcal_100g']),
      proteinPer100g: _toDouble(n['proteins_100g']),
      carbsPer100g: _toDouble(n['carbohydrates_100g']),
      fatPer100g: _toDouble(n['fat_100g']),
      fiberPer100g: n.containsKey('fiber_100g') ? _toDouble(n['fiber_100g']) : null,
    );
  }

  /// USDA FoodData Central — SR Legacy / Foundation data types.
  /// Nutrient IDs: 1008=kcal, 1003=protein, 1005=carbs, 1004=fat, 1079=fiber.
  factory FoodItem.fromUsdaJson(Map<String, dynamic> json) {
    final nutrients =
        (json['foodNutrients'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>();

    double getNutrient(int id) => nutrients
        .where((n) => n['nutrientId'] == id)
        .map((n) => _toDouble(n['value']))
        .firstOrNull ?? 0.0;

    return FoodItem(
      name: _normalizeUsdaName(json['description'] as String? ?? ''),
      brand: json['brandOwner'] as String?,
      caloriesPer100g: getNutrient(1008),
      proteinPer100g: getNutrient(1003),
      carbsPer100g: getNutrient(1005),
      fatPer100g: getNutrient(1004),
      fiberPer100g: getNutrient(1079) > 0 ? getNutrient(1079) : null,
    );
  }

  /// Legacy factory kept for backward compatibility — delegates to fromLocalJson.
  factory FoodItem.fromIndianJson(Map<String, dynamic> json) =>
      FoodItem.fromLocalJson(json);

  /// Loads from the bundled multi-cuisine local_foods.json.
  factory FoodItem.fromLocalJson(Map<String, dynamic> json) {
    final p = json['per100g'] as Map<String, dynamic>;
    final servingsRaw = json['commonServings'] as List<dynamic>?;
    final cuisine = json['cuisine'] as String? ?? '';
    return FoodItem(
      name: json['name'] as String,
      nameHindi: json['nameHindi'] as String?,
      category: json['category'] as String?,
      cuisine: cuisine,
      isIndian: cuisine == 'indian',
      isLiquid: json['isLiquid'] as bool? ?? false,
      caloriesPer100g: _toDouble(p['calories']),
      proteinPer100g: _toDouble(p['proteinG']),
      carbsPer100g: _toDouble(p['carbsG']),
      fatPer100g: _toDouble(p['fatG']),
      fiberPer100g: p.containsKey('fiberG') ? _toDouble(p['fiberG']) : null,
      commonServings: servingsRaw
          ?.whereType<Map<String, dynamic>>()
          .map(ServingOption.fromJson)
          .toList(),
    );
  }

  // ── Name normalisation ────────────────────────────────────────────────────

  static const _usdaCategoryPrefixes = {
    'Beverages', 'Nuts', 'Fish', 'Vegetables', 'Fruits', 'Cereals',
    'Legumes', 'Spices', 'Sweets', 'Snacks', 'Soups', 'Sauces',
    'Poultry', 'Lamb', 'Pork', 'Beef', 'Game', 'Finfish', 'Crustaceans',
    'Mollusks', 'Fats', 'Oils', 'Dairy', 'Eggs',
  };

  /// Converts USDA names like "Egg, whole, raw, fresh" → "Whole Egg (raw)"
  /// and "Beverages, protein powder soy based" → "Soy Protein Powder".
  static String _normalizeUsdaName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;
    final parts = trimmed.split(', ').map((p) => p.trim()).toList();
    if (parts.length == 1) return _toTitleCase(trimmed);

    if (_usdaCategoryPrefixes.contains(parts[0])) {
      // Drop generic category; use at most 2 remaining parts.
      final meaningful = parts.skip(1).take(2).join(', ');
      return _toTitleCase(meaningful);
    }

    // "Egg, boiled" → "Boiled Egg"
    if (parts.length == 2) {
      return _toTitleCase('${parts[1]} ${parts[0]}');
    }

    // Long entries: "Chicken, broilers, breast, cooked" → "Chicken Breast (cooked)"
    final base = parts[0];
    final descriptor = parts.skip(1).where((p) {
      final lower = p.toLowerCase();
      // Keep meaningful descriptors, skip filler phrases
      return !lower.contains('broilers or fryers') &&
          !lower.contains('meat only') &&
          !lower.contains('ns as to') &&
          lower.length < 20;
    }).take(2).join(', ');
    if (descriptor.isNotEmpty) {
      return _toTitleCase('$base ($descriptor)');
    }
    return _toTitleCase('${parts[0]} ${parts[1]}');
  }

  /// Cleans Open Food Facts product names (mostly already consumer-friendly).
  static String _cleanOffName(String raw) {
    final cleaned = raw.trim();
    if (cleaned.isEmpty) return cleaned;
    // Fix ALL CAPS names
    if (cleaned == cleaned.toUpperCase() && cleaned.length > 3) {
      return _toTitleCase(cleaned.toLowerCase());
    }
    return cleaned;
  }

  static String _toTitleCase(String s) {
    if (s.isEmpty) return s;
    const skip = {'a', 'an', 'the', 'and', 'or', 'of', 'in', 'with', 'as'};
    final words = s.split(' ');
    return words.asMap().entries.map((e) {
      final word = e.value;
      if (word.isEmpty) return word;
      if (e.key > 0 && skip.contains(word.toLowerCase())) {
        return word.toLowerCase();
      }
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  static double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }
}
