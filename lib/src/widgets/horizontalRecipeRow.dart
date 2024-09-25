import 'package:flutter/material.dart';
import '../views/recipeDetails_screen.dart';
import 'recipeCard.dart';

class HorizontalRecipeRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          RecipeCard(
            big: false,
            recipeId: 'testId',
            title: 'Spaghetti Bolognese',
            description: 'A classic Italian dish',
            rating: 4.5,
            thumbnailUrl: 'lib/assets/images/spaghettiBolognese.webp',
            author: 'Elias Antony',
            cookTime: '30 mins',
          ),
          RecipeCard(
            big: false,
            recipeId: 'testId',
            title: 'Spaghetti Bolognese',
            description: 'A classic Italian dish',
            rating: 4.5,
            thumbnailUrl: 'lib/assets/images/spaghettiBolognese.webp',
            author: 'Elias Antony',
            cookTime: '30 mins',
          ),
          RecipeCard(
            big: false,
            recipeId: 'testId',
            title: 'Spaghetti Bolognese',
            description: 'A classic Italian dish',
            rating: 4.5,
            thumbnailUrl: 'lib/assets/images/spaghettiBolognese.webp',
            author: 'Elias Antony',
            cookTime: '30 mins',
          ),
        ],
      ),
    );
  }
}
