// ingredient_provider.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_fellas/src/models/ingredient.dart';

class IngredientProvider with ChangeNotifier {
  List<Ingredient> _ingredients = [];
  bool isLoaded = false;

  List<Ingredient> get ingredients => _ingredients;

  Future<void> fetchIngredients() async {
    if (isLoaded) return; // Avoid re-fetching

    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('ingredients')
        .where('approved', isEqualTo: true)
        .get();

    _ingredients = snapshot.docs.map((doc) {
      return Ingredient.fromDocumentSnapshot(doc);
    }).toList();

    isLoaded = true;
    notifyListeners();
  }
}
