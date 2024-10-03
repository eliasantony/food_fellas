import 'package:flutter/material.dart';
import 'recipeCard.dart';

class HorizontalRecipeRow extends StatelessWidget {
  final List<Map<String, dynamic>> recipes;

  HorizontalRecipeRow({required this.recipes});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: recipes.map((recipeData) {
          return RecipeCard(
            recipeId: recipeData['id'], // Access the 'id' from recipeData
            big: false,
          );
        }).toList(),
      ),
    );
  }
}
