import 'package:flutter/material.dart';

class DiscoverScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Discover'),
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
            child: ListView.builder(
              itemCount: 10, // replace with actual number of recipes
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text('Recipe ${index+1}'),
                  // Add other recipe details here
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
