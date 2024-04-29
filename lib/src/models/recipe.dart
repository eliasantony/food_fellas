import 'ingredient.dart';

class Recipe {
  String title;
  String description;
  String cookingTime;
  List<Ingredient> ingredients;
  int initialServings;
  List<String> cookingSteps;
  String imageUrl;

  Recipe({
    this.title = '',
    this.description = '',
    this.cookingTime = '',
    this.ingredients = const [],
    this.initialServings = 2,
    this.cookingSteps = const [],
    this.imageUrl = 'lib/assets/images/spaghettiBolognese.webp',
  });

  String toJson() {
    return '''
    {
      "title": "$title",
      "description": "$description",
      "cookingTime": "$cookingTime",
      "ingredients": ${ingredients.map((ingredient) => ingredient.toJson()).toList()},
      "initialServings": $initialServings,
      "cookingSteps": $cookingSteps,
      "imageUrl": "$imageUrl"
    }
    ''';
  }
}
