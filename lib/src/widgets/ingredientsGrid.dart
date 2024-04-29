import 'package:flutter/material.dart';
import 'package:food_fellas/src/widgets/ingredientCard.dart';

class IngredientsGrid extends StatelessWidget {
  final int servings; // Add servings parameter

  // Assuming IngredientCard is updated to accept a baseAmount
  final List<IngredientCard> ingredients = [
    IngredientCard(
      imageUrl: 'lib/assets/images/pasta.webp',
      ingredientName: 'Pasta',
      baseAmount: 125,
      unit: 'g',
      servings: 2,
    ),
    IngredientCard(
      imageUrl: 'lib/assets/images/tomato.webp',
      ingredientName: 'Tomato',
      baseAmount: 200,
      unit: 'g',
      servings: 2,
    ),
    IngredientCard(
      imageUrl: 'lib/assets/images/pasta.webp',
      ingredientName: 'Pasta',
      baseAmount: 125,
      unit: 'g',
      servings: 2,
    ),
    IngredientCard(
      imageUrl: 'lib/assets/images/tomato.webp',
      ingredientName: 'Tomato',
      baseAmount: 200,
      unit: 'g',
      servings: 2,
    ),
    IngredientCard(
      imageUrl: 'lib/assets/images/pasta.webp',
      ingredientName: 'Pasta',
      baseAmount: 125,
      unit: 'g',
      servings: 2,
    ),
    IngredientCard(
      imageUrl: 'lib/assets/images/tomato.webp',
      ingredientName: 'Tomato',
      baseAmount: 200,
      unit: 'g',
      servings: 2,
    ),
    IngredientCard(
      imageUrl: 'lib/assets/images/pasta.webp',
      ingredientName: 'Pasta',
      baseAmount: 125,
      unit: 'g',
      servings: 2,
    ),
    IngredientCard(
      imageUrl: 'lib/assets/images/tomato.webp',
      ingredientName: 'Tomato',
      baseAmount: 200,
      unit: 'g',
      servings: 2,
    ),
  ];

  IngredientsGrid({
    Key? key,
    required this.servings,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, childAspectRatio: 0.6),
      shrinkWrap: true, // If you want this to be within a scrollable view
      itemCount: ingredients.length,
      itemBuilder: (context, index) {
        return IngredientCard(
          imageUrl: ingredients[index].imageUrl,
          baseAmount: ingredients[index].baseAmount,
          unit: ingredients[index].unit,
          ingredientName: ingredients[index].ingredientName,
          servings: servings, 
        );
      },
    );
  }
}
