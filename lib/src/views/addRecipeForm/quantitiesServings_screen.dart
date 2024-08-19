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
                  subtitle: TextFormField(
                    initialValue: recipeIngredient.baseAmount.toString(),
                    decoration: InputDecoration(labelText: 'Amount'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter an amount';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                    onChanged: (newValue) {
                      setState(() {
                        recipeIngredient.baseAmount = double.parse(newValue);
                        widget.onDataChanged(
                            'ingredients', widget.recipe.ingredients);
                      });
                    },
                  ),
                  trailing: SizedBox(
                    width: 100,
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(labelText: 'Unit'),
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
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextFormField(
              initialValue: widget.recipe.initialServings.toString(),
              decoration: InputDecoration(labelText: 'Servings'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter the number of servings';
                }
                if (int.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                return null;
              },
              onChanged: (newValue) {
                setState(() {
                  widget.recipe.initialServings = int.parse(newValue);
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

  void _saveForm() {
    if (widget.formKey.currentState!.validate()) {
      widget.formKey.currentState!.save();
    }
  }
}
