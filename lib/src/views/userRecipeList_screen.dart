import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:food_fellas/src/widgets/recipeCard.dart';
import 'package:food_fellas/src/widgets/filterModal.dart';

class UserRecipesListScreen extends StatefulWidget {
  final String userId;
  final String displayName;
  final bool isCurrentUser;

  UserRecipesListScreen({
    required this.userId,
    required this.displayName,
    required this.isCurrentUser,
  });

  @override
  _UserRecipesListScreenState createState() => _UserRecipesListScreenState();
}

class _UserRecipesListScreenState extends State<UserRecipesListScreen> {
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
      querySnapshot = await recipesQuery.limit(pageSize).get();
    } else {
      querySnapshot = await recipesQuery
          .startAfterDocument(lastDocument!)
          .limit(pageSize)
          .get();
    }

    if (querySnapshot.docs.length < pageSize) {
      hasMore = false;
    }

    if (querySnapshot.docs.isNotEmpty) {
      lastDocument = querySnapshot.docs.last;
      setState(() {
        recipes.addAll(querySnapshot.docs);
      });
    }

    setState(() {
      isLoadingMore = false;
    });
  }

  // Build the Firestore query with applied filters
  Query _buildRecipesQuery() {
    Query recipesQuery = FirebaseFirestore.instance
        .collection('recipes')
        .where('authorId', isEqualTo: widget.userId);

    // Apply filters
    if (selectedFilters.containsKey('minRating')) {
      double minRating = selectedFilters['minRating'];
      recipesQuery = recipesQuery.where('averageRating',
          isGreaterThanOrEqualTo: minRating);
    }

    if (selectedFilters.containsKey('maxCookingTime')) {
      int maxCookingTime = selectedFilters['maxCookingTime'];
      recipesQuery =
          recipesQuery.where('totalTime', isLessThanOrEqualTo: maxCookingTime);
    }

    if (selectedFilters.containsKey('createdByAI')) {
      bool createdByAI = selectedFilters['createdByAI'];
      recipesQuery = recipesQuery.where('createdByAI', isEqualTo: createdByAI);
    }

    // Tags filtering
    if (selectedFilters.containsKey('tags') &&
        selectedFilters['tags'].isNotEmpty) {
      List<String> selectedTags = selectedFilters['tags'];
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
      _scrollController.jumpTo(0);
    });
    _fetchRecipes();
  }

  // Open the filter modal
  void _openFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return FilterModal(
          initialFilters: selectedFilters,
          onApply: (filters) {
            Navigator.pop(context);
            _applyFilters(filters);
          },
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
      _scrollController.jumpTo(0);
    });
    _fetchRecipes();
  }

  @override
  Widget build(BuildContext context) {
    String title = widget.isCurrentUser
        ? 'My Recipes'
        : '${widget.displayName}\'s Recipes';

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
                        final recipeData =
                            recipes[index].data() as Map<String, dynamic>;
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
            Chip(
              label: Text(tag),
              onDeleted: () => _removeFilter('tags', tag),
            ),
          );
        }
      } else if (key == 'minRating') {
        filterChips.add(
          Chip(
            label: Text('Rating ≥ ${value.toStringAsFixed(1)} ★'),
            onDeleted: () => _removeFilter(key, value),
          ),
        );
      } else if (key == 'maxCookingTime') {
        filterChips.add(
          Chip(
            label: Text('Time ≤ $value mins ⏱️'),
            onDeleted: () => _removeFilter(key, value),
          ),
        );
      } else if (key == 'createdByAI') {
        if (value == true) {
          filterChips.add(
            Chip(
              label: Text('AI-assisted'),
              onDeleted: () => _removeFilter(key, value),
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
