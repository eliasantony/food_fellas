// ingredient_list_widget.dart
import 'package:flutter/material.dart';
import 'package:food_fellas/src/models/ingredient.dart';

class IngredientListWidget extends StatelessWidget {
  final List<Ingredient> ingredients;
  final List<String> selectedIngredients;
  final Function(String, bool) onSelectionChanged;

  IngredientListWidget({
    required this.ingredients,
    required this.selectedIngredients,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: ingredients.length,
      itemBuilder: (context, index) {
        final ingredient = ingredients[index];
        final isSelected =
            selectedIngredients.contains(ingredient.ingredientName);

        return CheckboxListTile(
          title: Text(ingredient.ingredientName),
          value: isSelected,
          onChanged: (bool? value) {
            onSelectionChanged(ingredient.ingredientName, value ?? false);
          },
        );
      },
    );
  }
}
