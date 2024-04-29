import 'package:flutter/material.dart';
import '../widgets/recipeCard.dart';
import '../widgets/verticalRecipeList.dart';

class SearchResultsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Results'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Search Bar',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          // Add category filters here
          Expanded(
            child: VerticalRecipeList(),
          ),
        ],
      ),
    );
  }
}
