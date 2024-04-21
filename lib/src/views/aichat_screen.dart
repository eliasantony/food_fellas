import 'package:flutter/material.dart';

class AIChatScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat with AI Chef'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              // This would be populated with chat messages
              children: [
                ListTile(
                  title: Text('Message'),
                  subtitle: Text('Response'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Type here...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
