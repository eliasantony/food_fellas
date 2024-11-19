import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:food_fellas/src/widgets/recipeCard.dart';
import 'package:food_fellas/src/widgets/filterModal.dart';

class RecipesListScreen extends StatefulWidget {
  final Query baseQuery;
  final String title;

  RecipesListScreen({
    required this.baseQuery,
    required this.title,
  });

  @override
  _RecipesListScreenState createState() => _RecipesListScreenState();
}

class _RecipesListScreenState extends State<RecipesListScreen> {
  Map<String, dynamic> selectedFilters = {};
  final int pageSize = 10;
  DocumentSnapshot? lastDocument;
  bool isLoadingMore = false;
  bool hasMore = true;
  List<DocumentSnapshot> recipes = [];
  ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchRecipes();

    // Listen to scroll events to implement infinite scrolling
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 100 &&
          !isLoadingMore &&
          hasMore) {
        _fetchRecipes();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Fetch recipes with pagination
  void _fetchRecipes() async {
    if (isLoadingMore || !hasMore) return;

    setState(() {
      isLoadingMore = true;
    });

    Query recipesQuery = _buildRecipesQuery();

    QuerySnapshot querySnapshot;
    if (lastDocument == null) {
      print('Fetching first page');
      querySnapshot = await recipesQuery.limit(pageSize).get();
    } else {
      print('Fetching next page');
      querySnapshot = await recipesQuery
          .startAfterDocument(lastDocument!)
          .limit(pageSize)
          .get();
    }

    if (querySnapshot.docs.isEmpty) {
      print('No more recipes to fetch');
      setState(() {
        isLoadingMore = false;
        hasMore = false;
      });
      return;
    }

    // Apply ingredients filter client-side
    List<DocumentSnapshot> fetchedRecipes = querySnapshot.docs;

    if (selectedFilters.containsKey('ingredients') &&
        selectedFilters['ingredients'].isNotEmpty) {
      List<String> selectedIngredients = selectedFilters['ingredients'];

      fetchedRecipes = fetchedRecipes.where((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        List<dynamic> ingredientsList = data['ingredients'] ?? [];

        // Extract ingredient names from the ingredientsList
        List<String> ingredientNames =
            ingredientsList.map((recipeIngredientMap) {
          Map<String, dynamic> recipeIngredient =
              Map<String, dynamic>.from(recipeIngredientMap);
          Map<String, dynamic> ingredient =
              Map<String, dynamic>.from(recipeIngredient['ingredient'] ?? {});
          return ingredient['ingredientName']?.toString() ?? '';
        }).toList();

        // Check if the recipe contains all selected ingredients
        bool containsAllIngredients = selectedIngredients
            .every((ingredient) => ingredientNames.contains(ingredient));

        return containsAllIngredients;
      }).toList();
    }

    if (fetchedRecipes.isEmpty) {
      // No matching recipes in this batch, fetch next batch
      if (querySnapshot.docs.length < pageSize) {
        // No more data to fetch
        setState(() {
          isLoadingMore = false;
          hasMore = false;
        });
      } else {
        // Fetch next batch
        lastDocument = querySnapshot.docs.last;
        _fetchRecipes();
      }
      return;
    }

    // Update lastDocument to the last fetched document
    lastDocument = querySnapshot.docs.last;

    setState(() {
      recipes.addAll(fetchedRecipes);
      isLoadingMore = false;
      if (querySnapshot.docs.length < pageSize) {
        hasMore = false;
      }
    });
  }

  // Build the Firestore query with applied filters
  Query _buildRecipesQuery() {
    Query recipesQuery = widget.baseQuery;

    // Min rating filtering
    if (selectedFilters.containsKey('minRating')) {
      double minRating = selectedFilters['minRating'];
      print('Min rating: $minRating');
      recipesQuery = recipesQuery.where('averageRating',
          isGreaterThanOrEqualTo: minRating);
    }

    // Max cooking time filtering
    if (selectedFilters.containsKey('maxCookingTime')) {
      double maxCookingTime = selectedFilters['maxCookingTime'];
      print('Max cooking time: $maxCookingTime');
      recipesQuery =
          recipesQuery.where('totalTime', isLessThanOrEqualTo: maxCookingTime);
    }

    // AI-assisted filtering
    if (selectedFilters.containsKey('createdByAI')) {
      bool createdByAI = selectedFilters['createdByAI'];
      print('AI-assisted: $createdByAI');
      recipesQuery = recipesQuery.where('createdByAI', isEqualTo: createdByAI);
    }

    // Tags filtering
    if (selectedFilters.containsKey('tags') &&
        selectedFilters['tags'].isNotEmpty) {
      List<String> selectedTags = selectedFilters['tags'];
      print('Tags: $selectedTags');
      // Firestore allows 'array-contains-any' with up to 10 values
      recipesQuery =
          recipesQuery.where('tagsNames', arrayContainsAny: selectedTags);
    }
    return recipesQuery;
  }

  // Apply filters and reset pagination
  void _applyFilters(Map<String, dynamic> filters) {
    setState(() {
      selectedFilters = filters;
      recipes.clear();
      lastDocument = null;
      hasMore = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });

    _fetchRecipes();
  }

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
      recipes.clear();
      lastDocument = null;
      hasMore = true;
    });
    // Defer jumpTo until after the frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });

    _fetchRecipes();
  }

  @override
  Widget build(BuildContext context) {
    String title = widget.title;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _openFilterModal,
          ),
        ],
      ),
      body: Column(
        children: [
          if (selectedFilters.isNotEmpty) _buildActiveFilters(),
          Expanded(
            child: recipes.isEmpty && !isLoadingMore
                ? const Center(child: Text('No recipes found.'))
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: recipes.length + (isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index < recipes.length) {
                        return RecipeCard(
                          big: true,
                          recipeId: recipes[index].id,
                        );
                      } else {
                        // Show loading indicator at the bottom
                        return Center(child: CircularProgressIndicator());
                      }
                    },
                  ),
          ),
        ],
      ),
    );
  }

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
}
