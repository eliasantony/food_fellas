import 'package:flutter/material.dart';
import '../widgets/horizontalRecipeRow.dart';
import 'addRecipeForm/addRecipe_form.dart';

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
            child: HorizontalRecipeRow(),
          ),
          const ListTile(
            title: Text('New Recipes'),
          ),
          Container(
            margin: const EdgeInsets.only(left: 8),
            child: HorizontalRecipeRow(),
          ),
          const ListTile(
            title: Text('Top Rated'),
          ),
          Container(
            margin: const EdgeInsets.only(left: 8),
            child: HorizontalRecipeRow(),
          ),
        ],
      ),
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
