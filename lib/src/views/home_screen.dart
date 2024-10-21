import 'package:flutter/material.dart';
import 'package:food_fellas/src/views/aichat_screen.dart';
import 'package:food_fellas/src/views/uploadPhoto_screen.dart';
import '../widgets/mockupHorizontalRecipeRow.dart';
import 'addRecipeForm/addRecipe_form.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FoodFellas'),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Search Bar',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const ListTile(
            title: Text('Recommended'),
          ),
          Container(
            margin: const EdgeInsets.only(left: 8),
            child: MockupHorizontalRecipeRow(),
          ),
          const ListTile(
            title: Text('New Recipes'),
          ),
          Container(
            margin: const EdgeInsets.only(left: 8),
            child: MockupHorizontalRecipeRow(),
          ),
          const ListTile(
            title: Text('Top Rated'),
          ),
          Container(
            margin: const EdgeInsets.only(left: 8),
            child: MockupHorizontalRecipeRow(),
          ),
        ],
      ),
      // TODO: Implement the ExpandableFab
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddRecipeForm()),
          );
        },
        child: const Icon(Icons.add),
        backgroundColor: Colors.green,
        tooltip: 'Add a Recipe',
      ),
    );
  }
}
