import 'package:flutter/material.dart';
import 'recipeCard.dart';

class VerticalRecipeColumn extends StatelessWidget {
  final List<String> recipeIds;

  VerticalRecipeColumn({required this.recipeIds});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: recipeIds.length,
      itemBuilder: (context, index) {
        return RecipeCard(
          recipeId: recipeIds[index],
          big: true,
        );
      },
    );
  }
}
