import 'package:flutter/material.dart';

class CommunityScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Community'),
      ),
      body: ListView.builder(
        itemCount: 10, // replace with actual number of community posts
        itemBuilder: (context, index) {
          return ListTile(
            title: Text('User ${index + 1}'),
            subtitle: Text('Last message in short'),
            trailing: Text('Time'),
          );
        },
      ),
    );
  }
}
