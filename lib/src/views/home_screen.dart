import 'package:flutter/material.dart';
import 'package:food_fellas/main.dart';
import 'package:food_fellas/src/views/aichat_screen.dart';
import 'package:food_fellas/src/views/imageToRecipe_screen.dart';
import 'package:food_fellas/src/widgets/expandableFAB.dart';
import '../widgets/mockupHorizontalRecipeRow.dart';
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
      floatingActionButton: ExpandableFab(
        distance: 130,
        children: [
                    ActionButton(
            onPressed: () {
              mainPageKey.currentState?.onItemTapped(3); // Index of AIChatScreen
            },
            icon: const Icon(Icons.chat),
          ),
          ActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddRecipeForm()),
              );
            },
            icon: const Icon(Icons.create),
          ),
          ActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ImageToRecipeScreen()),
              );
            },
            icon: const Icon(Icons.camera_alt),
          ),
        ],
      ),
    );
  }
}
