import 'package:flutter/material.dart';
import '../views/recipeDetails_screen.dart';
import 'recipeCard.dart';

class HorizontalRecipeRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RecipeDetailScreen(),
                ),
              );
            },
            child: RecipeCard(
              big: false,
              title: 'Spaghetti Bolognese',
              description: 'A classic Italian dish',
              rating: 4.5,
              thumbnailUrl: 'lib/assets/images/spaghettiBolognese.webp',
              author: 'Elias Antony',
              cookTime: '30 mins',
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RecipeDetailScreen(),
                ),
              );
            },
            child: RecipeCard(
              big: false,
              title: 'Spaghetti Bolognese',
              description: 'A classic Italian dish',
              rating: 4.5,
              thumbnailUrl: 'lib/assets/images/spaghettiBolognese.webp',
              author: 'Elias Antony',
              cookTime: '30 mins',
            ),
          ),
          // Add more RecipeCard widgets here
        ],
      ),
    );
  }
}
