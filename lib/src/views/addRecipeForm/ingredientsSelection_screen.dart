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
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final ingredientProvider =
        Provider.of<IngredientProvider>(context, listen: false);

    if (!ingredientProvider.isLoaded) {
      ingredientProvider.fetchIngredients(includeUnapproved: true).then((_) {
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterIngredients(String query) {
    final trimmedQuery = query.trim();
    setState(() {
      searchQuery = trimmedQuery;
      filteredIngredients = availableIngredients.where((ingredient) {
        return ingredient.ingredientName
            .toLowerCase()
            .contains(trimmedQuery.toLowerCase());
      }).toList();

      // Determine if any ingredient's name exactly matches the query (ignoring case)
      bool exactMatchFound = availableIngredients.any((ingredient) =>
          ingredient.ingredientName.toLowerCase() ==
          trimmedQuery.toLowerCase());

      // If the trimmed query is not empty and no exact match is found, show add option.
      showAddIngredientOption = trimmedQuery.isNotEmpty && !exactMatchFound;
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
                  _buildSelectedIngredientsSection(),
                  const Divider(),
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
        controller: _searchController,
        decoration: InputDecoration(
          labelText: 'Search or add ingredients',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _filterIngredients('');
                  },
                )
              : null,
        ),
        onChanged: (query) {
          _filterIngredients(query);
          setState(() {}); // Triggers rebuild to update the suffixIcon state.
        },
      ),
    );
  }

  void _addNewIngredient(String ingredientName) async {
    // Use the improved dialog to confirm the ingredient name and select a category.
    Map<String, String>? result =
        await _showAddNewIngredientDialog(ingredientName);

    if (result != null) {
      String newName = result['name']!.trim().toLowerCase(); // Normalize input
      String category = result['category']!;

      final ingredientsCollection =
          FirebaseFirestore.instance.collection('ingredients');

      // Check if ingredient already exists
      final existingIngredientQuery = await ingredientsCollection
          .where('ingredientName', isEqualTo: newName)
          .get();

      if (existingIngredientQuery.docs.isNotEmpty) {
        // If the ingredient already exists, show a message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ingredient "$newName" already exists.')),
        );
        return;
      }

      // If not found, add the new ingredient
      Ingredient newIngredient = Ingredient(
        ingredientName: newName,
        category: category,
        approved: false,
      );

      try {
        await ingredientsCollection.add(newIngredient.toJson());

        // Update local lists and automatically select the new ingredient.
        setState(() {
          availableIngredients.add(newIngredient);
          filteredIngredients.add(newIngredient);
          showAddIngredientOption = false;
          _toggleIngredientSelection(true, newIngredient);
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add ingredient: $e')),
        );
      }
    }
  }

  Future<Map<String, String>?> _showAddNewIngredientDialog(
      String initialName) async {
    // List of categories (you may extract this to a constant elsewhere)
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

    String? newIngredientName = initialName;
    String? selectedCategory;

    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Ingredient'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Confirm ingredient name and select a category:'),
              TextFormField(
                textCapitalization: TextCapitalization.words,
                initialValue: initialName,
                decoration: const InputDecoration(labelText: 'Ingredient Name'),
                onChanged: (value) {
                  newIngredientName = value;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: categories.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Row(
                      children: [
                        Text(categoryEmojis[value] ?? '🍽️'),
                        const SizedBox(width: 8),
                        Text(value),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (newValue) {
                  selectedCategory = newValue;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (newIngredientName?.trim().isNotEmpty == true &&
                    selectedCategory != null) {
                  Navigator.of(context).pop({
                    'name': newIngredientName!.trim(),
                    'category': selectedCategory!,
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Please enter a name and select a category')),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
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
            visualDensity: const VisualDensity(vertical: -4, horizontal: 0),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
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
    return ExpansionTile(
      leading: Text(
        '✅',
        style: const TextStyle(fontSize: 24),
      ),
      title: const Text('Selected Ingredients'),
      initiallyExpanded:
          (widget.recipe.createdByAI == true || widget.recipe.authorId != null)
              ? true
              : false,
      children: widget.recipe.ingredients.map((recipeIngredient) {
        final ingredient = recipeIngredient.ingredient;
        return CheckboxListTile(
          visualDensity: const VisualDensity(vertical: -4, horizontal: 0),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
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
    );
  }

  Widget _buildCategorizedIngredients() {
    // Define the correct categories
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

    // Map of categories to ingredients
    Map<String, List<Ingredient>> categorizedIngredients = {};
    Set<String> unknownCategories = {}; // Track unknown categories

    for (var ingredient in availableIngredients) {
      // Trim and normalize the category name
      String normalizedCategory = ingredient.category.trim();

      // Ensure ingredient has a valid name
      if (ingredient.ingredientName == null ||
          ingredient.ingredientName.trim().isEmpty ||
          ingredient.ingredientName.toLowerCase() == "unknown") {
        continue; // Skip invalid or unknown ingredients
      }

      // If category is unknown, track it but still show the ingredient
      if (!categoryOrder.contains(normalizedCategory)) {
        unknownCategories.add(normalizedCategory);
        normalizedCategory = 'Other';
      }

      // Add the ingredient under its category
      categorizedIngredients.putIfAbsent(normalizedCategory, () => []);
      categorizedIngredients[normalizedCategory]!.add(ingredient);
    }

    // Log unknown categories once
    if (unknownCategories.isNotEmpty) {
      debugPrint('Unknown categories found: ${unknownCategories.join(', ')}');
    }

    // Build UI
    List<Widget> categoryWidgets = [];
    for (String category in categoryOrder) {
      if (categorizedIngredients.containsKey(category)) {
        List<Ingredient> ingredients = categorizedIngredients[category]!;

        // Sort alphabetically
        ingredients.sort((a, b) => a.ingredientName
            .toLowerCase()
            .compareTo(b.ingredientName.toLowerCase()));

        List<Widget> ingredientWidgets = ingredients.map((ingredient) {
          return CheckboxListTile(
            visualDensity: const VisualDensity(vertical: -4, horizontal: 0),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
            title: Text(
                ingredient.ingredientName), // Ensure correct name is displayed
            value: _isSelected(ingredient),
            onChanged: (bool? value) {
              _toggleIngredientSelection(value, ingredient);
            },
          );
        }).toList();

        categoryWidgets.add(
          ExpansionTile(
            leading: Text(
              categoryEmojis[category] ?? '🍽️',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            title: Text(category),
            children: ingredientWidgets,
          ),
        );
      }
    }

    return Column(children: categoryWidgets);
  }
}
