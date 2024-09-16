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
  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey, // Use the formKey passed from the parent
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: widget.recipe.ingredients.length,
              itemBuilder: (context, index) {
                var recipeIngredient = widget.recipe.ingredients[index];
                return ListTile(
                  title: Text(recipeIngredient.ingredient.ingredientName),
                  subtitle: Row(
                    children: [
                      // Ensure consistent height by wrapping in SizedBox with height
                      Expanded(
                        flex: 2, // Adjust flex ratio as needed
                        child: SizedBox(
                          height: 60, // Set consistent height for both fields
                          child: TextFormField(
                            initialValue: recipeIngredient.baseAmount.toString(),
                            decoration: const InputDecoration(
                              labelText: 'Amount',
                              contentPadding: EdgeInsets.symmetric(vertical: 20.0), // Match padding
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (newValue) {
                              setState(() {
                                if (newValue.isNotEmpty) {
                                  recipeIngredient.baseAmount = double.parse(newValue);
                                } else {
                                  recipeIngredient.baseAmount = 0;
                                }
                                widget.onDataChanged(
                                    'ingredients', widget.recipe.ingredients);
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 16), // Add some spacing between fields
                      Expanded(
                        flex: 1, // Adjust flex ratio as needed
                        child: SizedBox(
                          height: 60, // Match the height
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                              contentPadding: EdgeInsets.symmetric(vertical: 20.0), // Match padding
                            ),
                            value: recipeIngredient.unit,
                            onChanged: (newValue) {
                              setState(() {
                                recipeIngredient.unit = newValue!;
                                widget.onDataChanged(
                                    'ingredients', widget.recipe.ingredients);
                              });
                            },
                            items: ['g', 'ml', 'tbsp', 'tsp', 'cup', 'oz', 'lb']
                                .map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextFormField(
              initialValue: widget.recipe.initialServings.toString(),
              decoration: const InputDecoration(labelText: 'Servings'),
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

  /// Manually validates the form when proceeding to the next page or saving.
  bool _validateForm() {
    bool isValid = true;

    // Validate servings
    if (widget.recipe.initialServings == null || widget.recipe.initialServings! <= 0) {
      isValid = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid number of servings')),
      );
    }

    // Validate each ingredient amount
    for (var recipeIngredient in widget.recipe.ingredients) {
      if (recipeIngredient.baseAmount == null || recipeIngredient.baseAmount! <= 0) {
        isValid = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter valid amounts for all ingredients')),
        );
        break;
      }
    }

    return isValid;
  }
}