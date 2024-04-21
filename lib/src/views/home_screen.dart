import 'package:flutter/material.dart';
import '../widgets/horizontalRecipeRow.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('FoodFellas'),
      ),
      body: ListView(
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
          ListTile(
            title: Text('Recommended'),
          ),
          Container(
            margin: EdgeInsets.only(left: 8),
            child: HorizontalRecipeRow(),
          ),
          ListTile(
            title: Text('New Recipes'),
          ),
          Container(
            margin: EdgeInsets.only(left: 8),
            child: HorizontalRecipeRow(),
          ),
          ListTile(
            title: Text('Top Rated'),
          ),
          Container(
            margin: EdgeInsets.only(left: 8),
            child: HorizontalRecipeRow(),
          ),
        ],
      ),
    );
  }
}
