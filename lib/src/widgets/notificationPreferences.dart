import 'package:flutter/material.dart';

class NotificationPreferencesWidget extends StatefulWidget {
  final bool notificationsEnabled;
  final Map<String, bool> notifications;
  final Function(bool, Map<String, bool>) onChanged;

  const NotificationPreferencesWidget({
    Key? key,
    required this.notificationsEnabled,
    required this.notifications,
    required this.onChanged,
  }) : super(key: key);

  @override
  _NotificationPreferencesWidgetState createState() =>
      _NotificationPreferencesWidgetState();
}

class _NotificationPreferencesWidgetState
    extends State<NotificationPreferencesWidget> {
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
  void didUpdateWidget(covariant NotificationPreferencesWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notificationsEnabled != widget.notificationsEnabled ||
        oldWidget.notifications != widget.notifications) {
      setState(() {
        allNotificationsEnabled = widget.notificationsEnabled;
        newFollowerEnabled = widget.notifications['newFollower'] ?? true;
        newRecipeEnabled =
            widget.notifications['newRecipeFromFollowing'] ?? true;
        newCommentEnabled = widget.notifications['newComment'] ?? true;
        weeklyRecommendationsEnabled =
            widget.notifications['weeklyRecommendations'] ?? true;
      });
    }
  }

  void _onEnableNotificationsChanged(bool value) {
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
    widget.onChanged(allNotificationsEnabled, {
      'newFollower': newFollowerEnabled,
      'newRecipeFromFollowing': newRecipeEnabled,
      'newComment': newCommentEnabled,
      'weeklyRecommendations': weeklyRecommendationsEnabled,
    });
  }

  void _onIndividualPreferenceChanged(String key, bool value) {
    setState(() {
      switch (key) {
        case 'newFollower':
          newFollowerEnabled = value;
          break;
        case 'newRecipeFromFollowing':
          newRecipeEnabled = value;
          break;
        case 'newComment':
          newCommentEnabled = value;
          break;
        case 'weeklyRecommendations':
          weeklyRecommendationsEnabled = value;
          break;
      }
    });
    widget.onChanged(allNotificationsEnabled, {
      'newFollower': newFollowerEnabled,
      'newRecipeFromFollowing': newRecipeEnabled,
      'newComment': newCommentEnabled,
      'weeklyRecommendations': weeklyRecommendationsEnabled,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: Text('Enable Notifications'),
          value: allNotificationsEnabled,
          onChanged: _onEnableNotificationsChanged,
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
                    _onIndividualPreferenceChanged('newFollower', value);
                  },
                  secondary: Icon(Icons.person_add),
                ),
                SwitchListTile(
                  title: Text('New Recipe from Following'),
                  value: newRecipeEnabled,
                  onChanged: (bool value) {
                    _onIndividualPreferenceChanged(
                        'newRecipeFromFollowing', value);
                  },
                  secondary: Icon(Icons.restaurant_menu),
                ),
                SwitchListTile(
                  title: Text('New Comment'),
                  value: newCommentEnabled,
                  onChanged: (bool value) {
                    _onIndividualPreferenceChanged('newComment', value);
                  },
                  secondary: Icon(Icons.comment),
                ),
                SwitchListTile(
                  title: Text('Weekly Recommendations'),
                  value: weeklyRecommendationsEnabled,
                  onChanged: (bool value) {
                    _onIndividualPreferenceChanged(
                        'weeklyRecommendations', value);
                  },
                  secondary: Icon(Icons.recommend),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
