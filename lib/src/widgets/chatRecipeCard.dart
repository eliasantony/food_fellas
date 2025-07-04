import 'package:flutter/material.dart';

class ChatRecipeCard extends StatelessWidget {
  final Map<String, dynamic> recipe;
  final VoidCallback onAddRecipe;

  ChatRecipeCard({required this.recipe, required this.onAddRecipe});

  @override
  Widget build(BuildContext context) {
    try {
      // Extract data from the recipe map
      final title = recipe['title'] ?? 'No Title';
      final description = recipe['description'] ?? 'No Description';
      final ingredients = recipe['ingredients'] as List<dynamic>? ?? [];
      final steps = recipe['cookingSteps'] as List<dynamic>? ?? [];
      final tags = recipe['tags'] as List<dynamic>? ?? [];

      return Card(
        margin: EdgeInsets.symmetric(vertical: 8.0),
        child: Padding(
          padding: EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                title,
                style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8.0),
              // Description
              Text(description),
              SizedBox(height: 12.0),
              // Ingredients
              Text(
                'Ingredients:',
                style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
              ),
              ...ingredients.map((ingredient) {
                // Using null-aware operators to prevent crashes
                final name = ingredient['ingredient']?['ingredientName'] ?? '';
                final amount = ingredient['baseAmount']?.toString() ?? '';
                final unit = ingredient['unit'] ?? '';
                return Text('- $amount $unit $name');
              }).toList(),
              SizedBox(height: 12.0),
              // Steps
              Text(
                'Cooking Steps:',
                style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
              ),
              ...steps.asMap().entries.map((entry) {
                int idx = entry.key + 1;
                String step = entry.value is String
                    ? entry.value
                    : entry.value.toString();
                return Text('$idx. $step');
              }).toList(),
              SizedBox(height: 12.0),
              // Tags
              if (tags.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: tags.map<Widget>((tag) {
                      final name = tag['name'] ?? '';
                      final icon = tag['icon'] ?? '';
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Chip(
                          label: Text('$icon $name'),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              SizedBox(height: 12.0),
              // Add Recipe Button
              ElevatedButton(
                onPressed: onAddRecipe,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: EdgeInsets.symmetric(horizontal: 30),
                ),
                child: Text(
                  'Add Recipe',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      // If any exception occurs, return a safe widget
      return Card(
        color: Colors.redAccent,
        margin: EdgeInsets.all(8.0),
        child: Padding(
          padding: EdgeInsets.all(12.0),
          child: Text(
            'Error displaying recipe. Please try again.',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }
  }
}