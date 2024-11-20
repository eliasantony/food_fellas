import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_fellas/src/utils/dialog_utils.dart';
import 'package:food_fellas/src/widgets/filterModal.dart';
import '../widgets/recipeCard.dart';

class CollectionDetailScreen extends StatefulWidget {
  final String collectionId;
  final String collectionEmoji;
  final String collectionName;
  final bool collectionVisibility;

  CollectionDetailScreen({
    required this.collectionId,
    required this.collectionEmoji,
    required this.collectionName,
    required this.collectionVisibility,
  });

  @override
  _CollectionDetailScreenState createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<DocumentSnapshot> recipes = [];
  bool isLoading = true;
  Map<String, dynamic> selectedFilters = {};

  @override
  void initState() {
    super.initState();
    _fetchRecipes();
  }

  // Fetch recipes in batches due to Firestore's 'whereIn' limitation
  void _fetchRecipes() async {
    final user = _auth.currentUser;
    if (user == null) {
      // Handle user not logged in
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      final collectionSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('collections')
          .doc(widget.collectionId)
          .get();

      if (!collectionSnapshot.exists) {
        // Handle collection not found
        setState(() {
          isLoading = false;
        });
        return;
      }

      final collectionData = collectionSnapshot.data() as Map<String, dynamic>;
      List<dynamic> recipeIds = collectionData['recipes'] ?? [];

      if (recipeIds.isEmpty) {
        // No recipes in the collection
        setState(() {
          recipes = [];
          isLoading = false;
        });
        return;
      }

      // Fetch recipes by IDs in batches
      List<DocumentSnapshot> fetchedRecipes = [];

      const int batchSize = 10;
      for (int i = 0; i < recipeIds.length; i += batchSize) {
        var batchIds = recipeIds.sublist(
            i,
            i + batchSize > recipeIds.length
                ? recipeIds.length
                : i + batchSize);

        QuerySnapshot querySnapshot = await FirebaseFirestore.instance
            .collection('recipes')
            .where(FieldPath.documentId, whereIn: batchIds)
            .get();

        fetchedRecipes.addAll(querySnapshot.docs);
      }

      setState(() {
        recipes = fetchedRecipes;
        isLoading = false;
      });
    } catch (e) {
      // Handle errors
      setState(() {
        isLoading = false;
      });
    }
  }

  // Apply filters to the recipes list
  void _applyFilters(Map<String, dynamic> filters) {
    setState(() {
      selectedFilters = filters;
    });
  }

