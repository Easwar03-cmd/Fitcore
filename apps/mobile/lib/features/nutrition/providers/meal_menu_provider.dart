import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/indian_food_service.dart';
import '../models/food_item.dart';

/// Ready-made menu for a meal ('breakfast' | 'lunch' | 'dinner' | 'snack').
final mealMenuProvider =
    FutureProvider.family<List<FoodItem>, String>((ref, meal) {
  return ref.read(indianFoodServiceProvider).menuFor(meal);
});
