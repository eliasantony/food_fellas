import 'package:flutter/material.dart';
import 'package:food_fellas/src/views/auth/notification_preferences_screen.dart';

import '../../models/user_data.dart';

class CookingSkillLevelScreen extends StatefulWidget {
  final UserData userData;

  const CookingSkillLevelScreen({Key? key, required this.userData})
      : super(key: key);

  @override
  _CookingSkillLevelScreenState createState() =>
      _CookingSkillLevelScreenState();
}

class _CookingSkillLevelScreenState extends State<CookingSkillLevelScreen> {
  String? selectedSkillLevel;

  final List<Map<String, String>> skillLevels = [
    {
      'label': 'Beginner',
      'description': 'I\'m just starting out',
      'icon': '🥄'
    },
    {
      'label': 'Intermediate',
      'description': 'I\'ve got some experience',
      'icon': '🥘'
    },
    {'label': 'Expert', 'description': 'I\'m a pro chef!', 'icon': '👨🏻‍🍳'},
  ];

  void _navigateToNext() {
    // Update userData with selected skill level
    widget.userData.cookingSkillLevel = selectedSkillLevel;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            NotificationPreferencesScreen(userData: widget.userData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cooking Skill Level'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'How would you rate your cooking skills?',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),
            ...skillLevels.map((skill) {
              return ListTile(
                leading: Text(skill['icon']!, style: TextStyle(fontSize: 24)),
                title: Text(skill['label']!),
                subtitle: Text(skill['description']!),
                trailing: Radio<String>(
                  value: skill['label']!,
                  groupValue: selectedSkillLevel,
                  onChanged: (String? value) {
                    setState(() {
                      selectedSkillLevel = value;
                    });
                  },
                ),
                onTap: () {
                  setState(() {
                    selectedSkillLevel = skill['label'];
                  });
                },
              );
            }).toList(),
            Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: selectedSkillLevel != null ? _navigateToNext : null,
                child: Text('Next'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