  // Open the filter modal
  void _openFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.8,
          child: FilterModal(
            initialFilters: selectedFilters,
            onApply: (filters) {
              Navigator.pop(context);
              _applyFilters(filters);
            },
          ),
        );
      },
    );
  }

  // Remove a specific filter
  void _removeFilter(String key, dynamic value) {
    setState(() {
      if (key == 'tags') {
        List<String> selectedTags = selectedFilters['tags'] ?? [];
        selectedTags.remove(value);
        if (selectedTags.isEmpty) {
          selectedFilters.remove('tags');
        } else {
          selectedFilters['tags'] = selectedTags;
        }
      } else {
        selectedFilters.remove(key);
      }
    });
  }

  // Build active filter chips
  Widget _buildActiveFilters() {
    List<Widget> filterChips = [];

    selectedFilters.forEach((key, value) {
      if (key == 'tags') {
        List<String> selectedTags = value;
        for (String tag in selectedTags) {
          filterChips.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Chip(
                label: Text(tag),
                onDeleted: () => _removeFilter('tags', tag),
                deleteIconColor: Theme.of(context).primaryColor,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Theme.of(context).primaryColor),
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
          );
        }
      } else if (key == 'minRating') {
        filterChips.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Chip(
              label: Text('Rating ≥ ${value.toStringAsFixed(1)} ⭐'),
              onDeleted: () => _removeFilter(key, value),
              deleteIconColor: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Theme.of(context).primaryColor),
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
          ),
        );
      } else if (key == 'maxCookingTime') {
        filterChips.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Chip(
              label: Text('Time ≤ $value mins ⏱️'),
              onDeleted: () => _removeFilter(key, value),
              deleteIconColor: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Theme.of(context).primaryColor),
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
          ),
        );
      } else if (key == 'ingredients') {
        List<String> selectedIngredients = value;
        for (String ingredient in selectedIngredients) {
          filterChips.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Chip(
                label: Text(ingredient),
                onDeleted: () => _removeFilter('ingredients', ingredient),
                deleteIconColor: Theme.of(context).primaryColor,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Theme.of(context).primaryColor),
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
          );
        }
      } else if (key == 'createdByAI') {
        if (value == true) {
          filterChips.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Chip(
                label: Text('🤖 AI-assisted'),
                onDeleted: () => _removeFilter(key, value),
                deleteIconColor: Theme.of(context).primaryColor,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Theme.of(context).primaryColor),
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
          );
        }
      }
    });

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.0),
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: filterChips,
      ),
    );
  }

  // Apply selected filters to the list of recipes
  List<DocumentSnapshot> _filterRecipes(List<DocumentSnapshot> recipes) {
    List<DocumentSnapshot> filteredRecipes = recipes;

    // Apply each filter condition
    if (selectedFilters.containsKey('minRating')) {
      double minRating = selectedFilters['minRating'];
      filteredRecipes = filteredRecipes.where((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        double averageRating = data['averageRating']?.toDouble() ?? 0.0;
        return averageRating >= minRating;
      }).toList();
    }

    if (selectedFilters.containsKey('maxCookingTime')) {
      double maxCookingTime = selectedFilters['maxCookingTime'];
      filteredRecipes = filteredRecipes.where((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        double totalTime = data['totalTime']?.toDouble() ?? 0.0;
        return totalTime <= maxCookingTime;
      }).toList();
    }

    if (selectedFilters.containsKey('createdByAI')) {
      bool createdByAI = selectedFilters['createdByAI'];
      filteredRecipes = filteredRecipes.where((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        bool isCreatedByAI = data['createdByAI'] ?? false;
        return isCreatedByAI == createdByAI;
      }).toList();
    }

    if (selectedFilters.containsKey('tags') &&
        selectedFilters['tags'].isNotEmpty) {
      List<String> selectedTags = selectedFilters['tags'];
      filteredRecipes = filteredRecipes.where((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        List<dynamic> tagsNames = data['tagsNames'] ?? [];
        return selectedTags.every((tag) => tagsNames.contains(tag));
      }).toList();
    }

    if (selectedFilters.containsKey('ingredients') &&
        selectedFilters['ingredients'].isNotEmpty) {
      List<String> selectedIngredients = selectedFilters['ingredients'];
      filteredRecipes = filteredRecipes.where((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        List<dynamic> ingredientsList = data['ingredients'] ?? [];

        // Extract ingredient names
        List<String> ingredientNames =
            ingredientsList.map((recipeIngredientMap) {
          Map<String, dynamic> recipeIngredient =
              Map<String, dynamic>.from(recipeIngredientMap);
          Map<String, dynamic> ingredient =
              Map<String, dynamic>.from(recipeIngredient['ingredient'] ?? {});
          return ingredient['ingredientName']?.toString() ?? '';
        }).toList();

        // Check if recipe contains all selected ingredients
        bool containsAllIngredients = selectedIngredients
            .every((ingredient) => ingredientNames.contains(ingredient));

        return containsAllIngredients;
      }).toList();
    }

    return filteredRecipes;
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return Scaffold(
        body: Center(child: Text('User not logged in')),
      );
    }

    String title = '${widget.collectionEmoji} ${widget.collectionName}';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _openFilterModal,
          ),
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () {
              showCreateCollectionDialog(
                context,
                initialName: widget.collectionName,
                initialIcon: widget.collectionEmoji,
                initialVisibility: widget.collectionVisibility,
                collectionId: widget.collectionId,
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : recipes.isEmpty
              ? Center(child: Text('No recipes in this collection.'))
              : Column(
                  children: [
                    if (selectedFilters.isNotEmpty) _buildActiveFilters(),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _filterRecipes(recipes).length,
                        itemBuilder: (context, index) {
                          DocumentSnapshot recipeDoc =
                              _filterRecipes(recipes)[index];
                          return RecipeCard(
                            recipeId: recipeDoc.id,
                            big: true,
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
