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

  // Convert Firestore document to Ingredient object
  factory Ingredient.fromDocumentSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>; // Ensure type safety
    return Ingredient(
      ingredientName: data['ingredientName'] ?? 'Unknown', // Fix field name
      category: data['category'] ?? 'Other', // Fix field name
      approved: data['approved'] ?? false,
    );
  }

  // Convert JSON to Ingredient object
  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      ingredientName: json['ingredientName'] ?? 'Unknown',
      category: json['category'] ?? 'Other',
      approved: json['approved'] ?? false,
    );
  }

  // Convert Ingredient object to Firestore JSON
  Map<String, dynamic> toJson() {
    return {
      'ingredientName': ingredientName,
      'category': category,
      'approved': approved,
    };
  }
}
