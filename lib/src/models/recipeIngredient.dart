import 'package:food_fellas/src/models/ingredient.dart';

class RecipeIngredient {
  final Ingredient ingredient;
  double baseAmount;
  String unit;
  int servings;

  RecipeIngredient({
    required this.ingredient,
    this.baseAmount = 100, // Default base amount
    this.unit = 'g',       // Default unit
    this.servings = 1,     // Default servings
  });

  Map<String, dynamic> toJson() {
    return {
      'ingredient': ingredient.toJson(), // Serialize the ingredient itself
      'baseAmount': baseAmount,
      'unit': unit,
      'servings': servings,
    };
  }
}
