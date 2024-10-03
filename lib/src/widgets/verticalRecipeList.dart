import 'package:flutter/material.dart';
import 'mockupRecipeCard.dart';

class VerticalRecipeList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Column(
        children: [
          MockupRecipeCard(
            big: true,
            recipeId: 'testId',
            title: 'Spaghetti Bolognese',
            description: 'A classic Italian dish',
            rating: 4.5,
            thumbnailUrl: 'lib/assets/images/spaghettiBolognese.webp',
            author: 'Elias Antony',
            totalTime: '30 mins',
                       ratingsCount: 0,
          ),
          MockupRecipeCard(
            big: true,
            recipeId: 'testId',
            title: 'Spaghetti Bolognese',
            description: 'A classic Italian dish',
            rating: 4.5,
            thumbnailUrl: 'lib/assets/images/spaghettiBolognese.webp',
            author: 'Elias Antony',
            totalTime: '30 mins',
                       ratingsCount: 0,
          ),
          MockupRecipeCard(
            big: true,
            recipeId: 'testId',
            title: 'Spaghetti Bolognese',
            description: 'A classic Italian dish',
            rating: 4.5,
            thumbnailUrl: 'lib/assets/images/spaghettiBolognese.webp',
            author: 'Elias Antony',
            totalTime: '30 mins',
                       ratingsCount: 0,
          ),
          // Add more RecipeCard widgets here
        ],
      ),
    );
  }
}
