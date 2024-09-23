import 'package:flutter/material.dart';
import 'package:food_fellas/src/views/auth/final_welcome_screen.dart';

import '../../models/user_data.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  final UserData userData;

  const NotificationPreferencesScreen({Key? key, required this.userData})
      : super(key: key);

  @override
  _NotificationPreferencesScreenState createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  bool notificationsEnabled = true;

  void _navigateToNext() {
    // Update userData with notification preferences
    widget.userData.notificationsEnabled = notificationsEnabled;

    // Navigate to the next screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FinalWelcomeScreen(userData: widget.userData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notification Preferences'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Stay in the loop with the latest recipes and tips!',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),
            SwitchListTile(
              title: Text('Enable Notifications'),
              value: notificationsEnabled,
              onChanged: (bool value) {
                setState(() {
                  notificationsEnabled = value;
                });
              },
            ),
            Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _navigateToNext,
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
