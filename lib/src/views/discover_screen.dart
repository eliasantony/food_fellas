import 'package:flutter/material.dart';
import '../widgets/categoryCard.dart';

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
            child: GridView.count(
              primary: false,
              padding: const EdgeInsets.all(20),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              children: <Widget>[
                CategoryCard(
                  title: 'Desserts',
                  iconData:
                      Icons.cake, // Choose an icon that represents the category
                  gradientColors: [Colors.pink, Colors.redAccent],
                ),
                CategoryCard(
                  title: 'Main Course',
                  iconData: Icons
                      .fastfood, // Choose an icon that represents the category
                  gradientColors: [Colors.orange, Colors.deepOrange],
                ),
                CategoryCard(
                  title: 'Appetizers',
                  iconData: Icons.local_dining,
                  gradientColors: [Colors.green, Colors.lightGreenAccent],
                ),
                CategoryCard(
                  title: 'Drinks',
                  iconData: Icons.local_cafe,
                  gradientColors: [Colors.blue, Colors.lightBlueAccent],
                ),
                CategoryCard(
                  title: 'Breakfast',
                  iconData: Icons.free_breakfast,
                  gradientColors: [Colors.purpleAccent, Colors.deepPurple],
                ),
                CategoryCard(
                  title: 'Lunch',
                  iconData: Icons.fastfood,
                  gradientColors: [Colors.orangeAccent, Colors.deepOrange],
                ),
                CategoryCard(
                  title: 'Dinner',
                  iconData: Icons.restaurant,
                  gradientColors: [Colors.red, Colors.redAccent],
                ),
                CategoryCard(
                  title: 'Snacks',
                  iconData: Icons.local_pizza,
                  gradientColors: [Colors.yellow, Colors.amber],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
