import 'package:flutter/material.dart';
import 'package:food_fellas/src/widgets/mockupRecipeCard.dart';
import '../views/recipeDetails_screen.dart';
import 'recipeCard.dart';

class MockupHorizontalRecipeRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          MockupRecipeCard(
            big: false,
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
            big: false,
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
            big: false,
            recipeId: 'testId',
            title: 'Spaghetti Bolognese',
            description: 'A classic Italian dish',
            rating: 4.5,
            thumbnailUrl: 'lib/assets/images/spaghettiBolognese.webp',
            author: 'Elias Antony',
            totalTime: '30 mins',
            ratingsCount: 0,
          ),
        ],
      ),
    );
  }
}
