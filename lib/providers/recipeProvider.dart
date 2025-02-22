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
    // 1) Check cache
    if (_recipesCache.containsKey(recipeId)) {
      return _recipesCache[recipeId];
    }

    try {
      // 2) Fetch from Firestore
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('recipes')
          .doc(recipeId)
          .get();

      if (!doc.exists) {
        return null;
      }

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      // 3) Parse rating fields, etc. (your existing code)
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

      // 4) Check if we have authorId
      String authorId = data['authorId'] ?? '';
      if (authorId.isEmpty) {
        // The doc might not even have an authorId. We'll set a fallback.
        data['authorName'] = data['authorName'] ?? 'Unknown author';
      } else {
        // If we do have an authorId, check if doc has authorName
        final hasNoName =
            (data['authorName'] == null || data['authorName'] == '');
        if (hasNoName) {
          // 5) Fallback fetch from "users" collection
          Map<String, dynamic>? authorData = await getAuthorById(authorId);
          final fetchedName = authorData?['display_name'] ?? 'Unknown author';

          // 6) Put that name in our local `data` so it displays
          data['authorName'] = fetchedName;

          // 7) Also store it back in Firestore so we don’t need to do this next time
          //    Use merge = true to preserve other fields
          await doc.reference
              .set({'authorName': fetchedName}, SetOptions(merge: true));
        } else {
          // doc had a valid authorName? just use it
          data['authorName'] = data['authorName'];
        }
      }

      // 8) Cache the result
      _recipesCache[recipeId] = data;
      notifyListeners();
      return data;
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

  Future<void> _fetchSavedRecipes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    // 1) Owned
    final ownedSnap = await userRef.collection('collections').get();
    Set<String> savedRecipeIds = {};

    for (var doc in ownedSnap.docs) {
      final data = doc.data();
      final recipes = data['recipes'] ?? [];
      savedRecipeIds.addAll(recipes.cast<String>());
    }

    // 2) Shared
    final sharedSnap = await userRef.collection('sharedCollections').get();
    if (sharedSnap.docs.isEmpty) {
      _savedRecipes = savedRecipeIds;
      notifyListeners();
      return;
    }

    for (var sharedDoc in sharedSnap.docs) {
      final sharedData = sharedDoc.data();
      final ownerUid = sharedData['collectionOwnerUid'];
      final colId = sharedData['collectionId'];

      // Fetch the actual doc to see its 'recipes'
      final colRef = FirebaseFirestore.instance
          .collection('users')
          .doc(ownerUid)
          .collection('collections')
          .doc(colId);

      final colSnap = await colRef.get();
      if (colSnap.exists) {
        final colData = colSnap.data()!;
        final recipes = (colData['recipes'] as List?) ?? [];
        savedRecipeIds.addAll(recipes.cast<String>());
      }
    }

    _savedRecipes = savedRecipeIds;
    notifyListeners();
  }

  // Check if a recipe is saved
  bool isRecipeSaved(String recipeId) {
    return _savedRecipes.contains(recipeId);
  }

  // Method to fetch collections where the user is a contributor
  Future<List<Map<String, dynamic>>> getContributedCollections(String userId) async {
    if (userId.isEmpty) return [];

    try {
      final sharedSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('sharedCollections')
          .get();

      List<Map<String, dynamic>> contributedCollections = [];

      for (var sharedDoc in sharedSnap.docs) {
        final data = sharedDoc.data();
        final ownerUid = data['collectionOwnerUid'];
        final colId = data['collectionId'];

        // Fetch the actual collection document
        final colSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(ownerUid)
            .collection('collections')
            .doc(colId)
            .get();

        if (colSnap.exists) {
          final colData = colSnap.data()!;
          contributedCollections.add({
            'id': colSnap.id,
            'ownerUid': ownerUid,
            ...colData,
          });
        }
      }

      return contributedCollections;
    } catch (e) {
      print('Error fetching contributed collections: $e');
      return [];
    }
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
