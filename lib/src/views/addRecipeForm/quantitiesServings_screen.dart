import 'package:flutter/material.dart';
import '../../models/recipe.dart';

class QuantitiesAndServingsPage extends StatefulWidget {
  final Recipe recipe;
  final Function(String, dynamic) onDataChanged;

  QuantitiesAndServingsPage({
    Key? key,
    required this.recipe,
    required this.onDataChanged,
  }) : super(key: key);

  @override
  _QuantitiesAndServingsPageState createState() =>
      _QuantitiesAndServingsPageState();
}

class _QuantitiesAndServingsPageState extends State<QuantitiesAndServingsPage> {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: widget.recipe.ingredients.length,
            itemBuilder: (context, index) {
              var ingredient = widget.recipe.ingredients[index];
              return ListTile(
                title: Text(ingredient.ingredientName),
                subtitle: TextFormField(
                  initialValue: ingredient.baseAmount.toString(),
                  decoration: InputDecoration(labelText: 'Amount'),
                  keyboardType: TextInputType.number,
                  onSaved: (newValue) {
                    ingredient.baseAmount = double.parse(newValue!);
                    widget.onDataChanged(
                        'ingredients', widget.recipe.ingredients);
                  },
                ),
                trailing: SizedBox(
                  width: 100,
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(labelText: 'Unit'),
                    value: ingredient.unit,
                    onChanged: (newValue) {
                      setState(() {
                        ingredient.unit = newValue!;
                        widget.onDataChanged(
                            'ingredients', widget.recipe.ingredients);
                      });
                    },
                    items: ['g', 'ml', 'tbsp']
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
            onSaved: (newValue) {
              widget.recipe.initialServings = int.parse(newValue!);
              widget.onDataChanged(
                  'initialServings', widget.recipe.initialServings);
            },
          ),
        ),
      ],
    );
  }
}
