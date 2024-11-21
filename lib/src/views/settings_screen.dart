import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
// Import other necessary packages

class SettingsScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  SettingsScreen({required this.userData});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool notificationsEnabled = true;
  int preferredServings = 1;

  @override
  void initState() {
    super.initState();
    notificationsEnabled = widget.userData['notificationsEnabled'] ?? true;
    preferredServings = widget.userData['preferredServings'] ?? 1;
  }

  void _changePreferredServings() {
    showDialog(
      context: context,
      builder: (context) {
        int tempServings = preferredServings;
        return AlertDialog(
          title: Text('Preferred Servings'),
          content: TextField(
            keyboardType: TextInputType.number,
            onChanged: (value) {
              tempServings = int.tryParse(value) ?? tempServings;
            },
            decoration: InputDecoration(hintText: 'Enter number of servings'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  preferredServings = tempServings;
                  // Update in Firestore
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.userData['uid'])
                      .update({'preferredServings': preferredServings});
                });
                Navigator.of(context).pop();
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _logOut() async {
    await FirebaseAuth.instance.signOut();
    // Navigate to login screen or root
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _disableAccount() {
    // Implement account disabling logic
    // E.g., update a field in Firestore to mark the account as disabled
  }

  void _showTermsOfService() {
    // Navigate to a screen or show a dialog with the Terms of Service
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Terms of Service coming soon... ;)'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showPrivacyPolicy() {
    // Navigate to a screen or show a dialog with the Privacy Policy
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Privacy Policy coming soon... ;)'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: Text('Enable Notifications'),
            trailing: Switch(
              value: notificationsEnabled,
              onChanged: (value) {
                setState(() {
                  notificationsEnabled = value;
                  // Update in Firestore
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.userData['uid'])
                      .update({'notificationsEnabled': value});
                });
              },
            ),
          ),
          ListTile(
            title: Text('Preferred Servings'),
            subtitle: Text('$preferredServings'),
            onTap: _changePreferredServings,
          ),
          Divider(),
          ListTile(
            title: Text('Log Out'),
            onTap: _logOut,
          ),
          ListTile(
            title: Text('Disable Account'),
            onTap: _disableAccount,
          ),
          Divider(),
          ListTile(
            title: Text('App Version'),
            subtitle: Text('pre 1.0.0'),
          ),
          ListTile(
            title: Text('Terms of Service'),
            onTap: _showTermsOfService,
          ),
          ListTile(
            title: Text('Privacy Policy'),
            onTap: _showPrivacyPolicy,
          ),
        ],
      ),
    );
  }
}
