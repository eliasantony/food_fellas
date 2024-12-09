import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_fellas/providers/ingredientProvider.dart';
import 'package:provider/provider.dart';
import '../../models/recipeIngredient.dart';
import '../../models/ingredient.dart';
import '../../models/recipe.dart';

class IngredientsSelectionPage extends StatefulWidget {
  final Recipe recipe;
  final Function(String, dynamic) onDataChanged;
  final GlobalKey<FormState> formKey;

  IngredientsSelectionPage({
    Key? key,
    required this.recipe,
    required this.onDataChanged,
    required this.formKey,
  }) : super(key: key);

  @override
  _IngredientsSelectionPageState createState() =>
      _IngredientsSelectionPageState();
}

class _IngredientsSelectionPageState extends State<IngredientsSelectionPage> {
  List<Ingredient> availableIngredients = [];
  List<RecipeIngredient> selectedIngredients = [];
  List<Ingredient> filteredIngredients = [];
  String searchQuery = '';
  bool showAddIngredientOption = false;

  @override
  void initState() {
    super.initState();
    super.initState();
    final ingredientProvider =
        Provider.of<IngredientProvider>(context, listen: false);

    if (!ingredientProvider.isLoaded) {
      ingredientProvider.fetchIngredients().then((_) {
        setState(() {
          availableIngredients = ingredientProvider.ingredients;
        });
      });
    } else {
      setState(() {
        availableIngredients = ingredientProvider.ingredients;
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

      // If no matching ingredients and query is not empty, show an option to add new ingredient
      if (filteredIngredients.isEmpty && query.isNotEmpty) {
        showAddIngredientOption = true;
      } else {
        showAddIngredientOption = false;
      }
    });
  }

  bool _isSelected(Ingredient ingredient) {
    return widget.recipe.ingredients
        .any((ri) => ri.ingredient.ingredientName == ingredient.ingredientName);
  }

  void _toggleIngredientSelection(bool? isSelected, Ingredient ingredient) {
    setState(() {
      if (isSelected == true) {
        widget.recipe.ingredients.add(
          RecipeIngredient(ingredient: ingredient),
        );
      } else {
        widget.recipe.ingredients.removeWhere(
          (ri) => ri.ingredient.ingredientName == ingredient.ingredientName,
        );
      }
      widget.onDataChanged('ingredients', widget.recipe.ingredients);
    });
  }

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

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (widget.recipe.ingredients.isNotEmpty)
                    _buildSelectedIngredientsSection(),
                  Divider(),
                  searchQuery.isNotEmpty
                      ? _buildSearchResults()
                      : _buildCategorizedIngredients(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        decoration: const InputDecoration(
          labelText: 'Search or add ingredients', // Updated placeholder
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: _filterIngredients,
      ),
    );
  }

  void _addNewIngredient(String ingredientName) async {
    // Show dialog to select category
    String? selectedCategory = await _showCategorySelectionDialog();
    if (selectedCategory != null) {
      Ingredient newIngredient = Ingredient(
        ingredientName: ingredientName,
        category: selectedCategory,
        approved: false,
      );

      // Add to Firestore
      final ingredientsCollection =
          FirebaseFirestore.instance.collection('ingredients');
      await ingredientsCollection.add(newIngredient.toJson());

      // Update local lists
      setState(() {
        availableIngredients.add(newIngredient);
        filteredIngredients.add(newIngredient);
        showAddIngredientOption = false;

        // Automatically select the new ingredient
        _toggleIngredientSelection(true, newIngredient);
      });
    }
  }

  Future<String?> _showCategorySelectionDialog() async {
    List<String> categories = [
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

    String? selectedCategory;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Category'),
          content: DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
            ),
            items: categories.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (newValue) {
              selectedCategory = newValue;
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedCategory != null) {
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a category')),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    return selectedCategory;
  }

  Widget _buildSearchResults() {
    List<Ingredient> allResults = filteredIngredients;

    List<Widget> children = [];

    for (int index = 0;
        index < allResults.length + (showAddIngredientOption ? 1 : 0);
        index++) {
      if (index == allResults.length && showAddIngredientOption) {
        // Show 'Add Ingredient' option
        children.add(
          ListTile(
            leading: const Icon(Icons.add),
            title: Text('Add "$searchQuery" as a new ingredient'),
            onTap: () {
              _addNewIngredient(searchQuery);
            },
          ),
        );
      } else {
        final ingredient = allResults[index];
        bool isSelected = _isSelected(ingredient);
        children.add(
          CheckboxListTile(
            title: Row(
              children: [
                Text(ingredient.ingredientName),
                if (!ingredient.approved)
                  const Text(
                    ' *',
                    style: TextStyle(color: Colors.red),
                  ),
              ],
            ),
            value: isSelected,
            onChanged: (bool? value) {
              _toggleIngredientSelection(value, ingredient);
            },
          ),
        );
      }
    }

    return Column(
      children: children,
    );
  }

  Widget _buildSelectedIngredientsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Selected Ingredients',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Column(
          children: widget.recipe.ingredients.map((recipeIngredient) {
            final ingredient = recipeIngredient.ingredient;
            return CheckboxListTile(
              title: Row(
                children: [
                  Text(ingredient.ingredientName),
                  if (!ingredient.approved)
                    const Text(
                      ' *',
                      style: TextStyle(color: Colors.red),
                    ),
                ],
              ),
              value: true,
              onChanged: (bool? value) {
                if (value == false) {
                  _toggleIngredientSelection(false, ingredient);
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCategorizedIngredients() {
    // Build a Map of category to list of ingredients
    Map<String, List<Ingredient>> categorizedIngredients = {};

    for (var ingredient in availableIngredients) {
      if (!categorizedIngredients.containsKey(ingredient.category)) {
        categorizedIngredients[ingredient.category] = [];
      }
      categorizedIngredients[ingredient.category]!.add(ingredient);
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

    // Build the list of ExpansionTiles in the desired order
    List<Widget> categoryWidgets = [];

    for (String category in categoryOrder) {
      if (categorizedIngredients.containsKey(category)) {
        List<Ingredient> ingredients = categorizedIngredients[category]!;

        // Build the list of ingredients for this category
        List<Widget> ingredientWidgets = ingredients.map((ingredient) {
          return CheckboxListTile(
            title: Row(
              children: [
                Text(ingredient.ingredientName),
                if (!ingredient.approved)
                  const Text(
                    ' *',
                    style: TextStyle(color: Colors.red),
                  ),
              ],
            ),
            value: _isSelected(ingredient),
            onChanged: (bool? value) {
              _toggleIngredientSelection(value, ingredient);
            },
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
            // Optionally, set initiallyExpanded if desired
            // initiallyExpanded: true,
            children: ingredientWidgets,
          ),
        );
      }
    }

    return Column(
      children: categoryWidgets,
    );
  }
}
