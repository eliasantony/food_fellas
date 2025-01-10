import 'package:flutter/material.dart';

import '../../models/user_data.dart';
import 'cooking_skill_level_screen.dart';

class FavoriteCuisinesScreen extends StatefulWidget {
  final UserData userData;

  const FavoriteCuisinesScreen({Key? key, required this.userData})
      : super(key: key);

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
    {'label': 'Thai', 'icon': '🍜'},
    {'label': 'French', 'icon': '🥐'},
    {'label': 'Greek', 'icon': '🥗'},
    {'label': 'Korean', 'icon': '🍱'},
    {'label': 'Vietnamese', 'icon': '🍜'},
    {'label': 'Spanish', 'icon': '🥘'},
    {'label': 'Middle Eastern', 'icon': '🥙'},
    {'label': 'Caribbean', 'icon': '🍹'},
    {'label': 'African', 'icon': '🍛'},
    {'label': 'German', 'icon': '🥨'},
    {'label': 'Brazilian', 'icon': '🍖'},
    {'label': 'Peruvian', 'icon': '🍤'},
    {'label': 'Russian', 'icon': '🍲'},
    {'label': 'Turkish', 'icon': '🍢'},
    {'label': 'Other', 'icon': '🌍'},
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
        builder: (context) =>
            CookingSkillLevelScreen(userData: widget.userData),
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
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Do you have any favorite cuisines?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
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
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 32.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _navigateToNext,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Next',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
