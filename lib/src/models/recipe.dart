import 'dart:convert';
import 'dart:io';
import 'package:food_fellas/src/models/recipeIngredient.dart';
import 'package:food_fellas/src/models/tag.dart';

class Recipe {
  String? id;
  String? authorId;
  String title;
  String description;
  int? prepTime; // in minutes
  int? cookTime; // in minutes
  int? totalTime; // in minutes
  List<RecipeIngredient> ingredients;
  int initialServings;
  double? calories;
  double? carbs;
  double? protein;
  double? fat;
  List<String> cookingSteps;
  List<Tag> tags;
  List<String>? aiTagNames;
  bool? createdByAI;
  String? imageUrl;
  DateTime? createdAt;
  DateTime? updatedAt;
  File? imageFile;
  List<double>? embedding;

  Recipe({
    this.id,
    this.authorId,
    this.title = '',
    this.description = '',
    this.prepTime,
    this.cookTime,
    this.totalTime,
    List<RecipeIngredient>? ingredients,
    this.initialServings = 2,
    this.calories,
    this.carbs,
    this.protein,
    this.fat,
    List<String>? cookingSteps,
    List<Tag>? tags,
    this.aiTagNames,
    this.createdByAI,
    this.imageUrl,
    this.createdAt,
    this.updatedAt,
    this.imageFile,
    this.embedding,
  })  : ingredients = ingredients ?? [],
        cookingSteps = cookingSteps ?? [],
        tags = tags ?? [];

  // Convert JSON to Recipe object
  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'],
      authorId: json['authorId'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      prepTime: json['prepTime'] ?? 0,
      cookTime: json['cookTime'] ?? 0,
      totalTime: json['totalTime'] ?? 0,
      ingredients: (json['ingredients'] as List<dynamic>?)
              ?.map((item) => RecipeIngredient.fromJson(item))
              .toList() ??
          [],
      initialServings: json['initialServings'] ?? 2,
      calories: (json['calories'] as num?)?.toDouble(),
      carbs: (json['carbs'] as num?)?.toDouble(),
      protein: (json['protein'] as num?)?.toDouble(),
      fat: (json['fat'] as num?)?.toDouble(),
      cookingSteps: List<String>.from(json['cookingSteps'] ?? []),
      tags: (json['tags'] as List<dynamic>?)
              ?.map((item) => Tag.fromJson(item))
              .toList() ??
          [],
      aiTagNames: json['aiTagNames'] != null
          ? List<String>.from(json['aiTagNames'])
          : [],
      createdByAI: json['createdByAI'] ?? false,
      imageUrl: json['imageUrl'],
      createdAt: json['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['updatedAt'])
          : null,
      embedding: json['embedding'] != null
          ? List<double>.from(json['embedding'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'authorId': authorId,
      'title': title,
      'description': description,
      'prepTime': prepTime,
      'cookTime': cookTime,
      'totalTime': totalTime,
      'ingredients': ingredients.map((ri) => ri.toJson()).toList(),
      'initialServings': initialServings,
      'calories': calories,
      'carbs': carbs,
      'protein': protein,
      'fat': fat,
      'cookingSteps': cookingSteps,
      'tags': tags.map((tag) => tag.toJson()).toList(),
      'aiTagNames': aiTagNames ?? [],
      'createdByAI': createdByAI ?? false,
      'imageUrl': imageUrl,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
      'embedding': embedding,
    };
  }

  String toJsonString() {
    return jsonEncode({
      'id': id,
      'authorId': authorId,
      'title': title,
      'description': description,
      'prepTime': prepTime,
      'cookTime': cookTime,
      'totalTime': totalTime,
      'ingredients': ingredients.map((ri) => ri.toJson()).toList(),
      'initialServings': initialServings,
      'calories': calories,
      'carbs': carbs,
      'protein': protein,
      'fat': fat,
      'cookingSteps': cookingSteps,
      'tags': tags.map((tag) => tag.toJson()).toList(),
      'aiTagNames': aiTagNames ?? [],
      'createdByAI': createdByAI ?? false,
      'imageUrl': imageUrl,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
      'embedding': embedding,
    });
  }
}
