// Food photo analysis models — mirrors FoodPhotoAnalysis returned by
// POST /api/v1/ai/analyze-food-photo.

class DetectedFoodItem {
  DetectedFoodItem({
    required this.foodName,
    required this.servingG,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.fiberG,
    required this.confidence,
    this.isSelected = true,
  })  : _baseServingG = servingG,
        _baseCalories = calories,
        _baseProteinG = proteinG,
        _baseCarbsG = carbsG,
        _baseFatG = fatG,
        _baseFiberG = fiberG;

  String foodName;
  double servingG;
  double calories;
  double proteinG;
  double carbsG;
  double fatG;
  double? fiberG;
  final String confidence; // high | medium | low
  bool isSelected;

  // Original values for proportional scaling when serving size changes.
  final double _baseServingG;
  final double _baseCalories;
  final double _baseProteinG;
  final double _baseCarbsG;
  final double _baseFatG;
  final double? _baseFiberG;

  /// Recalculate all macros proportionally when serving size is adjusted.
  void updateServing(double newServingG) {
    if (newServingG <= 0 || _baseServingG <= 0) return;
    final ratio = newServingG / _baseServingG;
    servingG = newServingG;
    calories = double.parse((_baseCalories * ratio).toStringAsFixed(1));
    proteinG = double.parse((_baseProteinG * ratio).toStringAsFixed(1));
    carbsG = double.parse((_baseCarbsG * ratio).toStringAsFixed(1));
    fatG = double.parse((_baseFatG * ratio).toStringAsFixed(1));
    fiberG = _baseFiberG != null
        ? double.parse((_baseFiberG * ratio).toStringAsFixed(1))
        : null;
  }

  factory DetectedFoodItem.fromJson(Map<String, dynamic> json) =>
      DetectedFoodItem(
        foodName: json['foodName'] as String,
        servingG: (json['servingG'] as num).toDouble(),
        calories: (json['calories'] as num).toDouble(),
        proteinG: (json['proteinG'] as num).toDouble(),
        carbsG: (json['carbsG'] as num).toDouble(),
        fatG: (json['fatG'] as num).toDouble(),
        fiberG: json['fiberG'] != null ? (json['fiberG'] as num).toDouble() : null,
        confidence: json['confidence'] as String? ?? 'medium',
      );
}

class FoodPhotoAnalysis {
  const FoodPhotoAnalysis({
    required this.detectedFoods,
    required this.totalCalories,
    this.notes,
  });

  final List<DetectedFoodItem> detectedFoods;
  final double totalCalories;
  final String? notes;

  factory FoodPhotoAnalysis.fromJson(Map<String, dynamic> json) =>
      FoodPhotoAnalysis(
        detectedFoods: (json['detectedFoods'] as List<dynamic>)
            .map((e) => DetectedFoodItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalCalories: (json['totalCalories'] as num).toDouble(),
        notes: json['notes'] as String?,
      );
}
