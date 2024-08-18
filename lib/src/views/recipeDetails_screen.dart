import 'package:flutter/material.dart';
import 'package:food_fellas/src/widgets/ingredientsGrid.dart';

class RecipeDetailScreen extends StatefulWidget {
  @override
  _RecipeDetailScreenState createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  int servings = 2; // Initial servings count

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Recipe Details'),
        leading: BackButton(
          onPressed: () => Navigator.pop(context), // Go back to previous screen
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Image.asset(
              'lib/assets/images/spaghettiBolognese.webp',
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Title',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Recipe Description Recipe Description Recipe Description Recipe Description',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove),
                        onPressed: () {
                          if (servings > 1) {
                            setState(() {
                              servings--;
                            });
                          }
                        },
                      ),
                      Text(
                        '$servings',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      IconButton(
                        icon: Icon(Icons.add),
                        onPressed: () {
                          setState(() {
                            servings++;
                          });
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Ingredients',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Container(
                    height: 300, // Set a fixed height for the grid view
                    child: IngredientsGrid(
                        servings:
                            servings), // Pass the current servings to the grid
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Steps',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  SizedBox(height: 8),
                  ...List.generate(
                      6, (index) => Text('${index + 1}. Step example text.')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
