/* import 'package:flutter/material.dart';
import 'ingredientCard.dart';
import '../models/recipeIngredient.dart';

class IngredientsGrid extends StatelessWidget {
  final int servings;
  final List<dynamic> ingredientsData;

  IngredientsGrid({
    Key? key,
    required this.servings,
    required this.ingredientsData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<RecipeIngredient> ingredients = ingredientsData.map((data) {
      return RecipeIngredient.fromJson(data as Map<String, dynamic>);
    }).toList();

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // Adjust to 2 columns for better spacing
        childAspectRatio: 0.8,
      ),
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: ingredients.length,
      itemBuilder: (context, index) {
        final ingredient = ingredients[index];
        return IngredientCard(
          //imageUrl: ingredient.ingredient.imageUrl ?? '',
          baseAmount: ingredient.baseAmount,
          unit: ingredient.unit,
          ingredientName: ingredient.ingredient.ingredientName,
          servings: servings,
          initialServings: ingredient.servings,
        );
      },
    );
  }
}
 */