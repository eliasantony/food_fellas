import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RecipeProvider extends ChangeNotifier {
  final Map<String, Map<String, dynamic>> _recipesCache = {};
  final Map<String, Map<String, dynamic>> _authorsCache = {};
  Set<String> _savedRecipes = Set<String>();

  Map<String, Map<String, dynamic>> get recipesCache => _recipesCache;
  Map<String, Map<String, dynamic>> get authorsCache => _authorsCache;
  Set<String> get savedRecipes => _savedRecipes;

  RecipeProvider() {
    _fetchSavedRecipes();
  }

  Future<Map<String, dynamic>?> getRecipeById(String recipeId) async {
    // Check if the recipe is already cached
    if (_recipesCache.containsKey(recipeId)) {
      return _recipesCache[recipeId];
    }

    // Fetch from Firestore and cache it
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('recipes')
          .doc(recipeId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Fetch author's display name
        String authorId = data['authorId'] ?? '';
        Map<String, dynamic>? authorData = await getAuthorById(authorId);

        if (authorData != null) {
          data['authorName'] = authorData['display_name'] ?? 'Unknown author';
        } else {
          data['authorName'] = 'Unknown author';
        }

        data['averageRating'] = (data['averageRating'] is String)
            ? double.tryParse(data['averageRating']) ?? 0.0
            : data['averageRating']?.toDouble() ?? 0.0;

        data['ratingsCount'] = (data['ratingsCount'] is String)
            ? int.tryParse(data['ratingsCount']) ?? 0
            : data['ratingsCount'] ?? 0;

        // Safe parsing for ratingCounts map
        if (data['ratingCounts'] is Map) {
          Map<String, dynamic> rawCounts =
              Map<String, dynamic>.from(data['ratingCounts']);
          data['ratingCounts'] = rawCounts.map((key, value) {
            int parsedKey = int.tryParse(key) ?? 0;
            int parsedValue =
                (value is String) ? int.tryParse(value) ?? 0 : value ?? 0;
            return MapEntry(parsedKey, parsedValue);
          });
        } else {
          data['ratingCounts'] = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
        }

        _recipesCache[recipeId] = data;
        notifyListeners();
        return data;
      } else {
        return null;
      }
    } catch (e) {
      print('Error fetching recipe: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getAuthorById(String authorId) async {
    // Check if the author is already cached
    if (_authorsCache.containsKey(authorId)) {
      return _authorsCache[authorId];
    }

    // Fetch from Firestore and cache it
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(authorId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        _authorsCache[authorId] = data;
        return data;
      } else {
        return null;
      }
    } catch (e) {
      print('Error fetching author: $e');
      return null;
    }
  }

  // Fetch saved recipes for the current user
  Future<void> _fetchSavedRecipes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    QuerySnapshot collectionsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('collections')
        .get();

    Set<String> savedRecipeIds = Set<String>();

    for (var collection in collectionsSnapshot.docs) {
      List<dynamic> recipes = collection['recipes'] ?? [];
      savedRecipeIds.addAll(recipes.cast<String>());
    }

    _savedRecipes = savedRecipeIds;
    notifyListeners();
  }

  // Check if a recipe is saved
  bool isRecipeSaved(String recipeId) {
    return _savedRecipes.contains(recipeId);
  }

  // Update saved state when a recipe is saved or unsaved
  Future<void> toggleRecipeSavedState(String recipeId, bool isSaved) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Update the saved state in Firestore
    // For simplicity, let's assume we have a 'favorites' collection
    final favoritesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorites');

    if (isSaved) {
      await favoritesRef.doc(recipeId).set({
        'recipeId': recipeId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      _savedRecipes.add(recipeId);
    } else {
      await favoritesRef.doc(recipeId).delete();
      _savedRecipes.remove(recipeId);
    }

    notifyListeners();
  }

  // Refresh saved recipes (e.g., after login)
  Future<void> refreshSavedRecipes() async {
    await _fetchSavedRecipes();
  }

  Future<void> refreshRecipe(String recipeId) async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('recipes')
          .doc(recipeId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        _recipesCache[recipeId] = data;
        notifyListeners();
      }
    } catch (e) {
      print('Error refreshing recipe: $e');
    }
  }

  // Optional: Clear the cache
  void clearCache() {
    _recipesCache.clear();
    notifyListeners();
  }
}
