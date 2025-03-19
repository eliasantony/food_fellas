import 'package:flutter/material.dart';
import '../../models/recipe.dart';

class QuantitiesAndServingsPage extends StatefulWidget {
  final Recipe recipe;
  final Function(String, dynamic) onDataChanged;
  final GlobalKey<FormState> formKey; // Pass the formKey from the parent

  QuantitiesAndServingsPage({
    Key? key,
    required this.recipe,
    required this.onDataChanged,
    required this.formKey, // Ensure formKey is passed in
  }) : super(key: key);

  @override
  _QuantitiesAndServingsPageState createState() =>
      _QuantitiesAndServingsPageState();
}

class _QuantitiesAndServingsPageState extends State<QuantitiesAndServingsPage> {
  List<String> units = [
    'g',
    'kg',
    'ml',
    'pieces',
    'slices',
    'tbsp',
    'tsp',
    'pinch',
    'leaf',
    'clove',
    'unit',
    'bottle',
    'can',
    'other',
  ];

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey, // Use the formKey passed from the parent
      child: ListView(
        padding: EdgeInsets.only(
          bottom: kFloatingActionButtonMargin + 56, // Extra space for FABs
          left: 16,
          right: 16,
          top: 8,
        ),
        children: [
          ...widget.recipe.ingredients.map((recipeIngredient) {
            bool isUnitInList = units.contains(recipeIngredient.unit);

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipeIngredient.ingredient.ingredientName,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            initialValue: recipeIngredient.baseAmount != null
                                ? recipeIngredient.baseAmount.toString()
                                : (recipeIngredient.amountDescription ?? ''),
                            decoration: const InputDecoration(
                              labelText: 'Amount',
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 5.0, horizontal: 10),
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.text,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter an amount';
                              }
                              return null;
                            },
                            onChanged: (newValue) {
                              setState(() {
                                if (newValue.isNotEmpty) {
                                  final parsedValue = double.tryParse(newValue);
                                  if (parsedValue != null) {
                                    recipeIngredient.baseAmount = parsedValue;
                                    recipeIngredient.amountDescription = null;
                                  } else {
                                    recipeIngredient.baseAmount = null;
                                    recipeIngredient.amountDescription =
                                        newValue;
                                  }
                                } else {
                                  recipeIngredient.baseAmount = null;
                                  recipeIngredient.amountDescription = null;
                                }
                                widget.onDataChanged(
                                    'ingredients', widget.recipe.ingredients);
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 5.0, horizontal: 10),
                              border: OutlineInputBorder(),
                            ),
                            value: (recipeIngredient.unit != null &&
                                    recipeIngredient.unit!.isNotEmpty &&
                                    units.contains(recipeIngredient.unit))
                                ? recipeIngredient.unit
                                : 'g',
                            onChanged: (newValue) {
                              setState(() {
                                recipeIngredient.unit = newValue!;
                                widget.onDataChanged(
                                    'ingredients', widget.recipe.ingredients);
                              });
                            },
                            items: units
                                .map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),

          // Add Servings field inside the ListView
          Padding(
            padding:
                const EdgeInsets.only(top: 16.0), // Space above servings field
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How many servings is this for?',
                  style: Theme.of(context).textTheme.labelLarge,
                  textAlign: TextAlign.left,
                ),
                SizedBox(height: 8),
                TextFormField(
                  initialValue: widget.recipe.initialServings != null
                      ? widget.recipe.initialServings.toString()
                      : '',
                  decoration: const InputDecoration(
                    labelText: 'Servings',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (newValue) {
                    setState(() {
                      if (newValue.isNotEmpty) {
                        widget.recipe.initialServings = int.parse(newValue);
                      } else {
                        widget.recipe.initialServings = 0; // Allow clearing
                      }
                      widget.onDataChanged(
                          'initialServings', widget.recipe.initialServings);
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Call this method when moving to the next page or submitting the form.
  void _saveForm() {
    // Perform validation manually
    if (_validateForm()) {
      widget.formKey.currentState!.save();
    }
  }

  bool _validateForm() {
    bool isValid = true;

    // Validate servings
    if (widget.recipe.initialServings == null ||
        widget.recipe.initialServings <= 0 ||
        widget.recipe.initialServings > 100) {
      isValid = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a valid number of servings')),
      );
    }

    // Validate each ingredient amount
    for (var recipeIngredient in widget.recipe.ingredients) {
      bool amountIsValid = (recipeIngredient.baseAmount != null &&
              recipeIngredient.baseAmount! > 0) ||
          (recipeIngredient.amountDescription != null &&
              recipeIngredient.amountDescription!.isNotEmpty);

      if (!amountIsValid ||
          (recipeIngredient.unit == null || recipeIngredient.unit!.isEmpty)) {
        isValid = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Please enter valid amounts and units for all ingredients')),
        );
        break;
      }
    }

    return isValid;
  }
}
