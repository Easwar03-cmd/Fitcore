class FoodItem {
  const FoodItem({
    required this.name,
    this.brand,
    this.imageUrl,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.fiberPer100g,
  });

  final String name;
  final String? brand;
  final String? imageUrl;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final double? fiberPer100g;

  factory FoodItem.fromOpenFoodFactsJson(Map<String, dynamic> json) {
    final n = json['nutriments'] as Map<String, dynamic>? ?? {};
    return FoodItem(
      name: (json['product_name'] as String? ?? '').trim(),
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
      name: (json['description'] as String? ?? '').trim(),
      brand: json['brandOwner'] as String?,
      imageUrl: null, // USDA has no product images
      caloriesPer100g: getNutrient(1008),
      proteinPer100g: getNutrient(1003),
      carbsPer100g: getNutrient(1005),
      fatPer100g: getNutrient(1004),
      fiberPer100g: getNutrient(1079) > 0 ? getNutrient(1079) : null,
    );
  }

  static double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }
}
