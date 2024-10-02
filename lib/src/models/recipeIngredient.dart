import 'package:food_fellas/src/models/ingredient.dart';

class RecipeIngredient {
  final Ingredient ingredient;
  double? baseAmount;
  String? amountDescription;
  String? unit;
  int? servings;

  RecipeIngredient({
    required this.ingredient,
    this.baseAmount,
    this.amountDescription,
    this.unit,
    this.servings,
  });

// Convert JSON to RecipeIngredient object
  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    double? baseAmount;
    String? amountDescription;

    // Handle baseAmount
    if (json['baseAmount'] != null) {
      if (json['baseAmount'] is num) {
        baseAmount = (json['baseAmount'] as num).toDouble();
      } else if (json['baseAmount'] is String) {
        final amountString = json['baseAmount'] as String;
        final parsedAmount = double.tryParse(amountString);
        if (parsedAmount != null) {
          baseAmount = parsedAmount;
        } else {
          amountDescription = amountString;
        }
      }
    }

    // Handle amountDescription if it's provided separately
    if (json['amountDescription'] != null) {
      amountDescription = json['amountDescription'];
    }

    return RecipeIngredient(
      ingredient: Ingredient.fromJson(json['ingredient']),
      baseAmount: baseAmount,
      amountDescription: amountDescription,
      unit: json['unit'],
      servings: json['servings'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ingredient': ingredient.toJson(),
      'baseAmount': baseAmount ?? amountDescription,
      'unit': unit,
      'servings': servings,
    };
  }
}
