import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_fellas/src/widgets/ingredientsGrid.dart';

class RecipeDetailScreen extends StatefulWidget {
  final String recipeId;

  RecipeDetailScreen({required this.recipeId});

  @override
  _RecipeDetailScreenState createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late Future<DocumentSnapshot> _recipeFuture;
  int servings = 1;
  int initialServings = 1;

  @override
  void initState() {
    super.initState();
    _recipeFuture = FirebaseFirestore.instance
        .collection('recipes')
        .doc(widget.recipeId)
        .get();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe Details'),
        leading: BackButton(
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: _recipeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          } else if (snapshot.hasError) {
            return const Center(
              child: Text('Error fetching recipe'),
            );
          } else if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text('Recipe not found'),
            );
          } else {
            final recipeData = snapshot.data!.data() as Map<String, dynamic>;
            initialServings = recipeData['initialServings'] ?? 1;
            if (servings == 1) servings = initialServings;

            return _buildRecipeDetail(recipeData);
          }
        },
      ),
    );
  }

  Widget _buildRecipeDetail(Map<String, dynamic> recipeData) {
    String imageUrl = recipeData['imageUrl'] ?? '';
    String title = recipeData['title'] ?? '';
    String description = recipeData['description'] ?? '';
    String cookingTime = recipeData['cookingTime'] ?? '';
    List<dynamic> ingredientsData = recipeData['ingredients'] ?? [];
    List<dynamic> cookingSteps = recipeData['cookingSteps'] ?? [];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          imageUrl.startsWith('http')
              ? Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                )
              : Image.asset(
                  imageUrl,
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
                  title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                // Servings adjustment
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
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
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        setState(() {
                          servings++;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Ingredients',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                IngredientsGrid(
                  servings: servings,
                  ingredientsData: ingredientsData,
                ),
                const SizedBox(height: 16),
                Text(
                  'Steps',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                ...List.generate(
                  cookingSteps.length,
                  (index) => Text('${index + 1}. ${cookingSteps[index]}'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
