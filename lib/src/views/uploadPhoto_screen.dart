import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:food_fellas/src/models/aiPhotoRecognitionModel_config.dart';
import 'package:food_fellas/src/models/recipe.dart';
import 'package:food_fellas/src/views/addRecipeForm/addRecipe_form.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';

class UploadPhotoScreen extends StatefulWidget {
  @override
  _UploadPhotoScreenState createState() => _UploadPhotoScreenState();
}

class _UploadPhotoScreenState extends State<UploadPhotoScreen> {
  File? _selectedImage;
  String _description = '';
  bool _isLoading = false;

  final List<String> _loadingHints = [
    "This may take a moment...",
    "Remember, this is AI-generated and might have some inaccuracies.",
    "Hang tight! We're analyzing your delicious dish."
  ];

  String _currentHint = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Upload Photo for Recipe'),
      ),
      body: Stack(
        children: [
          // Content
          Column(
            children: [
              _selectedImage == null
                  ? Placeholder(
                      fallbackHeight: 200,
                      fallbackWidth: double.infinity,
                    )
                  : Image.file(
                      _selectedImage!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
              ElevatedButton(
                onPressed: _pickImage,
                child: Text('Take or Upload Photo'),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      _description = value;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Description',
                    hintText: 'Enter a short description of the dish...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _canSubmit() ? _startProcessing : null,
                child: Text('Identify Recipe'),
              ),
            ],
          ),
          // Loading Overlay
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  bool _canSubmit() {
    return _description.isNotEmpty && _selectedImage != null;
  }

  Widget _buildLoadingOverlay() {
    return Stack(
      children: [
        // Blur Background
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            color: Colors.black.withOpacity(0.5),
          ),
        ),
        // Loading Animation and Hint
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset('lib/assets/lottie/loadingAnim.json'),
              SizedBox(height: 20),
              Text(
                _currentHint,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  void _startProcessing() async {
    setState(() {
      _isLoading = true;
    });

    // Display changing hints during processing
    for (int i = 0; i < _loadingHints.length; i++) {
      await Future.delayed(Duration(seconds: 2), () {
        setState(() {
          _currentHint = _loadingHints[i];
        });
      });
    }

    // Send the data to the AI for processing
    await _sendPhotoAndDescription(_selectedImage!, _description);

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _sendPhotoAndDescription(File image, String description) async {
    try {
      // Get the AI model for identifying the recipe
      final model = getRecipeFromPhotoModel();
      final chat = model?.startChat();

      // Prepare the prompt with the description
      final prompt = Content.text(description);
      final response = await chat?.sendMessage(prompt);
      final responseText = response?.text ?? '';

      // Extract the JSON recipe from the AI response
      final recipeJson = extractJsonRecipe(responseText);

      if (recipeJson != null) {
        // Once a valid recipe JSON is obtained, navigate to addRecipe form
        await _navigateToAddRecipeForm(context, recipeJson);
      } else {
        // Show error if recipe extraction failed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: Could not extract recipe information')),
        );
      }
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _checkAndAddIngredients(Recipe recipe) async {
    final ingredientsCollection =
        FirebaseFirestore.instance.collection('ingredients');

    for (var recipeIngredient in recipe.ingredients) {
      String ingredientName = recipeIngredient.ingredient.ingredientName;

      // Check if ingredient exists
      QuerySnapshot snapshot = await ingredientsCollection
          .where('ingredientName', isEqualTo: ingredientName)
          .get();

      if (snapshot.docs.isEmpty) {
        // Ingredient doesn't exist, add it with approved: false
        await ingredientsCollection.add({
          'ingredientName': ingredientName,
          'category': recipeIngredient.ingredient.category,
          'approved': false,
        });
      }
    }
  }

  Future<void> _navigateToAddRecipeForm(
      BuildContext context, Map<String, dynamic>? recipeJson) async {
    if (recipeJson != null) {
      Recipe recipe = Recipe.fromJson(recipeJson);
      recipe.createdByAI = true; // Set the AI-created flag

      // Check and add missing ingredients
      await _checkAndAddIngredients(recipe);

      // Navigate to AddRecipeForm with the pre-filled recipe data
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddRecipeForm(
            initialRecipe: recipe,
          ),
        ),
      );
    }
  }

  Map<String, dynamic>? extractJsonRecipe(String text) {
    try {
      // Regular expression to find JSON code blocks
      final codeBlockRegExp =
          RegExp(r'```json\s*(\{[\s\S]*?\})\s*```', multiLine: true);
      final match = codeBlockRegExp.firstMatch(text);
      if (match != null) {
        String? jsonString = match.group(1);
        if (jsonString != null) {
          // Preprocess the JSON string to replace fractions with decimal equivalents
          jsonString = jsonString.replaceAllMapped(
            RegExp(r'(\d+)/(\d+)'),
            (match) {
              final numerator = int.parse(match.group(1)!);
              final denominator = int.parse(match.group(2)!);
              return (numerator / denominator).toString();
            },
          );

          final Map<String, dynamic> decoded = json.decode(jsonString);
          if (decoded.containsKey('title') &&
              decoded.containsKey('description') &&
              decoded.containsKey('ingredients') &&
              decoded.containsKey('cookingSteps')) {
            return decoded;
          }
        }
      }
    } catch (e) {
      print('Error parsing JSON: $e');
      // Ignore parsing errors, just return null
    }
    return null;
  }

  Future<Map<String, dynamic>?> identifyRecipe(
      File image, String description) async {
    try {
      final model = getRecipeFromPhotoModel();
      final chat = model?.startChat();

      final prompt = Content.text(description);
      final response = await chat?.sendMessage(prompt);
      final responseText = response?.text ?? '';

      // Extract the JSON recipe from the response
      return extractJsonRecipe(responseText);
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
    return null;
  }
}
