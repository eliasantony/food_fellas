import 'dart:developer';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:food_fellas/src/models/user_data.dart';
import 'package:food_fellas/src/services/firebase_messaging_service.dart';
import 'package:food_fellas/src/views/auth/final_welcome_screen.dart';
import 'package:food_fellas/src/widgets/notificationPreferences.dart';

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
  Map<String, bool> notifications = {
    'newFollower': true,
    'newRecipeFromFollowing': true,
    'newComment': true,
    'weeklyRecommendations': true,
  };

  @override
  void initState() {
    super.initState();
    // Initialize from userData if available
    allNotificationsEnabled = widget.userData.allNotificationsEnabled ?? true;

    // Handle null notifications by providing default values
    notifications = widget.userData.notifications != null
        ? widget.userData.notifications!
            .map((key, value) => MapEntry(key, value is bool ? value : true))
        : {
            'newFollower': true,
            'newRecipeFromFollowing': true,
            'newComment': true,
            'weeklyRecommendations': true,
          };
  }

  // This method updates the local state when switches are toggled
  void _handlePreferencesChange(bool enabled, Map<String, bool> prefs) {
    setState(() {
      allNotificationsEnabled = enabled;
      notifications = prefs;
    });
  }

  Future<void> _navigateToNext() async {
    log('Starting _navigateToNext');

    if (allNotificationsEnabled) {
      log('Requesting notification permissions...');
      // Request notification permissions
      NotificationSettings settings =
          await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      log('Notification permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        log('Permissions authorized.');
        // Permissions granted
        await initLocalNotifications();
        log('Local notifications initialized.');

        await saveTokenToDatabase();
        log('Token saved to database.');

        // Show confirmation
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notifications enabled!'),
          ),
        );
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        log('Provisional permissions granted.');
        // Handle provisional permissions if needed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Provisional notifications enabled!'),
          ),
        );
      } else {
        log('Permissions denied.');
        // Permissions denied
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Notification permissions denied. You can enable them in settings later.'),
          ),
        );

        // Update the state to reflect that notifications are disabled
        setState(() {
          allNotificationsEnabled = false;
        });
      }
    } else {
      log('Notifications are being disabled.');
      // Notifications being disabled
      await removeTokenFromDatabase();
      log('Token removed from database.');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notifications disabled.'),
        ),
      );
    }

    // Update userData with current preferences
    widget.userData.allNotificationsEnabled = allNotificationsEnabled;
    widget.userData.notifications = notifications;

    log('Navigating to FinalWelcomeScreen');

    // Navigate to the final welcome screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => FinalWelcomeScreen(userData: widget.userData),
      ),
    );

    log('Navigation to FinalWelcomeScreen initiated.');
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
            NotificationPreferencesWidget(
              notificationsEnabled: allNotificationsEnabled,
              notifications: notifications,
              onChanged: _handlePreferencesChange, // Updated callback
            ),
            Spacer(),
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
