import 'dart:io';

import 'package:flutter/material.dart';
import 'package:easy_stepper/easy_stepper.dart';
import 'package:food_fellas/src/models/tag.dart';
import 'package:food_fellas/src/models/textEmbedding_model.dart';
import 'package:food_fellas/src/views/addRecipeForm/feedback_dialog.dart';
import 'package:food_fellas/src/views/addRecipeForm/tagsSelection_screen.dart';
import 'package:food_fellas/src/views/addRecipeForm/thankyou_screen.dart';
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
  final GlobalKey<FormState> _tagsFormKey = GlobalKey<FormState>();
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
              activeStepIconColor:
                  Theme.of(context).colorScheme.primary, // Icon color
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
                TagsSelectionPage(
                  recipe: recipe,
                  onDataChanged: _updateRecipeData,
                  formKey: _tagsFormKey,
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
                  child: Icon(Icons.arrow_back, color: Colors.white),
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
                      color: Colors.white),
                ),
              ],
            ),
    );
  }

  void _nextPage() {
    if (_getCurrentFormKey().currentState!.validate()) {
      _getCurrentFormKey().currentState!.save(); // Save the form state

      // Close the keyboard if open
      FocusScope.of(context).unfocus();

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

      final now = DateTime.now();
      recipe.updatedAt = now; // Always update 'updatedAt'

      // 1) Only set the authorId if it's a brand-new recipe (no existing recipe.id).
      //    If recipe.id is null or empty => brand new
      //    If recipe.id is set => editing existing recipe
      if (recipe.id == null || recipe.id!.isEmpty) {
        // This is a new recipe
        recipe.authorId = currentUser.uid; // Keep track of who created it
        recipe.createdAt = now; // Created time
      }

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

      // Generate embedding
      try {
        TextEmbeddingModel embeddingModel = TextEmbeddingModel();
        String ingredientNames = recipe.ingredients
            .map((ri) => ri.ingredient.ingredientName)
            .join(", ");
        String tagNames = recipe.tags.map((tag) => tag.name).join(", ");
        String combinedText =
            [recipe.title, ingredientNames, tagNames].join(" ");
        recipe.embeddings =
            await embeddingModel.generateEmbedding(combinedText);
      } catch (e) {
        print('Error generating embedding: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating embedding: $e')),
        );
        setState(() {
          _isSubmitting = false;
        });
        return;
      }

      // Determine if we are editing or creating new
      bool isNewRecipe = (recipe.id == null || recipe.id!.isEmpty);

      // 2) Decide which DocumentReference to use
      DocumentReference docRef;
      if (isNewRecipe) {
        // brand-new recipe
        docRef = FirebaseFirestore.instance.collection('recipes').doc();
        recipe.id = docRef.id; // set the recipe ID
      } else {
        // editing existing recipe
        docRef =
            FirebaseFirestore.instance.collection('recipes').doc(recipe.id);
      }

      // Prepare the tag names for easier searching
      List<String> tagsNames =
          recipe.tags.map((tag) => tag.name).toSet().toList();

      // Convert to JSON but also add tagsNames
      Map<String, dynamic> recipeData = recipe.toJson();
      recipeData['tagsNames'] = tagsNames;

try {
        await docRef.set(recipeData);

        if (isNewRecipe) {
          final userRef = FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid);

          // Update recipe count and fetch the updated value
          DocumentSnapshot userDoc = await userRef.get();
          int recipeCount = ((userDoc.data() as Map<String, dynamic>?)?['recipeCount'] ?? 0) + 1;
          print('Recipe count: $recipeCount');

          await userRef.update({'recipeCount': FieldValue.increment(1)});

          // Conditionally show feedback dialog if recipe count < 5
          if (recipeCount < 5) {
            showDialog(
              context: context,
              builder: (context) => RecipeFeedbackDialog(recipeId: recipe.id!),
            );
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Recipe submitted successfully!')),
          );

          Navigator.pop(context); // Close the form
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ThankYouScreen(recipeId: recipe.id!),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Recipe edited successfully!')),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        print('Error submitting recipe: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting recipe: $e')),
        );
      } finally {
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
        case 'prepTime':
          recipe.prepTime = value;
          break;
        case 'cookTime':
          recipe.cookTime = value;
          break;
        case 'totalTime':
          recipe.totalTime = value;
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
        case 'tags':
          recipe.tags = List<Tag>.from(value);
          print('Tags: ${recipe.tags}');
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
        return _tagsFormKey;
      case 5:
        return _imageFormKey;
      default:
        throw ArgumentError('Invalid step: $_currentStep');
    }
  }

  int _totalSteps() => 6;

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
        title: 'Tags',
        icon: Icon(Icons.label),
      ),
      const EasyStep(
        title: 'Image',
        icon: Icon(Icons.image),
      ),
    ];
  }
}
