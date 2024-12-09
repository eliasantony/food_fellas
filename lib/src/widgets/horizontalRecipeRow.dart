import 'package:flutter/material.dart';
import 'package:food_fellas/src/views/userRecipeList_screen.dart';
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
          if (recipeData['isViewAll'] == true) {
            // Render the special 'View All' card
            return _buildViewAllCard(context, recipeData);
          } else {
            // Render a regular recipe card
            return RecipeCard(
              recipeId: recipeData['id'],
              big: false,
            );
          }
        }).toList(),
      ),
    );
  }

  Widget _buildViewAllCard(BuildContext context, Map<String, dynamic> data) {
    return GestureDetector(
      onTap: () {
        // Navigate to the full recipe list
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UserRecipesListScreen(
              userId: data['userId'],
              displayName: data['displayName'],
              isCurrentUser: data['isCurrentUser'],
            ),
          ),
        );
      },
      child: Container(
        width: 150, // Adjust the width as needed
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          margin: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Container(
            width: 120,
            height: 275,
            padding: EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      Icon(Icons.list_rounded, size: 40),
                      SizedBox(height: 8),
                      const Text(
                        'View All',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'of ${data['displayName']}\'s recipes',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
