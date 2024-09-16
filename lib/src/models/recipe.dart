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
    List<RecipeIngredient>? ingredients,
    this.initialServings = 2,
    List<String>? cookingSteps,
    this.imageUrl = 'lib/assets/images/spaghettiBolognese.webp',
  })  : ingredients = ingredients ?? [],
        cookingSteps = cookingSteps ?? [];

  // Convert JSON to Recipe object
  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      cookingTime: json['cookingTime'] ?? '',
      ingredients: (json['ingredients'] as List<dynamic>?)
              ?.map((item) => RecipeIngredient.fromJson(item))
              .toList() ??
          [],
      initialServings: json['initialServings'] ?? 2,
      cookingSteps: List<String>.from(json['cookingSteps'] ?? []),
      imageUrl: json['imageUrl'] ?? 'lib/assets/images/spaghettiBolognese.webp',
    );
  }

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
