import 'package:flutter/material.dart';
import '../../models/recipe.dart';
import '../../models/ingredient.dart';

class IngredientsSelectionPage extends StatefulWidget {
  final Recipe recipe;
  final Function(String, dynamic) onDataChanged;

  IngredientsSelectionPage({
    Key? key,
    required this.recipe,
    required this.onDataChanged,
  }) : super(key: key);

  @override
  _IngredientsSelectionPageState createState() =>
      _IngredientsSelectionPageState();
}

class _IngredientsSelectionPageState extends State<IngredientsSelectionPage> {
  List<Ingredient> availableIngredients = [
    Ingredient(
      imageUrl: 'lib/assets/images/pasta.webp',
      ingredientName: 'Pasta',
      baseAmount: 125,
      unit: 'g',
      servings: 2,
    ),
    Ingredient(
      imageUrl: 'lib/assets/images/tomato.webp',
      ingredientName: 'Tomato',
      baseAmount: 200,
      unit: 'g',
      servings: 2,
    ),
  ];
  List<Ingredient> selectedIngredients = [];

  @override
  void initState() {
    super.initState();
    // Initialize availableIngredients with data from your database
    // availableIngredients = getAllIngredients();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: availableIngredients.length,
      itemBuilder: (context, index) {
        var ingredient = availableIngredients[index];
        return CheckboxListTile(
          title: Text(ingredient.ingredientName),
          value: selectedIngredients.contains(ingredient),
          onChanged: (bool? value) {
            setState(() {
              if (value == true) {
                selectedIngredients.add(ingredient);
              } else {
                selectedIngredients.remove(ingredient);
              }
              widget.onDataChanged('ingredients', selectedIngredients);
            });
          },
        );
      },
    );
  }
}
