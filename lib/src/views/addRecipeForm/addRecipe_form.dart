import 'package:flutter/material.dart';
import 'package:easy_stepper/easy_stepper.dart';
import '../../models/recipe.dart';
import 'recipeBasics_screen.dart';
import 'ingredientsSelection_screen.dart';
import 'quantitiesServings_screen.dart';
import 'cookingSteps_screen.dart';
import 'imageUpload_screen.dart';

class AddRecipeForm extends StatefulWidget {
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

  Recipe recipe = Recipe();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add a Recipe')),
      body: Column(
        children: <Widget>[
          SingleChildScrollView(
            child: SizedBox(
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
      child: Row(
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
            onPressed:
                _currentStep < _totalSteps() - 1 ? _nextPage : _submitForm,
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
      try {
        print('Recipe Data: ${recipe.toJson()}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recipe submitted successfully!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting recipe: $e')),
        );
      }
    }
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
        case 'imageUrl':
          recipe.imageUrl = value;
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