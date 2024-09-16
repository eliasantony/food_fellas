import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  List<RecipeIngredient> selectedIngredients = []; // Now holds RecipeIngredient
  List<Ingredient> filteredIngredients = [];
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchIngredients();
  }

  Future<void> _fetchIngredients() async {
    try {
      // Try to fetch from cache first
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('ingredients')
          .where('approved', isEqualTo: true)
          .get(const GetOptions(source: Source.cache));

      if (snapshot.docs.isEmpty) {
        // If cache is empty, attempt to fetch from server
        final QuerySnapshot serverSnapshot = await FirebaseFirestore.instance
            .collection('ingredients')
            .where('approved', isEqualTo: true)
            .get(const GetOptions(source: Source.server));

        if (serverSnapshot.docs.isNotEmpty) {
          final ingredients = serverSnapshot.docs.map((doc) {
            return Ingredient.fromDocumentSnapshot(doc);
          }).toList();

          setState(() {
            availableIngredients = ingredients;
            filteredIngredients = ingredients;
          });
        } else {
          // Handle case where no data exists
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No ingredients found on server')),
          );
        }
      } else {
        // If cache has data, use it
        final ingredients = snapshot.docs.map((doc) {
          return Ingredient.fromDocumentSnapshot(doc);
        }).toList();

        setState(() {
          availableIngredients = ingredients;
          filteredIngredients = ingredients;
        });
      }
    } catch (e) {
      print('Error fetching ingredients: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load ingredients')),
      );
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

  @override
  Widget build(BuildContext context) {
    Map<String, List<Ingredient>> categorizedIngredients = {};

    for (var ingredient in filteredIngredients) {
      if (!categorizedIngredients.containsKey(ingredient.category)) {
        categorizedIngredients[ingredient.category] = [];
      }
      categorizedIngredients[ingredient.category]!.add(ingredient);
    }

    return Form(
      key: widget.formKey,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Search Ingredients',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _filterIngredients,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: categorizedIngredients.entries.length,
              itemBuilder: (context, index) {
                final entry = categorizedIngredients.entries.elementAt(index);
                return ExpansionTile(
                  title: Text(entry.key),
                  initiallyExpanded: true,
                  children: entry.value.map((ingredient) {
                    return CheckboxListTile(
                      title: Text(ingredient.ingredientName),
                      value: _isSelected(ingredient),
                      onChanged: (bool? value) {
                        _toggleIngredientSelection(value, ingredient);
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
