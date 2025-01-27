import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:food_fellas/src/models/recipe.dart';
import 'package:food_fellas/src/models/textEmbedding_model.dart';
import 'package:food_fellas/src/views/addRecipeForm/importSummary_screen.dart';

class ImportRecipesPage extends StatefulWidget {
  const ImportRecipesPage({Key? key}) : super(key: key);

  @override
  _ImportRecipesPageState createState() => _ImportRecipesPageState();
}

class _ImportRecipesPageState extends State<ImportRecipesPage> {
  bool isLoading = false;
  String statusMessage = '';
  String _userRole = 'user';

  /// We'll keep references to the success/failure lists
  List<Recipe> _successList = [];
  List<RecipeImportError> _failureList = [];

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  void _fetchUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (userDoc.exists) {
      setState(() {
        _userRole = userDoc['role'] ?? 'user';
      });
    }
  }

  Future<void> importRecipesFromDevice() async {
    setState(() {
      isLoading = true;
      statusMessage = 'Picking file from device...';
    });

    try {
      // 1) Pick a file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.isEmpty) {
        // User canceled the picker
        setState(() {
          statusMessage = 'File pick canceled.';
          isLoading = false;
        });
        return;
      }

      // 2) Read the file
      final filePath = result.files.single.path;
      if (filePath == null) {
        setState(() {
          statusMessage = 'No file path found.';
          isLoading = false;
        });
        return;
      }

      final file = File(filePath);
      final String jsonString = await file.readAsString();
      final List<dynamic> jsonData = jsonDecode(jsonString);

      // 3) Convert each JSON map into a Recipe object
      final importedRecipes =
          jsonData.map((item) => Recipe.fromJson(item)).toList();

      final User? currentUser = FirebaseAuth.instance.currentUser;
      final String adminUid = currentUser?.uid ?? 'unknownAdmin';

      setState(() {
        statusMessage = 'Importing ${importedRecipes.length} recipes...';
      });

      // Clear any old data
      _successList.clear();
      _failureList.clear();

      // 4) Upload
      await _uploadRecipes(importedRecipes, adminUid);

      setState(() {
        statusMessage = 'Import Complete!';
      });

      // 5) Show summary screen
      _showSummaryScreen();
    } catch (e) {
      print('Error importing recipes from device: $e');
      setState(() {
        statusMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Upload logic that handles both "from assets" and "from device"
  Future<void> _uploadRecipes(List<Recipe> recipes, String adminUid) async {
    final collectionRef = FirebaseFirestore.instance.collection('recipes');
    final embeddingModel = TextEmbeddingModel();

    for (var recipe in recipes) {
      try {
        // Create new doc if no ID
        final newDocRef = collectionRef.doc();
        recipe.id = newDocRef.id;

        // Setup fields
        final now = DateTime.now();
        recipe.createdAt ??= now;
        recipe.updatedAt = now;
        recipe.authorId ??= adminUid;

        // Generate embeddings
        final String ingredientNames = recipe.ingredients
            .map((ri) => ri.ingredient.ingredientName)
            .join(", ");
        final String tagNames = recipe.tags.map((tag) => tag.name).join(", ");
        final String combinedText =
            [recipe.title, ingredientNames, tagNames].join(" ");

        try {
          recipe.embeddings =
              await embeddingModel.generateEmbedding(combinedText);
        } catch (embedErr) {
          print(
              "Error generating embedding for recipe: ${recipe.title}, $embedErr");
          // We won't throw here because we can still save the recipe even if embeddings fail
          recipe.embeddings = null;
        }

        // Convert to JSON
        final recipeData = recipe.toJson();

        // Add 'tagsNames'
        final tagsNames = recipe.tags.map((t) => t.name).toSet().toList();
        recipeData['tagsNames'] = tagsNames;

        // Write to Firestore
        await newDocRef.set(recipeData);

        // If all is good, add to success list
        _successList.add(recipe);
      } catch (e) {
        // Something went wrong with this recipe
        _failureList.add(RecipeImportError(recipe, e.toString()));
      }
    }
  }

  /// Simple helper to navigate to the summary screen
  void _showSummaryScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImportSummaryPage(
          successList: _successList,
          failureList: _failureList,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_userRole != 'admin') {
      return Scaffold(
        appBar: AppBar(
          title: Text('Bulk Import Recipes'),
        ),
        body: Center(child: Text('Not authorized')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Bulk Import Recipes'),
      ),
      body: Center(
        child: isLoading
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text(statusMessage),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(statusMessage),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: importRecipesFromDevice,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      textStyle: TextStyle(fontSize: 18),
                    ),
                    icon: Icon(Icons.upload_file,
                        color: Theme.of(context).colorScheme.onPrimary),
                    label: Text('Import from device',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary)),
                  ),
                ],
              ),
      ),
    );
  }
}
