import 'package:flutter/material.dart';
import 'recipeCard.dart';

class HorizontalRecipeRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          RecipeCard(
            title: 'Spaghetti Bolognese',
            description: 'A classic Italian dish',
            rating: 4.5,
            thumbnailUrl: 'lib/assets/images/spaghettiBolognese.webp',
            author: 'Elias Antony',
            cookTime: '30 mins',
          ),
          RecipeCard(
            title: 'Spaghetti Bolognese',
            description: 'A classic Italian dish',
            rating: 4.5,
            thumbnailUrl: 'lib/assets/images/spaghettiBolognese.webp',
            author: 'Elias Antony',
            cookTime: '30 mins',
          ),
          // Add more RecipeCard widgets here
        ],
      ),
    );
  }
}
