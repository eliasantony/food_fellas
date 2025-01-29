import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:food_fellas/providers/themeProvider.dart';
import 'package:food_fellas/src/views/addRecipeForm/importRecipes_screen.dart';
import 'package:food_fellas/src/widgets/feedbackModal.dart';
import 'package:food_fellas/src/widgets/settings_notificationPreferences_screen.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const SettingsScreen({
    Key? key,
    required this.userData,
  }) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _updateNotificationPreferences(
      Map<String, dynamic> newPreferences) async {
    final userId = widget.userData['uid'];

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update(newPreferences);
      print('Notification preferences updated successfully!');
    } catch (e) {
      print('Error updating notification preferences: $e');
    }
  }

  void _logOut() async {
    bool? confirmLogout = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Logout'),
        content: Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmLogout == true) {
      await FirebaseAuth.instance.signOut();
      // Navigate to login screen or root
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _showInstagram() {
    // Open the browser to show the Privacy Policy link
    var url = Uri(
        scheme: 'https',
        host: 'instagram.com',
        fragment: '/foodfellas.app',
        path: '/');
    _launchURL(url);
  }

  void _showTermsOfService() {
    // Open the browser to show the Terms of Service link
    var url = Uri(
        scheme: 'https', host: 'foodfellas.app', fragment: '/terms', path: '/');
    print(url);
    _launchURL(url);
  }

  void _showPrivacyPolicy() {
    // Open the browser to show the Privacy Policy link
    var url = Uri(
        scheme: 'https',
        host: 'foodfellas.app',
        fragment: '/privacy',
        path: '/');
    _launchURL(url);
  }

  void _launchURL(Uri url) async {
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch $url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    bool isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: ListView(
        children: [
          if (widget.userData['role'] == 'admin')
            ListTile(
              leading: Icon(Icons.edit_document),
              title: Text('Batch Import for Admins'),
              trailing: Icon(Icons.arrow_forward),
              onTap: () async {
                // Navigate to Import Recipes Screen
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ImportRecipesPage(),
                  ),
                );
              },
            ),
          Divider(),
          ListTile(
            leading: Icon(Icons.notifications),
            title: Text('Manage Notifications'),
            trailing: Icon(Icons.arrow_forward),
            onTap: () async {
              // Navigate to Notification Preferences Screen
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsNotificationPreferencesScreen(
                    notificationsEnabled:
                        widget.userData['notificationsEnabled'] ?? true,
                    notifications: widget.userData['notifications'] ?? {},
                  ),
                ),
              );

              if (result != null) {
                // Save updated preferences
                await _updateNotificationPreferences(result);
              }
            },
          ),
          ListTile(
            leading: Icon(Icons.brightness_6),
            title: const Text('Dark Mode'),
            trailing: Switch(
              value: isDarkMode,
              onChanged: (value) {
                themeProvider.toggleTheme(value);
              },
            ),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.feedback_outlined),
            title: Text('Send Feedback'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FeedbackModal(),
                ),
              );
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.description),
            title: Text('Terms of Service'),
            onTap: _showTermsOfService,
          ),
          ListTile(
            leading: Icon(Icons.privacy_tip),
            title: Text('Privacy Policy'),
            onTap: _showPrivacyPolicy,
          ),
          ListTile(
            leading: Icon(Icons.info),
            title: Text('App Version'),
            subtitle: Text('pre 1.0.0'),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.share),
            title: Text('Share Food Fellas'),
            onTap: () {
              Share.share(
                  'Check out Food Fellas, the best app for food lovers! 🍔🍕🍝 Visit us at https://foodfellas.app');
            },
          ),
          ListTile(
            leading: Icon(Icons.star),
            title: Text('Rate Food Fellas'),
            onTap: () {
              // Implement rating logic
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.photo_camera),
            title: Text('Follow us on Instagram'),
            onTap: _showInstagram,
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.logout),
            title: Text('Log Out'),
            onTap: _logOut,
          ),
        ],
      ),
    );
  }
}
