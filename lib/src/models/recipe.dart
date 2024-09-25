import 'dart:io';
import 'package:food_fellas/src/models/recipeIngredient.dart';

class Recipe {
  String? id;
  String? authorId;
  String title;
  String description;
  String cookingTime;
  List<RecipeIngredient> ingredients;
  int initialServings;
  List<String> cookingSteps;
  String? imageUrl;
  DateTime? createdAt;
  DateTime? updatedAt;
  File? imageFile;

  Recipe({
    this.id,
    this.authorId,
    this.title = '',
    this.description = '',
    this.cookingTime = '',
    List<RecipeIngredient>? ingredients,
    this.initialServings = 2,
    List<String>? cookingSteps,
    this.imageUrl,
    this.createdAt,
    this.updatedAt,
    this.imageFile, // Include in constructor
  })  : ingredients = ingredients ?? [],
        cookingSteps = cookingSteps ?? [];

  // Convert JSON to Recipe object
  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'],
      authorId: json['authorId'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      cookingTime: json['cookingTime'] ?? '',
      ingredients: (json['ingredients'] as List<dynamic>?)
              ?.map((item) => RecipeIngredient.fromJson(item))
              .toList() ??
          [],
      initialServings: json['initialServings'] ?? 2,
      cookingSteps: List<String>.from(json['cookingSteps'] ?? []),
      imageUrl: json['imageUrl'],
      createdAt: json['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['updatedAt'])
          : null,
      // imageFile is not included in fromJson since it's a local file
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'authorId': authorId,
      'title': title,
      'description': description,
      'cookingTime': cookingTime,
      'ingredients': ingredients.map((ri) => ri.toJson()).toList(),
      'initialServings': initialServings,
      'cookingSteps': cookingSteps,
      'imageUrl': imageUrl,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
      // imageFile is not included in toJson since we don't store it in Firestore
    };
  }
}
