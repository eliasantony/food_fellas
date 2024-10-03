import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_fellas/providers/recipeProvider.dart';
import '../widgets/categoryCard.dart';
import '../widgets/verticalRecipeColumn.dart';
import 'package:provider/provider.dart';

class DiscoverScreen extends StatefulWidget {
  @override
  _DiscoverScreenState createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  String _searchQuery = '';
  List<String> _selectedCategories = [];

  @override
  Widget build(BuildContext context) {
    final recipeProvider = Provider.of<RecipeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Discover'),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Search Recipes',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim();
                });
              },
            ),
          ),
          // Category Filters
          Container(
            height: 80,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildCategoryChip('Desserts', '🍰'),
                _buildCategoryChip('Main Course', '🍝'),
                _buildCategoryChip('Appetizers', '🥗'),
                _buildCategoryChip('Drinks', '🍹'),
                // Add more categories as needed
              ],
            ),
          ),
          // Recipe List
          Expanded(
            child: _buildRecipeList(recipeProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String categoryName, String emoji) {
    bool isSelected = _selectedCategories.contains(categoryName);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: FilterChip(
        label: Text('$emoji $categoryName'),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            if (selected) {
              _selectedCategories.add(categoryName);
            } else {
              _selectedCategories.remove(categoryName);
            }
          });
        },
      ),
    );
  }

  Widget _buildRecipeList(RecipeProvider recipeProvider) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getRecipeQuery().snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error fetching recipes'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        final recipes = snapshot.data!.docs;
        final recipeIds = recipes.map((doc) => doc.id).toList();

        return VerticalRecipeColumn(recipeIds: recipeIds);
      },
    );
  }

  Query _getRecipeQuery() {
    CollectionReference recipesRef =
        FirebaseFirestore.instance.collection('recipes');

    Query query = recipesRef;

    if (_searchQuery.isNotEmpty) {
      query = query.where('title', isGreaterThanOrEqualTo: _searchQuery);
      query =
          query.where('title', isLessThanOrEqualTo: _searchQuery + '\uf8ff');
    }

    if (_selectedCategories.isNotEmpty) {
      query = query.where('tags', arrayContainsAny: _selectedCategories);
    }

    return query;
  }
}
