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

  // Convert JSON to RecipeIngredient object
  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      ingredient: Ingredient.fromJson(json['ingredient']),
      baseAmount: json['baseAmount']?.toDouble() ?? 100,
      unit: json['unit'] ?? 'g',
      servings: json['servings'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ingredient': ingredient.toJson(),
      'baseAmount': baseAmount,
      'unit': unit,
      'servings': servings,
    };
  }
}

