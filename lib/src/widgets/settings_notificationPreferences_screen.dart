import 'package:flutter/material.dart';

class SettingsNotificationPreferencesScreen extends StatefulWidget {
  final bool notificationsEnabled;
  final Map<String, dynamic> notifications;

  const SettingsNotificationPreferencesScreen({
    Key? key,
    required this.notificationsEnabled,
    required this.notifications,
  }) : super(key: key);

  @override
  _SettingsNotificationPreferencesScreenState createState() =>
      _SettingsNotificationPreferencesScreenState();
}

class _SettingsNotificationPreferencesScreenState
    extends State<SettingsNotificationPreferencesScreen> {
  late bool allNotificationsEnabled;
  late bool newFollowerEnabled;
  late bool newRecipeEnabled;
  late bool newCommentEnabled;
  late bool weeklyRecommendationsEnabled;

  @override
  void initState() {
    super.initState();
    allNotificationsEnabled = widget.notificationsEnabled;
    newFollowerEnabled = widget.notifications['newFollower'] ?? true;
    newRecipeEnabled = widget.notifications['newRecipeFromFollowing'] ?? true;
    newCommentEnabled = widget.notifications['newComment'] ?? true;
    weeklyRecommendationsEnabled =
        widget.notifications['weeklyRecommendations'] ?? true;
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
                  } else {
                    newFollowerEnabled = true;
                    newRecipeEnabled = true;
                    newCommentEnabled = true;
                    weeklyRecommendationsEnabled = true;
                  }
                });
              },
            ),
            if (allNotificationsEnabled) ...[
              Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: Column(
                    children: [
                    SwitchListTile(
                      title: Text('New Follower'),
                      value: newFollowerEnabled,
                      onChanged: (bool value) {
                      setState(() => newFollowerEnabled = value);
                      },
                      secondary: Icon(Icons.person_add),
                    ),
                    SwitchListTile(
                      title: Text('New Recipe from Following'),
                      value: newRecipeEnabled,
                      onChanged: (bool value) {
                      setState(() => newRecipeEnabled = value);
                      },
                      secondary: Icon(Icons.restaurant_menu),
                    ),
                    SwitchListTile(
                      title: Text('New Comment'),
                      value: newCommentEnabled,
                      onChanged: (bool value) {
                      setState(() => newCommentEnabled = value);
                      },
                      secondary: Icon(Icons.comment),
                    ),
                    SwitchListTile(
                      title: Text('Weekly Recommendations'),
                      value: weeklyRecommendationsEnabled,
                      onChanged: (bool value) {
                      setState(() => weeklyRecommendationsEnabled = value);
                      },
                      secondary: Icon(Icons.recommend),
                    ),
                  ],
                ),
              ),
            ],
            Spacer(),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Return updated preferences to the settings screen
                    Navigator.pop(context, {
                      'notificationsEnabled': allNotificationsEnabled,
                      'notifications': {
                        'newFollower': newFollowerEnabled,
                        'newRecipeFromFollowing': newRecipeEnabled,
                        'newComment': newCommentEnabled,
                        'weeklyRecommendations': weeklyRecommendationsEnabled,
                      },
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                  child: Text('Save Preferences',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
