class FoodLog {
  const FoodLog({
    required this.id,
    required this.foodName,
    required this.mealType,
    required this.servingG,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.fiberG,
    required this.loggedAt,
  });

  final String id;
  final String foodName;
  final String mealType; // breakfast | lunch | dinner | snack
  final double servingG;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double? fiberG;
  final DateTime loggedAt;

  factory FoodLog.fromJson(Map<String, dynamic> json) => FoodLog(
        id: json['id'] as String,
        foodName: json['foodName'] as String,
        mealType: json['mealType'] as String,
        servingG: _toDouble(json['servingG']),
        calories: _toDouble(json['calories']),
        proteinG: _toDouble(json['proteinG']),
        carbsG: _toDouble(json['carbsG']),
        fatG: _toDouble(json['fatG']),
        fiberG: json['fiberG'] != null ? _toDouble(json['fiberG']) : null,
        loggedAt: DateTime.parse(json['loggedAt'] as String),
      );

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }
}

/// Aggregated totals returned alongside the log list.
class DayTotals {
  const DayTotals({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;

  factory DayTotals.fromJson(Map<String, dynamic> json) => DayTotals(
        calories: FoodLog._toDouble(json['calories']),
        proteinG: FoodLog._toDouble(json['proteinG']),
        carbsG: FoodLog._toDouble(json['carbsG']),
        fatG: FoodLog._toDouble(json['fatG']),
      );

  static const zero = DayTotals(calories: 0, proteinG: 0, carbsG: 0, fatG: 0);
}

class DayLogs {
  const DayLogs({required this.logs, required this.totals});
  final List<FoodLog> logs;
  final DayTotals totals;
}
