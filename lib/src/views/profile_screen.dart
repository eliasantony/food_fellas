import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Your Profile'),
      ),
      body: ListView(
        children: [
          CircleAvatar(
            radius: 50,
            // Load user's profile image here
          ),
          ListTile(
            title: Text('Name'),
            subtitle: Text('Additional Info'),
          ),
          // Add other profile details here
        ],
      ),
    );
  }
}
