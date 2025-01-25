import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SettingsNotificationPreferencesScreen extends StatefulWidget {
  const SettingsNotificationPreferencesScreen({Key? key}) : super(key: key);

  @override
  _SettingsNotificationPreferencesScreenState createState() =>
      _SettingsNotificationPreferencesScreenState();
}

class _SettingsNotificationPreferencesScreenState
    extends State<SettingsNotificationPreferencesScreen> {
  bool allNotificationsEnabled = true;
  bool newFollowerEnabled = true;
  bool newRecipeEnabled = true;
  bool newCommentEnabled = true;
  bool weeklyRecommendationsEnabled = true;

  bool isLoading = true; // Show loading state initially

  @override
  void initState() {
    super.initState();
    _fetchNotificationPreferences();
  }

  Future<void> _fetchNotificationPreferences() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        final data = doc.data();
        if (data != null && data['notifications'] != null) {
          setState(() {
            allNotificationsEnabled = data['notificationsEnabled'] ?? true;
            newFollowerEnabled = data['notifications']['newFollower'] ?? true;
            newRecipeEnabled =
                data['notifications']['newRecipeFromFollowing'] ?? true;
            newCommentEnabled = data['notifications']['newComment'] ?? true;
            weeklyRecommendationsEnabled =
                data['notifications']['weeklyRecommendations'] ?? true;
            isLoading = false; // Stop loading
          });
        } else {
          setState(() {
            isLoading = false; // Stop loading even if no preferences found
          });
        }
      } catch (e) {
        print('Error fetching notification preferences: $e');
        setState(() {
          isLoading = false; // Stop loading on error
        });
      }
    }
  }

  Future<void> _saveNotificationPreferences() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({
          'notificationsEnabled': allNotificationsEnabled,
          'notifications': {
            'newFollower': newFollowerEnabled,
            'newRecipeFromFollowing': newRecipeEnabled,
            'newComment': newCommentEnabled,
            'weeklyRecommendations': weeklyRecommendationsEnabled,
          },
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Preferences saved successfully!')),
        );
      } catch (e) {
        print('Error saving notification preferences: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save preferences.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notification Preferences'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator()) // Show loading indicator
          : Padding(
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
                      onPressed: _saveNotificationPreferences,
                      child: Text('Save Preferences'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
