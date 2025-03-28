import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:easy_stepper/easy_stepper.dart';
import 'package:food_fellas/main.dart';
import 'package:food_fellas/providers/recipeProvider.dart';
import 'package:food_fellas/providers/searchProvider.dart';
import 'package:food_fellas/src/models/tag.dart';
import 'package:food_fellas/src/models/textEmbedding_model.dart';
import 'package:food_fellas/src/services/analytics_service.dart';
import 'package:food_fellas/src/views/addRecipeForm/feedback_dialog.dart';
import 'package:food_fellas/src/views/addRecipeForm/tagsSelection_screen.dart';
import 'package:food_fellas/src/views/addRecipeForm/thankyou_screen.dart';
import 'package:food_fellas/src/views/guestUserScreen.dart';
import 'package:provider/provider.dart';
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

  // Record the form start time (for duration tracking)
  late DateTime _formStartTime;
  // If the recipe was pre-filled (e.g. from AI), keep an original copy for later comparison
  Recipe? _originalRecipe;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _formStartTime = DateTime.now();
    if (widget.initialRecipe != null) {
      // Clone the initial recipe (assumes toJson/fromJson exist)
      _originalRecipe = Recipe.fromJson(widget.initialRecipe!.toJson());
    }
    recipe = widget.initialRecipe ?? Recipe();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Checks if the recipe form is not empty (has any user input).
  bool _isRecipeNotEmpty() {
    return recipe.title.isNotEmpty ||
        recipe.description.isNotEmpty ||
        recipe.ingredients.isNotEmpty ||
        recipe.tags.isNotEmpty ||
        recipe.cookingSteps.isNotEmpty ||
        recipe.imageFile != null;
  }

  void _logFormCancellation() {
    final duration = DateTime.now().difference(_formStartTime);
    String? currentStepName = _buildEasySteps()[_currentStep].title;

    AnalyticsService.logEvent(
      name: "recipe_form_cancelled",
      parameters: {
        "source": recipe.source ?? 'manual',
        "duration_seconds": duration.inSeconds,
        "cancelled_at_step": currentStepName ?? 'Unknown',
      },
    );
  }

  Future<bool> _showExitConfirmationDialog(BuildContext context) async {
    if (_isRecipeNotEmpty()) {
      return await showDialog<bool>(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Discard Changes?'),
                content: const Text(
                    'You have unsaved changes. Are you sure you want to leave? Your progress will be lost.'),
                actions: [
                  TextButton(
                    child: Text('Leave',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface)),
                    onPressed: () {
                      Navigator.of(context)
                          .pop(true); // Return true when leaving
                    },
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context)
                          .pop(false); // Return false when canceling
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary),
                    ),
                  ),
                ],
              );
            },
          ) ??
          false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    bool isGuestUser = currentUser == null || currentUser.isAnonymous;

    if (isGuestUser) {
      return GuestUserScreen(
          title: "Add Recipe", message: "Sign up to add a recipe!");
    }

    return PopScope(
      canPop: false, // Prevents immediate popping without confirmation
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (!didPop) {
          bool shouldExit = await _showExitConfirmationDialog(context);

          if (shouldExit) {
            _logFormCancellation(); // Log the form cancellation event
            result.complete(true); // Allow exit
          } else {
            if (result != null) {
              result.complete(false);
            }
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
              widget.initialRecipe == null ? 'Add a Recipe' : 'Edit Recipe'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              _showExitConfirmationDialog(context).then((shouldExit) {
                if (shouldExit) {
                  _logFormCancellation(); // Log the form cancellation event
                  Navigator.pop(context);
                }
              });
            },
          ),
        ),
        floatingActionButton: _buildFloatingActionButtons(), // Moved here
        floatingActionButtonLocation: FloatingActionButtonLocation
            .centerFloat, // Ensures buttons are at the bottom
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
                    MediaQuery.of(context).platformBrightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                activeStepBackgroundColor:
                    Theme.of(context).colorScheme.primary,
                activeStepBorderColor: Theme.of(context).colorScheme.primary,
                finishedStepTextColor: Theme.of(context).colorScheme.primary,
                onStepReached: (index) {
                  if (_getCurrentFormKey().currentState!.validate()) {
                    _getCurrentFormKey().currentState!.save();
                    AnalyticsService.logEvent(
                      name: "recipe_form_step_reached",
                      parameters: {
                        "step": _buildEasySteps()[index].title as Object,
                        "step_index": index,
                        "source": recipe.source ?? 'manual',
                      },
                    );
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
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButtons() {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        if (_isSubmitting)
          Center(child: CircularProgressIndicator())
        else ...[
          Positioned(
            left: 16,
            bottom: 8,
            child: FloatingActionButton(
              heroTag: "previousPageBtn",
              onPressed: _currentStep > 0 ? _previousPage : null,
              backgroundColor: _currentStep > 0
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
              child: Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 8,
            child: FloatingActionButton(
              heroTag: "nextPageBtn",
              onPressed:
                  _currentStep < _totalSteps() - 1 ? _nextPage : _submitForm,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Icon(
                  _currentStep < _totalSteps() - 1
                      ? Icons.arrow_forward
                      : Icons.check,
                  color: Colors.white),
            ),
          ),
        ],
      ],
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

      bool isNewRecipe = (recipe.id == null || recipe.id!.isEmpty);

      // If brand new recipe, set authorId and createdAt
      if (isNewRecipe) {
        recipe.authorId = currentUser.uid;
        recipe.createdAt = now;
      }

      for (var ingredient in recipe.ingredients) {
        ingredient.servings = recipe.initialServings;
      }

      // Handle image upload if provided
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

      // Generate embedding (this is your current functionality)
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

      DocumentReference docRef;
      if (isNewRecipe) {
        docRef = FirebaseFirestore.instance.collection('recipes').doc();
        recipe.id = docRef.id;
      } else {
        docRef =
            FirebaseFirestore.instance.collection('recipes').doc(recipe.id);
      }

      Map<String, dynamic> recipeData = recipe.toJson();

      recipeData['tagsNames'] =
          recipe.tags.map((tag) => tag.name).toSet().toList();

      try {
        // 1) Get the current user’s display name
        final userRef =
            FirebaseFirestore.instance.collection('users').doc(currentUser.uid);
        final userDoc = await userRef.get();
        final String currentUserDisplayName =
            userDoc.data()?['display_name'] ?? 'Unknown author';

        if (isNewRecipe) {
          // ============== NEW RECIPE ==============
          // Store the current user’s name right away
          recipeData['authorName'] = currentUserDisplayName;

          // Write the new doc
          await docRef.set(recipeData);
        } else {
          // ============= EXISTING RECIPE =============
          // Fetch the existing doc to see who authored it
          final docSnap = await docRef.get();
          if (docSnap.exists) {
            final existingData = docSnap.data() as Map<String, dynamic>;
            final existingAuthorId = existingData['authorId'];

            // If current user is the author => update authorName to current name
            if (existingAuthorId == currentUser.uid) {
              recipeData['authorName'] = currentUserDisplayName;
            } else {
              // If the doc has no authorName stored, do a fallback fetch
              if (existingData['authorName'] == null ||
                  existingData['authorName'] == '') {
                // For example, use your provider to get the “real” author’s name
                // (assuming getAuthorById returns a Map like {'display_name': '...'})
                final originalAuthorDoc =
                    await Provider.of<RecipeProvider>(context, listen: false)
                        .getAuthorById(existingAuthorId);
                final originalName =
                    originalAuthorDoc?['display_name'] ?? 'Unknown author';
                recipeData['authorName'] = originalName;
              } else {
                // Otherwise, do nothing. We respect the existing authorName.
                recipeData.remove('authorName');
              }
            }
          }
          // Write updates to the doc (merging to keep existing fields if desired)
          await docRef.set(recipeData, SetOptions(merge: true));
        }

        if (!isNewRecipe) {
          AnalyticsService.logEvent(
            name: "recipe_edited",
            parameters: {
              "source": recipe.source ?? 'manual',
              "duration_seconds":
                  DateTime.now().difference(_formStartTime).inSeconds,
            },
          );
        }

        if (isNewRecipe) {
          final duration = DateTime.now().difference(_formStartTime);

          // Build the submission parameters including the source and, if available, the similarity percentage.
          Map<String, Object> submissionParams = {
            "source": recipe.source ?? 'manual',
            "duration_seconds": duration.inSeconds,
          };
          if (_originalRecipe != null) {
            double similarityPercentage =
                computeRecipeSimilarity(_originalRecipe!, recipe);
            submissionParams["similarity_percentage"] = similarityPercentage;
          }
          AnalyticsService.logEvent(
            name: "recipe_submission_complete",
            parameters: submissionParams,
          );

          final userRef = FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid);

          DocumentSnapshot userDoc = await userRef.get();
          int recipeCount =
              ((userDoc.data() as Map<String, dynamic>?)?['recipeCount'] ?? 0) +
                  1;

          if (kDebugMode) {
            debugPrint('Recipe count: $recipeCount');
          }

          await userRef.update({'recipeCount': FieldValue.increment(1)});

          if (recipeCount <= 5) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ThankYouScreen(recipeId: recipe.id!),
              ),
            ).then((shouldShowFeedback) {
              // Once the Thank You screen is popped, check return value
              if (kDebugMode) {
                debugPrint('Should show feedback: $shouldShowFeedback');
              }
              if (shouldShowFeedback == true) {
                if (kDebugMode) {
                  debugPrint('Showing feedback dialog');
                }
                AnalyticsService.logEvent(
                  name: "recipe_feedback_prompt_shown",
                  parameters: {
                    "recipe_id": recipe.id!,
                    "source": recipe.source ?? 'manual',
                  },
                );
                showDialog(
                  context: globalNavigatorKey.currentContext!,
                  builder: (ctx) => RecipeFeedbackDialog(recipeId: recipe.id!),
                );
              }
            });
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ThankYouScreen(recipeId: recipe.id!),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Recipe edited successfully!')),
          );
          // Update the recipe in Firestore
          final recipeProvider =
              Provider.of<RecipeProvider>(context, listen: false);
          recipeProvider.refreshRecipe(docRef.id);
          final searchProvider =
              Provider.of<SearchProvider>(context, listen: false);
          searchProvider.updateRecipe(docRef.id, recipeData);
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

  double computeRecipeSimilarity(Recipe originalRecipe, Recipe newRecipe) {
    double totalScore = 0.0;

    // 1. Time similarity (prepTime & cookTime) – 25%
    double prepSim = 1.0;
    if (originalRecipe.prepTime != null && newRecipe.prepTime != null) {
      int diff = (originalRecipe.prepTime! - newRecipe.prepTime!).abs();
      int maxTime = (originalRecipe.prepTime! > newRecipe.prepTime!
          ? originalRecipe.prepTime!
          : newRecipe.prepTime!);
      prepSim = maxTime > 0 ? 1 - (diff / maxTime) : 1.0;
    }
    double cookSim = 1.0;
    if (originalRecipe.cookTime != null && newRecipe.cookTime != null) {
      int diff = (originalRecipe.cookTime! - newRecipe.cookTime!).abs();
      int maxTime = (originalRecipe.cookTime! > newRecipe.cookTime!
          ? originalRecipe.cookTime!
          : newRecipe.cookTime!);
      cookSim = maxTime > 0 ? 1 - (diff / maxTime) : 1.0;
    }
    double timeSim = (prepSim + cookSim) / 2;
    double timeContribution = timeSim * 25; // 25% weight

    // 2. Ingredient similarity – 40%
    // Assume each RecipeIngredient has a 'amount' field (of type double).
    // Build maps: ingredient name (lowercased) => amount.
    Map<String, double> originalIngr = {};
    for (var ri in originalRecipe.ingredients) {
      // If amount is not available, default to 1.0.
      // (Adjust this according to your RecipeIngredient model.)
      originalIngr[ri.ingredient.ingredientName.toLowerCase().trim()] =
          (ri.baseAmount ?? 1.0);
    }
    Map<String, double> newIngr = {};
    for (var ri in newRecipe.ingredients) {
      newIngr[ri.ingredient.ingredientName.toLowerCase().trim()] =
          (ri.baseAmount ?? 1.0);
    }
    Set<String> originalNames = originalIngr.keys.toSet();
    Set<String> newNames = newIngr.keys.toSet();
    double jaccard = 0.0;
    if (originalNames.union(newNames).isNotEmpty) {
      jaccard = originalNames.intersection(newNames).length /
          originalNames.union(newNames).length;
    }
    // Now, for common ingredients, compute amount similarity.
    double amountSim = 0.0;
    if (originalNames.intersection(newNames).isNotEmpty) {
      double sum = 0.0;
      for (String key in originalNames.intersection(newNames)) {
        double origAmt = originalIngr[key]!;
        double newAmt = newIngr[key]!;
        double sim = (origAmt == 0 || newAmt == 0)
            ? 0.0
            : 1 -
                ((origAmt - newAmt).abs() /
                    (origAmt > newAmt ? origAmt : newAmt));
        sum += sim;
      }
      amountSim = sum / originalNames.intersection(newNames).length;
    } else {
      amountSim = 0.0;
    }
    // Combine name and amount similarity with weights (e.g., 75% name, 25% amount)
    double ingredientScore = (0.75 * jaccard) + (0.25 * amountSim);
    double ingredientContribution = ingredientScore * 40; // 40% weight

    // 3. Tag similarity – 20%
    Set<String> originalTags =
        originalRecipe.tags.map((tag) => tag.name.toLowerCase().trim()).toSet();
    Set<String> newTags =
        newRecipe.tags.map((tag) => tag.name.toLowerCase().trim()).toSet();
    double tagJaccard = 0.0;
    if (originalTags.union(newTags).isNotEmpty) {
      tagJaccard = originalTags.intersection(newTags).length /
          originalTags.union(newTags).length;
    }
    double tagContribution = tagJaccard * 20; // 20% weight

    // 4. Cooking steps similarity – 15%
    List<String> originalSteps =
        originalRecipe.cookingSteps.map((s) => s.toLowerCase().trim()).toList();
    List<String> newSteps =
        newRecipe.cookingSteps.map((s) => s.toLowerCase().trim()).toList();
    Set<String> originalStepsSet = originalSteps.toSet();
    Set<String> newStepsSet = newSteps.toSet();
    double stepsJaccard = 0.0;
    if (originalStepsSet.union(newStepsSet).isNotEmpty) {
      stepsJaccard = originalStepsSet.intersection(newStepsSet).length /
          originalStepsSet.union(newStepsSet).length;
    }
    double stepsContribution = stepsJaccard * 15; // 15% weight

    totalScore = timeContribution +
        ingredientContribution +
        tagContribution +
        stepsContribution;
    if (totalScore > 100) totalScore = 100;
    return totalScore;
  }

  Future<String> _uploadRecipeImage(File imageFile, String userId) async {
    Reference storageRef = FirebaseStorage.instance.ref().child(
        'recipe_images/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg');
    UploadTask uploadTask = storageRef.putFile(imageFile);
    AnalyticsService.logEvent(name: "recipe_image_uploaded");
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
      EasyStep(
        title: 'Basics',
        icon: Icon(Icons.info),
        activeIcon: Icon(
          Icons.info,
          color: MediaQuery.of(context).platformBrightness == Brightness.dark
              ? Colors.white
              : Colors.black,
        ),
      ),
      EasyStep(
          title: 'Ingredients',
          icon: Icon(Icons.shopping_cart),
          activeIcon: Icon(
            Icons.shopping_cart,
            color: MediaQuery.of(context).platformBrightness == Brightness.dark
                ? Colors.white
                : Colors.black,
          )),
      EasyStep(
          title: 'Amounts',
          icon: Icon(Icons.scale_rounded),
          activeIcon: Icon(
            Icons.scale_rounded,
            color: MediaQuery.of(context).platformBrightness == Brightness.dark
                ? Colors.white
                : Colors.black,
          )),
      EasyStep(
          title: 'Steps',
          icon: Icon(Icons.list),
          activeIcon: Icon(
            Icons.list,
            color: MediaQuery.of(context).platformBrightness == Brightness.dark
                ? Colors.white
                : Colors.black,
          )),
      EasyStep(
          title: 'Tags',
          icon: Icon(Icons.label),
          activeIcon: Icon(
            Icons.label,
            color: MediaQuery.of(context).platformBrightness == Brightness.dark
                ? Colors.white
                : Colors.black,
          )),
      EasyStep(
          title: 'Image',
          icon: Icon(Icons.image),
          activeIcon: Icon(
            Icons.image,
            color: MediaQuery.of(context).platformBrightness == Brightness.dark
                ? Colors.white
                : Colors.black,
          )),
    ];
  }
}
