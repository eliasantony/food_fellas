import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:food_fellas/providers/themeProvider.dart';
import 'package:food_fellas/src/views/addRecipeForm/importRecipes_screen.dart';
import 'package:food_fellas/src/views/admin_dashboard.dart';
import 'package:food_fellas/src/widgets/feedbackModal.dart';
import 'package:food_fellas/src/widgets/settings_notificationPreferences_screen.dart';
import 'package:food_fellas/src/widgets/tutorialDialog.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = packageInfo.version;
    });
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
            child: Text('Cancel',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.onSurface)),
          ),
          TextButton(
            onPressed: () => {
              Navigator.of(context).pop(true),
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/welcome', (route) => false)
            },
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
      path: '/foodfellas.app',
    );
    _launchURL(url);
  }

  void _openWebsite() {
    // Open the browser to show the Privacy Policy link
    var url = Uri(
      scheme: 'https',
      host: 'foodfellas.app',
    );
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

  void _showSupport() {
    // Open the browser to show the Privacy Policy link
    var url = Uri(
        scheme: 'https',
        host: 'foodfellas.app',
        fragment: '/support',
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

  void _deleteAccount() async {
    String inputText = '';
    bool? confirmDelete = await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Confirm Account Deletion'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      'Type DELETE to confirm account deletion. This action cannot be undone.'),
                  TextField(
                    onChanged: (value) {
                      setState(() {
                        inputText = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Type DELETE here',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Cancel',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface)),
                ),
                ElevatedButton.icon(
                  onPressed: inputText == 'DELETE'
                      ? () => Navigator.of(context).pop(true)
                      : null,
                  icon: Icon(
                    Icons.delete,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).colorScheme.errorContainer,
                  ),
                  label: Text(
                    'Delete Account',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmDelete == true) {
      // Delete the user's account
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await user.delete();
          // Navigate to signup screen
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/signup', (route) => false);
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Account deleted successfully!'),
            ),
          );
        } catch (e) {
          print('Error deleting account: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting account. Please try again.'),
            ),
          );
        }
      }
    }
  }

  void _resetPassword() async {
    String email = FirebaseAuth.instance.currentUser!.email!;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset email sent to $email'),
        ),
      );
    } catch (e) {
      print('Error sending password reset email: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Error sending password reset email. Please try again.'),
        ),
      );
    }
  }

  void _updatePassword() async {
    String newPassword = '';
    String confirmPassword = '';
    bool? confirmUpdate = await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            bool passwordsMismatch =
                confirmPassword.isNotEmpty && newPassword != confirmPassword;
            return AlertDialog(
              title: Text('Update Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Enter your new password below.',
                    textAlign: TextAlign.left,
                  ),
                  TextField(
                    obscureText: true,
                    onChanged: (value) {
                      setState(() {
                        newPassword = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'New Password',
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: passwordsMismatch ? Colors.red : Colors.grey,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: passwordsMismatch
                              ? Colors.red
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    obscureText: true,
                    onChanged: (value) {
                      setState(() {
                        confirmPassword = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Confirm New Password',
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: passwordsMismatch ? Colors.red : Colors.grey,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: passwordsMismatch
                              ? Colors.red
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      errorText:
                          passwordsMismatch ? 'Passwords do not match' : null,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Cancel',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface)),
                ),
                ElevatedButton.icon(
                  onPressed: (newPassword.isNotEmpty &&
                          confirmPassword.isNotEmpty &&
                          newPassword == confirmPassword)
                      ? () => Navigator.of(context).pop(true)
                      : null,
                  icon: Icon(Icons.lock),
                  label: Text('Update Password'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmUpdate == true) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await user.updatePassword(newPassword);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Password updated successfully!'),
            ),
          );
        } catch (e) {
          print('Error updating password: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating password. Please try again.'),
            ),
          );
        }
      }
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
          if (widget.userData['role'] == 'admin') ...[
            ListTile(
              leading: Icon(Icons.dashboard),
              title: Text('Admin Dashboard'),
              trailing: Icon(Icons.arrow_forward),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => AdminDashboardScreen()),
                );
              },
            ),
            Divider(),
          ],
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
            title: Text("Show Tutorial"),
            leading: Icon(Icons.help_outline),
            onTap: () {
              showTutorialDialog(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.feedback_outlined),
            title: Text('Give Feedback'),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => FeedbackModal(),
              );
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.language),
            title: Text('Visit our Website'),
            onTap: _openWebsite,
          ),
          ListTile(
            leading: Icon(FontAwesomeIcons.instagram),
            title: Text('Follow us on Instagram'),
            onTap: _showInstagram,
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.share),
            title: Text('Share FoodFellas'),
            onTap: () {
              Share.share(
                  'Check out Food Fellas, the best app for food lovers! 🍔🍕🍝 Visit us at https://foodfellas.app');
            },
          ),
          ListTile(
            leading: Icon(Icons.star),
            title: Text('Rate FoodFellas'),
            onTap: () {
              void _rateApp() {
                if (Platform.isAndroid) {
                  _launchURL(Uri.parse(
                      'https://play.google.com/store/apps/details?id=com.foodfellas.app'));
                } else if (Platform.isIOS) {
                  _launchURL(
                      Uri.parse('https://apps.apple.com/app/6741926857'));
                }
              }
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.info),
            title: Text('App Version'),
            subtitle: Text(_appVersion),
          ),
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
            leading: Icon(Icons.support_agent_rounded),
            title: Text('Support'),
            onTap: _showSupport,
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.lock),
            title: Text('Reset Password'),
            onTap: _resetPassword,
          ),
          ListTile(
            leading: Icon(Icons.update),
            title: Text('Update Password'),
            onTap: _updatePassword,
          ),
          Divider(),
          if (widget.userData['role'] == 'admin') ...[
            ListTile(
              leading: Icon(Icons.delete),
              title: Text('Clear Shared Preferences'),
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Shared preferences cleared.'),
                  ),
                );
              },
            ),
            Divider(),
          ],
          ListTile(
            leading: Icon(Icons.logout),
            title: Text('Log Out'),
            onTap: _logOut,
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.delete_forever_rounded),
            title: Text('Delete Account'),
            onTap: _deleteAccount,
          ),
        ],
      ),
    );
  }
}
