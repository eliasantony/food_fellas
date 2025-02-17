import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:food_fellas/src/services/firebase_messaging_service.dart';
import 'package:food_fellas/src/widgets/notificationPreferences.dart';

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
  late Map<String, bool> notifications;

  @override
  void initState() {
    super.initState();
    allNotificationsEnabled = widget.notificationsEnabled;
    notifications = widget.notifications
        .map((key, value) => MapEntry(key, value is bool ? value : true));
  }

  // This method updates the local state when switches are toggled
  void _handlePreferencesChange(bool enabled, Map<String, bool> prefs) {
    setState(() {
      allNotificationsEnabled = enabled;
      notifications = prefs;
    });
  }

  // This method handles saving preferences when the button is pressed
  Future<void> _savePreferences() async {
    if (allNotificationsEnabled) {
      // Request notification permissions
      NotificationSettings settings =
          await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Permissions granted
        await initLocalNotifications();
        await saveTokenToDatabase();
      } else {
        // Permissions denied
        // Update the state to reflect that notifications are disabled
        setState(() {
          allNotificationsEnabled = false;
        });
      }
    } else {
      // Notifications being disabled
      await removeTokenFromDatabase();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notifications disabled.'),
        ),
      );
    }

    // After saving, pop the screen and pass the updated preferences
    Navigator.pop(context, {
      'notificationsEnabled': allNotificationsEnabled,
      'notifications': notifications,
    });
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
                  onPressed: _savePreferences,
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
                  child: Text(
                    'Save Preferences',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
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
