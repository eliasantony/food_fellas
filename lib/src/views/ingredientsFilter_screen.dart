// ingredient_filter_screen.dart
import 'package:flutter/material.dart';
import 'package:food_fellas/src/models/ingredient.dart';
import 'package:provider/provider.dart';
import 'package:food_fellas/providers/ingredientProvider.dart';

class IngredientFilterScreen extends StatefulWidget {
  final List<String> initialSelectedIngredients;

  IngredientFilterScreen({required this.initialSelectedIngredients});

  @override
  _IngredientFilterScreenState createState() => _IngredientFilterScreenState();
}

class _IngredientFilterScreenState extends State<IngredientFilterScreen> {
  List<String> selectedIngredients = [];
  List<Ingredient> availableIngredients = [];
  List<Ingredient> filteredIngredients = [];
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    selectedIngredients = List.from(widget.initialSelectedIngredients);
    _fetchIngredients();
  }

  void _fetchIngredients() {
    final ingredientProvider =
        Provider.of<IngredientProvider>(context, listen: false);

    if (!ingredientProvider.isLoaded) {
      ingredientProvider.fetchIngredients().then((_) {
        setState(() {
          availableIngredients = ingredientProvider.ingredients;
          filteredIngredients = availableIngredients;
        });
      });
    } else {
      setState(() {
        availableIngredients = ingredientProvider.ingredients;
        filteredIngredients = availableIngredients;
      });
    }
  }

  void _filterIngredients(String query) {
    setState(() {
      searchQuery = query;
      filteredIngredients = availableIngredients.where((ingredient) {
        return ingredient.ingredientName
            .toLowerCase()
            .contains(query.toLowerCase());
      }).toList();
    });
  }

  void _onDone() {
    Navigator.pop(context, selectedIngredients);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Ingredients'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search ingredients',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _filterIngredients,
            ),
          ),
          Expanded(
            child: _buildIngredientList(),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: _onDone,
          style: ElevatedButton.styleFrom(
            minimumSize:
                Size(double.infinity, 50), // Makes the button full-width
            backgroundColor: Theme.of(context).primaryColor,
          ),
          child: Text('Done',
              style: TextStyle(color: Theme.of(context).canvasColor)),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        decoration: const InputDecoration(
          labelText: 'Search ingredients',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: _filterIngredients,
      ),
    );
  }

  void _toggleIngredientSelection(bool? value, Ingredient ingredient) {
    setState(() {
      if (value != null && value) {
        if (selectedIngredients.length < 10 ||
            selectedIngredients.contains(ingredient.ingredientName)) {
          selectedIngredients.add(ingredient.ingredientName);
        }
      } else {
        selectedIngredients.remove(ingredient.ingredientName);
      }
    });
  }

  Widget _buildIngredientList() {
    if (filteredIngredients.isEmpty) {
      return Center(child: Text('No ingredients found.'));
    }

    // Build a Map of category to list of ingredients
    Map<String, List<Ingredient>> categorizedIngredients = {};

    for (var ingredient in filteredIngredients) {
      String category = ingredient.category ?? 'Other';
      if (!categorizedIngredients.containsKey(category)) {
        categorizedIngredients[category] = [];
      }
      categorizedIngredients[category]!.add(ingredient);
    }

    // Define the desired category order
    List<String> categoryOrder = [
      'Vegetable',
      'Fruit',
      'Grain',
      'Protein',
      'Dairy',
      'Spice & Seasoning',
      'Fat & Oil',
      'Herb',
      'Seafood',
      'Condiment',
      'Nuts & Seeds',
      'Legume',
      'Other',
    ];

    Map<String, String> categoryEmojis = {
      'Vegetable': '🥦',
      'Fruit': '🍎',
      'Grain': '🌾',
      'Protein': '🍖',
      'Dairy': '🧀',
      'Spice & Seasoning': '🌶️',
      'Fat & Oil': '🧈',
      'Herb': '🌿',
      'Seafood': '🐟',
      'Condiment': '🍯',
      'Nuts & Seeds': '🥜',
      'Legume': '🌰',
      'Other': '🍽️',
    };

    // Build the list of ExpansionTiles in the desired order
    List<Widget> categoryWidgets = [];

    for (String category in categoryOrder) {
      if (categorizedIngredients.containsKey(category)) {
        List<Ingredient> ingredients = categorizedIngredients[category]!;

        // Build the list of ingredients for this category
        List<Widget> ingredientWidgets = ingredients.map((ingredient) {
          final isSelected =
              selectedIngredients.contains(ingredient.ingredientName);
          final canSelectMore = selectedIngredients.length < 10 || isSelected;

          return CheckboxListTile(
            title: Text(ingredient.ingredientName),
            value: isSelected,
            onChanged: canSelectMore
                ? (bool? value) {
                    _toggleIngredientSelection(value, ingredient);
                  }
                : null,
          );
        }).toList();

        // Build the ExpansionTile for this category
        categoryWidgets.add(
          ExpansionTile(
            leading: Text(
              categoryEmojis[category] ?? '🍽️',
              style: TextStyle(fontSize: 24),
            ),
            title: Text(category),
            children: ingredientWidgets,
          ),
        );
      }
    }

    return ListView(
      children: categoryWidgets,
    );
  }
}
