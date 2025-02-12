// importRecipes_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  String? _lastBatchId;

  /// References to the success/failure lists
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

  Future<void> pickAndUploadPdfs() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true, // Let user pick multiple PDFs at once
    );

    if (result == null || result.files.isEmpty) {
      // User canceled or no file selected
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Not logged in or not admin
      return;
    }

    setState(() {
      isLoading = true;
      statusMessage = 'Uploading PDFs...';
    });

    try {
      // Create a "batchId" to group these PDFs together
      final batchId = DateTime.now().millisecondsSinceEpoch.toString();

      // Upload each PDF to `pdf_uploads/{batchId}/{filename}`
      for (final pickedFile in result.files) {
        if (pickedFile.path == null) continue;

        final filePath = pickedFile.path!;
        final fileName = pickedFile.name;
        final localFile = File(filePath);

        final storagePath = 'pdf_uploads/$batchId/$fileName';
        final ref = FirebaseStorage.instance.ref().child(storagePath);

        // Provide custom metadata so the Cloud Function knows the user
        await ref.putFile(
          localFile,
          SettableMetadata(
            contentType: 'application/pdf',
            customMetadata: {
              'uploaderUid': user.uid,
              'batchId': batchId,
            },
          ),
        );
      }

      setState(() {
        statusMessage = 'PDFs uploaded. The server is extracting recipes...';
        _lastBatchId = batchId;
      });
    } catch (e) {
      setState(() {
        statusMessage = 'Error uploading PDFs: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
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
      final dynamic decoded = jsonDecode(jsonString);
      List<dynamic> jsonData;

      if (decoded is Map<String, dynamic>) {
        // Wrap the single object in a list
        jsonData = [decoded];
      } else if (decoded is List) {
        jsonData = decoded;
      } else {
        throw FormatException('Invalid JSON: not a Map or List');
      }

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

  Future<List<String>> fetchBatchIds() async {
    final snap = await FirebaseFirestore.instance
        .collection('pdfProcessingResults')
        .get();

    // Each doc in pdfProcessingResults is a "batchId"
    return snap.docs.map((doc) => doc.id).toList();
  }

  Future<List<Map<String, dynamic>>> fetchPdfProcessedRecipes(
      String batchId) async {
    // e.g., read all "files" for that batch
    final snap = await FirebaseFirestore.instance
        .collection('pdfProcessingResults')
        .doc(batchId)
        .collection('files')
        .where('imported', isEqualTo: false)
        .get();

    final allRecipes = <Map<String, dynamic>>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final recipes = data['recipes'] as List? ?? [];
      for (final recipe in recipes) {
        // Each "recipe" is a Map<String,dynamic> presumably
        allRecipes.add(Map<String, dynamic>.from(recipe));
      }
    }
    return allRecipes;
  }

  Future<void> _loadAndImportProcessedRecipes(String batchId) async {
    setState(() {
      isLoading = true;
      statusMessage = 'Loading processed PDF recipes...';
    });

    try {
      // 1) Fetch the docs for "imported: false"
      final snap = await FirebaseFirestore.instance
          .collection('pdfProcessingResults')
          .doc(batchId)
          .collection('files')
          .where('imported', isEqualTo: false)
          .get();

      // 2) Gather all the docs & parse recipes
      final List<Map<String, dynamic>> allRecipesData = [];
      final List<DocumentSnapshot> docRefs = [];

      for (final doc in snap.docs) {
        docRefs.add(doc); // keep reference for later
        final data = doc.data();
        final recipes = data['recipes'] as List? ?? [];
        for (final recipe in recipes) {
          allRecipesData.add(Map<String, dynamic>.from(recipe));
        }
      }

      if (allRecipesData.isEmpty) {
        setState(() {
          statusMessage = 'No unimported recipes found.';
        });
        return;
      }

      // 3) Convert each map to a `Recipe` object
      final importedRecipes =
          allRecipesData.map((map) => Recipe.fromJson(map)).toList();

      final user = FirebaseAuth.instance.currentUser;
      final adminUid = user?.uid ?? 'unknownAdmin';

      // Clear old success/failure
      _successList.clear();
      _failureList.clear();

      // 4) Import them with `_uploadRecipes`
      await _uploadRecipes(importedRecipes, adminUid);

      // 5) Mark each doc as imported
      for (final docSnap in docRefs) {
        await docSnap.reference.update({'imported': true});
      }

      // 6) Show success
      setState(() {
        statusMessage = 'Imported ${importedRecipes.length} recipes!';
      });

      // If you want the summary screen:
      _showSummaryScreen();
    } catch (e) {
      setState(() {
        statusMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
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
      return Center(child: Text('Not authorized'));
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: isLoading
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text(statusMessage),
                ],
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Status Message:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Divider(),
                              SizedBox(height: 8),
                              Text(statusMessage),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Divider(),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: pickAndUploadPdfs,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          padding: EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          textStyle: TextStyle(fontSize: 18),
                        ),
                        icon: Icon(Icons.upload_file,
                            color: Theme.of(context).colorScheme.onPrimary),
                        label: Text(
                          'Upload PDF(s) to Gemini AI',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (_lastBatchId == null) {
                            setState(() {
                              statusMessage =
                                  'No batch ID found. Please upload PDFs first.';
                            });
                            return;
                          }
                          _loadAndImportProcessedRecipes(_lastBatchId!);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          padding: EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          textStyle: TextStyle(fontSize: 18),
                        ),
                        icon: Icon(Icons.downloading_outlined,
                            color: Theme.of(context).colorScheme.onPrimary),
                        label: Text(
                          'Load Processed PDF Recipes',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: importRecipesFromDevice,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          padding: EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          textStyle: TextStyle(fontSize: 18),
                        ),
                        icon: Icon(Icons.data_object,
                            color: Theme.of(context).colorScheme.onPrimary),
                        label: Text(
                          'Import JSON File from Device',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
