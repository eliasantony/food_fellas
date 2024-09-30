import 'package:cloud_firestore/cloud_firestore.dart';

class Ingredient {
  final String ingredientName;
  // final String imageUrl;
  final String category;

  Ingredient({
    required this.ingredientName,
    // required this.imageUrl,
    required this.category,
  });

  // This method will be used to create an Ingredient object from Firebase data
  factory Ingredient.fromDocumentSnapshot(DocumentSnapshot doc) {
    return Ingredient(
      ingredientName: doc['IngredientName'],
      //imageUrl: 'lib/assets/images/${doc['IngredientPicture']}', // Handle image URL
      category: doc['ingredientCatgory'],
    );
  }

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      ingredientName: json['ingredientName'],
      // imageUrl: json['imageUrl'],
      category: json['category'],
    );
  }

  // This method will be used to convert an Ingredient object to a JSON object
  Map<String, dynamic> toJson() {
    return {
      'ingredientName': ingredientName,
      // 'imageUrl': imageUrl,
      'category': category,
    };
  }
}
