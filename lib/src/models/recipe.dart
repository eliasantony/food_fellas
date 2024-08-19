import 'package:food_fellas/src/models/recipeIngredient.dart';

class Recipe {
  String title;
  String description;
  String cookingTime;
  List<RecipeIngredient> ingredients;
  int initialServings;
  List<String> cookingSteps;
  String imageUrl;

  Recipe({
    this.title = '',
    this.description = '',
    this.cookingTime = '',
    List<RecipeIngredient>? ingredients, // Mutable list of ingredients
    this.initialServings = 2,
    List<String>? cookingSteps, // Nullable list in constructor
    this.imageUrl = 'lib/assets/images/spaghettiBolognese.webp',
  })  : ingredients = ingredients ?? [],
        cookingSteps = cookingSteps ?? []; // Initialize with a modifiable list

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'cookingTime': cookingTime,
      'ingredients': ingredients.map((ri) => ri.toJson()).toList(),
      'initialServings': initialServings,
      'cookingSteps': cookingSteps,
      'imageUrl': imageUrl,
    };
  }
}

