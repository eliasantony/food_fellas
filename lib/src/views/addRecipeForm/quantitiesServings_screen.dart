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
    'tbsp',
    'tsp',
    'pinch',
    'cup',
    'oz',
    'lb',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey, // Use the formKey passed from the parent
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: widget.recipe.ingredients.length,
              itemBuilder: (context, index) {
                var recipeIngredient = widget.recipe.ingredients[index];

                // Determine if the unit is in the predefined units list
                bool isUnitInList = units.contains(recipeIngredient.unit);

                // Handle the case where unit is 'Other' or not in the units list
                bool showCustomUnitField =
                    !isUnitInList || recipeIngredient.unit == 'Other';

                return Card(
                  margin:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
                                initialValue:
                                    recipeIngredient.baseAmount != null
                                        ? recipeIngredient.baseAmount.toString()
                                        : (recipeIngredient.amountDescription ??
                                            ''),
                                decoration: const InputDecoration(
                                  labelText: 'Amount',
                                  contentPadding: EdgeInsets.symmetric(
                                      vertical: 5.0, horizontal: 10),
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType:
                                    TextInputType.text, // Allow text input
                                onChanged: (newValue) {
                                  setState(() {
                                    if (newValue.isNotEmpty) {
                                      final parsedValue =
                                          double.tryParse(newValue);
                                      if (parsedValue != null) {
                                        recipeIngredient.baseAmount =
                                            parsedValue;
                                        recipeIngredient.amountDescription =
                                            null;
                                      } else {
                                        recipeIngredient.baseAmount = null;
                                        recipeIngredient.amountDescription =
                                            newValue;
                                      }
                                    } else {
                                      recipeIngredient.baseAmount = null;
                                      recipeIngredient.amountDescription = null;
                                    }
                                    widget.onDataChanged('ingredients',
                                        widget.recipe.ingredients);
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: showCustomUnitField
                                  ? TextFormField(
                                      decoration: const InputDecoration(
                                        labelText: 'Unit',
                                        contentPadding: EdgeInsets.symmetric(
                                            vertical: 5.0, horizontal: 10),
                                        border: OutlineInputBorder(),
                                      ),
                                      initialValue: recipeIngredient.unit,
                                      onChanged: (newValue) {
                                        setState(() {
                                          recipeIngredient.unit = newValue;
                                          widget.onDataChanged('ingredients',
                                              widget.recipe.ingredients);
                                        });
                                      },
                                    )
                                  : DropdownButtonFormField<String>(
                                      decoration: const InputDecoration(
                                        labelText: 'Unit',
                                        contentPadding: EdgeInsets.symmetric(
                                            vertical: 5.0, horizontal: 10),
                                        border: OutlineInputBorder(),
                                      ),
                                      value: recipeIngredient.unit,
                                      onChanged: (newValue) {
                                        setState(() {
                                          if (newValue == 'Other') {
                                            recipeIngredient.unit = '';
                                          } else {
                                            recipeIngredient.unit = newValue!;
                                          }
                                          widget.onDataChanged('ingredients',
                                              widget.recipe.ingredients);
                                        });
                                      },
                                      items: units
                                          .map<DropdownMenuItem<String>>(
                                              (String value) {
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
              },
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextFormField(
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
        widget.recipe.initialServings <= 0) {
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
