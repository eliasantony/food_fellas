import 'package:flutter/material.dart';
import 'package:easy_stepper/easy_stepper.dart';
import 'package:flutter/widgets.dart';
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
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  PageController _pageController = PageController();

  Recipe recipe = Recipe();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text('Add a Recipe'),
      ),
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
                  lineSpace: 4,
                  lineType: LineType.normal,
                  defaultLineColor: Colors.grey,
                  finishedLineColor: Theme.of(context).colorScheme.secondary,
                ),
                activeStepTextColor: Theme.of(context).colorScheme.onPrimary,
                finishedStepTextColor:
                    Theme.of(context).colorScheme.onSecondary,
                internalPadding: 4,
                showLoadingAnimation: false,
                stepRadius: 24,
                showStepBorder: false,
                steps: _buildEasySteps(),
                // steps: List.generate(
                //   _totalSteps(),
                //   (index) => EasyStep(
                //     title: 'Step ${index + 1}',
                //     customStep: CircleAvatar(
                //       radius: 8,
                //       backgroundColor: Colors.white,
                //       child: CircleAvatar(
                //         radius: 7,
                //         backgroundColor: _currentStep >= index
                //             ? Theme.of(context).colorScheme.secondary
                //             : Colors.white,
                //       ),
                //     ),
                //     topTitle: index % 2 == 0,
                //   ),
                // ),
                onStepReached: (index) {
                  setState(() {
                    _currentStep = index;
                  });
                  _pageController.animateToPage(
                    index,
                    duration: Duration(milliseconds: 300),
                    curve: Curves.ease,
                  );
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
                    recipe: recipe, onDataChanged: _updateRecipeData),
                IngredientsSelectionPage(
                    recipe: recipe, onDataChanged: _updateRecipeData),
                QuantitiesAndServingsPage(
                    recipe: recipe, onDataChanged: _updateRecipeData),
                CookingStepsPage(
                    recipe: recipe, onDataChanged: _updateRecipeData),
                ImageUploadPage(
                    recipe: recipe, onDataChanged: _updateRecipeData),
              ],
            ),
          ),
          SizedBox(height: 100, child: _buildFloatingActionButtons())
        ],
      ),
      // floatingActionButton: _buildFloatingActionButtons(),
    );
  }

  Widget _buildFloatingActionButtons() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          FloatingActionButton(
            heroTag: "nextPageBtn",
            onPressed: _currentStep > 0 ? _previousPage : null,
            backgroundColor: _currentStep > 0
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
            child: Icon(Icons.arrow_back),
          ),
          FloatingActionButton(
            heroTag: "previousPageBtn",
            onPressed:
                _currentStep < _totalSteps() - 1 ? _nextPage : _submitForm,
            backgroundColor: _currentStep < _totalSteps() - 1
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.secondary,
            child: Icon(_currentStep < _totalSteps() - 1
                ? Icons.arrow_forward
                : Icons.check),
          ),
        ],
      ),
    );
  }

  void _nextPage() {
    if (_currentStep < _totalSteps() - 1) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    }
  }

  void _previousPage() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    }
  }

  void _submitForm() {
    // if (_formKey.currentState!.validate()) {
    // Submit the form
    print('Recipe Data: $recipe');
    print('Recipe Data: ${recipe.toJson()}');
    print('${_formKey.currentState}');
    // You would usually send this data to a server or Firebase
    // }
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
      }
    });
  }

  int _totalSteps() => 5; // Total number of pages/steps in the form

  List<Step> _buildSteps() {
    return [
      Step(
        title: Text('Basics'),
        content: SizedBox(),
        isActive: _currentStep == 0,
        state: _currentStep > 0 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: Text('Ingredients'),
        content: SizedBox(),
        isActive: _currentStep == 1,
        state: _currentStep > 1 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: Text('Amounts'),
        content: SizedBox(),
        isActive: _currentStep == 2,
        state: _currentStep > 2 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: Text('Steps'),
        content: SizedBox(),
        isActive: _currentStep == 3,
        state: _currentStep > 3 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: Text('Image'),
        content: SizedBox(),
        isActive: _currentStep == 4,
        state: _currentStep > 4 ? StepState.complete : StepState.indexed,
      ),
    ];
  }

  List<EasyStep> _buildEasySteps() {
    return [
      const EasyStep(
        title: 'Basics',
        icon: Icon(Icons.info),
        topTitle: false,
      ),
      const EasyStep(
        title: 'Ingredients',
        icon: Icon(Icons.shopping_cart),
        topTitle: false,
      ),
      const EasyStep(
        title: 'Amounts',
        icon: Icon(Icons.line_weight),
        topTitle: false,
      ),
      const EasyStep(
        title: 'Steps',
        icon: Icon(Icons.list),
        topTitle: false,
      ),
      const EasyStep(
        title: 'Image',
        icon: Icon(Icons.image),
        topTitle: false,
      ),
    ];
  }
}
