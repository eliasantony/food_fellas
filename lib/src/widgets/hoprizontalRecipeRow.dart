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
            big: false,
            recipeId: recipeData['recipeId'],
            title: recipeData['title'] ?? 'Unnamed Recipe',
            description: recipeData['description'] ?? '',
            rating: recipeData['averageRating']?.toDouble() ?? 0.0,
            thumbnailUrl: recipeData['imageUrl'] ?? '',
            author: recipeData['author'] ?? '',
            cookTime: recipeData['cookingTime'] ?? '',
          );
        }).toList(),
      ),
    );
  }
}
