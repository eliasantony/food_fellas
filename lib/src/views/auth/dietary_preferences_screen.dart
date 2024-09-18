import 'package:flutter/material.dart';
import 'package:food_fellas/src/models/user_data.dart';
import 'package:food_fellas/src/views/auth/favorite_cuisines_screen.dart';

class DietaryPreferencesScreen extends StatefulWidget {
  final UserData userData;
  
  const DietaryPreferencesScreen({Key? key, required this.userData}) : super(key: key);

  @override
  _DietaryPreferencesScreenState createState() =>
      _DietaryPreferencesScreenState();
}

class _DietaryPreferencesScreenState extends State<DietaryPreferencesScreen> {
  List<String> selectedPreferences = [];

  final List<Map<String, String>> preferences = [
    {'label': 'Vegetarian', 'icon': '🥕'},
    {'label': 'Vegan', 'icon': '🌱'},
    {'label': 'Gluten-Free', 'icon': '🍞'},
    {'label': 'Dairy-Free', 'icon': '🥛'},
    {'label': 'Nut-Free', 'icon': '🥜'},
    {'label': 'No Preferences', 'icon': '🍽️'},
  ];

  void _togglePreference(String preference) {
    setState(() {
      if (selectedPreferences.contains(preference)) {
        selectedPreferences.remove(preference);
      } else {
        selectedPreferences.add(preference);
      }
    });
  }

  void _navigateToNext() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FavoriteCuisinesScreen(userData: widget.userData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dietary Preferences'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Any dietary preferences we should know about?',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: preferences.map((pref) {
                  return ListTile(
                    leading: Text(pref['icon']!, style: TextStyle(fontSize: 24)),
                    title: Text(pref['label']!),
                    trailing: Checkbox(
                      value: selectedPreferences.contains(pref['label']),
                      onChanged: (bool? value) {
                        _togglePreference(pref['label']!);
                      },
                    ),
                    onTap: () => _togglePreference(pref['label']!),
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
