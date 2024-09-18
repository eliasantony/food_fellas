import 'package:flutter/material.dart';

import '../../models/user_data.dart';
import 'cooking_skill_level_screen.dart';

class FavoriteCuisinesScreen extends StatefulWidget {
  final UserData userData;

  const FavoriteCuisinesScreen({Key? key, required this.userData}) : super(key: key);

  @override
  _FavoriteCuisinesScreenState createState() => _FavoriteCuisinesScreenState();
}

class _FavoriteCuisinesScreenState extends State<FavoriteCuisinesScreen> {
  List<String> selectedCuisines = [];

  final List<Map<String, String>> cuisines = [
    {'label': 'Italian', 'icon': '🍕'},
    {'label': 'Mexican', 'icon': '🌮'},
    {'label': 'Chinese', 'icon': '🥡'},
    {'label': 'Indian', 'icon': '🍛'},
    {'label': 'Japanese', 'icon': '🍣'},
    {'label': 'Mediterranean', 'icon': '🥙'},
    {'label': 'American', 'icon': '🍔'},
  ];

  void _toggleCuisine(String cuisine) {
    setState(() {
      if (selectedCuisines.contains(cuisine)) {
        selectedCuisines.remove(cuisine);
      } else {
        selectedCuisines.add(cuisine);
      }
    });
  }

  void _navigateToNext() {
    // Update userData with selected cuisines
    widget.userData.favoriteCuisines = selectedCuisines;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CookingSkillLevelScreen(userData: widget.userData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Favorite Cuisines'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Which cuisines make your mouth water?',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: cuisines.map((cuisine) {
                  return ListTile(
                    leading:
                        Text(cuisine['icon']!, style: TextStyle(fontSize: 24)),
                    title: Text(cuisine['label']!),
                    trailing: Checkbox(
                      value: selectedCuisines.contains(cuisine['label']),
                      onChanged: (bool? value) {
                        _toggleCuisine(cuisine['label']!);
                      },
                    ),
                    onTap: () => _toggleCuisine(cuisine['label']!),
                  );
                }).toList(),
              ),
            ),
            ElevatedButton(
              onPressed: _navigateToNext,
              child: Text('Next'),
            ),
          ],
        ),
      ),
    );
  }
}
