// Meal plan models — mirrors the WeeklyMealPlan shape returned by
// POST /api/v1/ai/meal-plan.

class PlannedMeal {
  const PlannedMeal({
    required this.mealType,
    required this.name,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.ingredients,
    required this.prepTimeMin,
  });

  final String mealType; // breakfast | lunch | dinner | snack
  final String name;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final List<String> ingredients;
  final int prepTimeMin;

  factory PlannedMeal.fromJson(Map<String, dynamic> json) => PlannedMeal(
        mealType: json['mealType'] as String,
        name: json['name'] as String,
        calories: (json['calories'] as num).toDouble(),
        proteinG: (json['proteinG'] as num).toDouble(),
        carbsG: (json['carbsG'] as num).toDouble(),
        fatG: (json['fatG'] as num).toDouble(),
        ingredients: (json['ingredients'] as List<dynamic>)
            .map((e) => e as String)
            .toList(),
        prepTimeMin: (json['prepTimeMin'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {
        'mealType': mealType,
        'name': name,
        'calories': calories,
        'proteinG': proteinG,
        'carbsG': carbsG,
        'fatG': fatG,
        'ingredients': ingredients,
        'prepTimeMin': prepTimeMin,
      };
}

class DayMealPlan {
  const DayMealPlan({
    required this.dayName,
    required this.totalCalories,
    required this.totalProteinG,
    required this.totalCarbsG,
    required this.totalFatG,
    required this.meals,
  });

  final String dayName;
  final double totalCalories;
  final double totalProteinG;
  final double totalCarbsG;
  final double totalFatG;
  final List<PlannedMeal> meals;

  factory DayMealPlan.fromJson(Map<String, dynamic> json) => DayMealPlan(
        dayName: json['dayName'] as String,
        totalCalories: (json['totalCalories'] as num).toDouble(),
        totalProteinG: (json['totalProteinG'] as num).toDouble(),
        totalCarbsG: (json['totalCarbsG'] as num).toDouble(),
        totalFatG: (json['totalFatG'] as num).toDouble(),
        meals: (json['meals'] as List<dynamic>)
            .map((e) => PlannedMeal.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'dayName': dayName,
        'totalCalories': totalCalories,
        'totalProteinG': totalProteinG,
        'totalCarbsG': totalCarbsG,
        'totalFatG': totalFatG,
        'meals': meals.map((m) => m.toJson()).toList(),
      };
}

class WeeklyMealPlan {
  const WeeklyMealPlan({required this.days});

  final List<DayMealPlan> days;

  factory WeeklyMealPlan.fromJson(Map<String, dynamic> json) => WeeklyMealPlan(
        days: (json['days'] as List<dynamic>)
            .map((e) => DayMealPlan.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'days': days.map((d) => d.toJson()).toList(),
      };
}
