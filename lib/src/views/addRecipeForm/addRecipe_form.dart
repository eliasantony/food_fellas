import 'dart:io';

import 'package:flutter/material.dart';
import 'package:easy_stepper/easy_stepper.dart';
import '../../models/recipe.dart';
import 'recipeBasics_screen.dart';
import 'ingredientsSelection_screen.dart';
import 'quantitiesServings_screen.dart';
import 'cookingSteps_screen.dart';
import 'imageUpload_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AddRecipeForm extends StatefulWidget {
  final Recipe? initialRecipe;

  AddRecipeForm({Key? key, this.initialRecipe}) : super(key: key);

  @override
  _AddRecipeFormState createState() => _AddRecipeFormState();
}

class _AddRecipeFormState extends State<AddRecipeForm> {
  final GlobalKey<FormState> _basicsFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _ingredientsFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _quantitiesFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _stepsFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _imageFormKey = GlobalKey<FormState>();

  late PageController _pageController;
  int _currentStep = 0;
  bool _isSubmitting = false;

  late Recipe recipe;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    recipe = widget.initialRecipe ?? Recipe();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.initialRecipe == null ? 'Add a Recipe' : 'Edit Recipe'),
      ),
      body: Column(
        children: <Widget>[
          SizedBox(
            height: 100,
            child: EasyStepper(
              activeStep: _currentStep,
              lineStyle: LineStyle(
                lineLength: 80,
                lineThickness: 3,
              ),
              steps: _buildEasySteps(),
              onStepReached: (index) {
                if (_getCurrentFormKey().currentState!.validate()) {
                  _getCurrentFormKey().currentState!.save();
                  setState(() {
                    _currentStep = index;
                  });
                  _pageController.animateToPage(
                    index,
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: NeverScrollableScrollPhysics(),
              children: <Widget>[
                RecipeBasicsPage(
                  recipe: recipe,
                  onDataChanged: _updateRecipeData,
                  formKey: _basicsFormKey,
                ),
                IngredientsSelectionPage(
                  recipe: recipe,
                  onDataChanged: _updateRecipeData,
                  formKey: _ingredientsFormKey,
                ),
                QuantitiesAndServingsPage(
                  recipe: recipe,
                  onDataChanged: _updateRecipeData,
                  formKey: _quantitiesFormKey,
                ),
                CookingStepsPage(
                  recipe: recipe,
                  onDataChanged: _updateRecipeData,
                  formKey: _stepsFormKey,
                ),
                ImageUploadPage(
                  recipe: recipe,
                  onDataChanged: _updateRecipeData,
                  formKey: _imageFormKey,
                ),
              ],
            ),
          ),
          SizedBox(height: 100, child: _buildFloatingActionButtons())
        ],
      ),
    );
  }

  Widget _buildFloatingActionButtons() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: _isSubmitting
          ? Center(child: CircularProgressIndicator())
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                FloatingActionButton(
                  heroTag: "previousPageBtn",
                  onPressed: _currentStep > 0 ? _previousPage : null,
                  backgroundColor: _currentStep > 0
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                  child: Icon(Icons.arrow_back),
                ),
                FloatingActionButton(
                  heroTag: "nextPageBtn",
                  onPressed: _currentStep < _totalSteps() - 1
                      ? _nextPage
                      : _submitForm,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Icon(
                    _currentStep < _totalSteps() - 1
                        ? Icons.arrow_forward
                        : Icons.check,
                  ),
                ),
              ],
            ),
    );
  }

  void _nextPage() {
    if (_getCurrentFormKey().currentState!.validate()) {
      _getCurrentFormKey().currentState!.save(); // Save the form state

      if (_currentStep < _totalSteps() - 1) {
        setState(() => _currentStep++);
        _pageController.nextPage(
          duration: Duration(milliseconds: 300),
          curve: Curves.ease,
        );
      }
    }
  }

  void _previousPage() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    }
  }

  void _submitForm() async {
    if (_getCurrentFormKey().currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      _getCurrentFormKey().currentState!.save();

      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You must be logged in to submit a recipe.')),
        );
        setState(() {
          _isSubmitting = false;
        });
        return;
      }

      recipe.authorId = currentUser.uid;
      final now = DateTime.now();
      recipe.createdAt = now;
      recipe.updatedAt = now;

      // Handle image upload if an image is provided
      if (recipe.imageFile != null) {
        try {
          String imageUrl =
              await _uploadRecipeImage(recipe.imageFile!, currentUser.uid);
          recipe.imageUrl = imageUrl;
        } catch (e) {
          print('Error uploading image: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error uploading image: $e')),
          );
          setState(() {
            _isSubmitting = false;
          });
          return;
        }
      }

      // Generate a new document reference
      final docRef = FirebaseFirestore.instance.collection('recipes').doc();
      recipe.id = docRef.id; // Set the recipe's ID before saving

      // Save the recipe to Firestore
      try {
        await docRef.set(recipe.toJson());
        print('DocRef ID: ${docRef.id}');
        print('Recipe ID: ${recipe.id}');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recipe submitted successfully!')),
        );

        setState(() {
          _isSubmitting = false;
        });

        // Navigate to the recipe detail page or back to the previous screen
        Navigator.pop(context);
      } catch (e) {
        print('Error submitting recipe: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting recipe: $e')),
        );
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<String> _uploadRecipeImage(File imageFile, String userId) async {
    Reference storageRef = FirebaseStorage.instance.ref().child(
        'recipe_images/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg');
    UploadTask uploadTask = storageRef.putFile(imageFile);

    TaskSnapshot taskSnapshot = await uploadTask;
    String downloadUrl = await taskSnapshot.ref.getDownloadURL();
    return downloadUrl;
  }

  void _updateRecipeData(String key, dynamic value) {
    setState(() {
      switch (key) {
        case 'title':
          recipe.title = value;
          break;
        case 'description':
          recipe.description = value;
          break;
        case 'cookingTime':
          recipe.cookingTime = value;
          break;
        case 'ingredients':
          recipe.ingredients = value;
          break;
        case 'initialServings':
          recipe.initialServings = value;
          break;
        case 'cookingSteps':
          recipe.cookingSteps = value;
          break;
        case 'imageFile':
          recipe.imageFile = value;
          break;
        default:
          throw ArgumentError('Unknown key: $key');
      }
    });
  }

  GlobalKey<FormState> _getCurrentFormKey() {
    switch (_currentStep) {
      case 0:
        return _basicsFormKey;
      case 1:
        return _ingredientsFormKey;
      case 2:
        return _quantitiesFormKey;
      case 3:
        return _stepsFormKey;
      case 4:
        return _imageFormKey;
      default:
        throw ArgumentError('Invalid step: $_currentStep');
    }
  }

  int _totalSteps() => 5;

  List<EasyStep> _buildEasySteps() {
    return [
      const EasyStep(
        title: 'Basics',
        icon: Icon(Icons.info),
      ),
      const EasyStep(
        title: 'Ingredients',
        icon: Icon(Icons.shopping_cart),
      ),
      const EasyStep(
        title: 'Amounts',
        icon: Icon(Icons.line_weight),
      ),
      const EasyStep(
        title: 'Steps',
        icon: Icon(Icons.list),
      ),
      const EasyStep(
        title: 'Image',
        icon: Icon(Icons.image),
      ),
    ];
  }
}
