import 'package:flutter/material.dart';
import 'recipeCard.dart';

class VerticalRecipeList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Column(
        children: [
          RecipeCard(
            big: true,
            title: 'Spaghetti Bolognese',
            description: 'A classic Italian dish',
            rating: 4.5,
            thumbnailUrl: 'lib/assets/images/spaghettiBolognese.webp',
            author: 'Elias Antony',
            cookTime: '30 mins',
          ),
          RecipeCard(
            big: true,
            title: 'Spaghetti Bolognese',
            description: 'A classic Italian dish',
            rating: 4.5,
            thumbnailUrl: 'lib/assets/images/spaghettiBolognese.webp',
            author: 'Elias Antony',
            cookTime: '30 mins',
          ),
          RecipeCard(
            big: true,
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
