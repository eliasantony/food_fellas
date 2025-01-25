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
  bool allNotificationsEnabled = true;
  bool newFollowerEnabled = true;
  bool newRecipeEnabled = true;
  bool newCommentEnabled = true;
  bool weeklyRecommendationsEnabled = true;

  void _navigateToNext() {
    // Update userData with notification preferences
    widget.userData.allNotificationsEnabled = allNotificationsEnabled;

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stay in the loop with the latest updates!',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),
            SwitchListTile(
              title: Text('Enable Notifications'),
              value: allNotificationsEnabled,
              onChanged: (bool value) {
                setState(() {
                  allNotificationsEnabled = value;
                  if (!value) {
                    newFollowerEnabled = false;
                    newRecipeEnabled = false;
                    newCommentEnabled = false;
                    weeklyRecommendationsEnabled = false;
                  }
                });
              },
            ),
            if (allNotificationsEnabled) ...[
              SwitchListTile(
                title: Text('New Follower'),
                value: newFollowerEnabled,
                onChanged: (bool value) {
                  setState(() => newFollowerEnabled = value);
                },
              ),
              SwitchListTile(
                title: Text('New Recipe from Following'),
                value: newRecipeEnabled,
                onChanged: (bool value) {
                  setState(() => newRecipeEnabled = value);
                },
              ),
              SwitchListTile(
                title: Text('New Comment'),
                value: newCommentEnabled,
                onChanged: (bool value) {
                  setState(() => newCommentEnabled = value);
                },
              ),
              SwitchListTile(
                title: Text('Weekly Recommendations'),
                value: weeklyRecommendationsEnabled,
                onChanged: (bool value) {
                  setState(() => weeklyRecommendationsEnabled = value);
                },
              ),
            ],
            Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Save preferences to userData
                  widget.userData.allNotificationsEnabled =
                      allNotificationsEnabled;
                  widget.userData.notifications = {
                    'newFollower': newFollowerEnabled,
                    'newRecipeFromFollowing': newRecipeEnabled,
                    'newComment': newCommentEnabled,
                    'weeklyRecommendations': weeklyRecommendationsEnabled,
                  };
                  _navigateToNext();
                },
                child: Text('Finish up!'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
