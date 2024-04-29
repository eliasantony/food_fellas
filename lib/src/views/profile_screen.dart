import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile', style: theme.textTheme.titleLarge),
        backgroundColor: theme.appBarTheme.backgroundColor,
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: theme.iconTheme.color),
            onPressed: () {
              // Navigate to settings screen or perform other actions
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const CircleAvatar(
                    backgroundImage: NetworkImage('https://via.placeholder.com/150'),
                    radius: 40,
                  ),
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        Text(
                          'Eko Prasetyo',
                          style: theme.textTheme.titleLarge,
                        ),
                        Text(
                          'Tarakan, Indonesia',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.edit, color: theme.iconTheme.color),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  _ProfileStatistic(title: 'Recipes', value: '1'),
                  _ProfileStatistic(title: 'Likes', value: '347'),
                  _ProfileStatistic(title: 'Following', value: '100'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'My Recipe',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              elevation: 4.0,
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                children: <Widget>[
                  Image.network('https://via.placeholder.com/400', fit: BoxFit.cover),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text('Fried Chicken', style: theme.textTheme.titleMedium),
                        Row(
                          children: <Widget>[
                            Icon(Icons.favorite_border, color: theme.colorScheme.secondary),
                            Text(' 225', style: theme.textTheme.titleMedium),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Add more widgets as needed
          ],
        ),
      ),
    );
  }

  Widget _ProfileStatistic({required String title, required String value}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}
