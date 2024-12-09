import 'package:cloud_firestore/cloud_firestore.dart';

class Ingredient {
  final String ingredientName;
  final String category;
  final bool approved;

  Ingredient({
    required this.ingredientName,
    required this.category,
    this.approved = false, // Default to false for new ingredients
  });

  // This method will be used to create an Ingredient object from Firebase data
  factory Ingredient.fromDocumentSnapshot(DocumentSnapshot doc) {
    return Ingredient(
      ingredientName: doc['IngredientName'],
      category: doc['ingredientCatgory'],
      approved: doc['approved'] ?? false,
    );
  }

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      ingredientName: json['ingredientName'],
      category: json['category'],
      approved: json['approved'] ?? false,
    );
  }

  // This method will be used to convert an Ingredient object to a JSON object
  Map<String, dynamic> toJson() {
    return {
      'ingredientName': ingredientName,
      'category': category,
      'approved': approved,
    };
  }
}
