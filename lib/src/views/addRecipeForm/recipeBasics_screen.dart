import 'package:flutter/material.dart';
import '../../models/recipe.dart';

class RecipeBasicsPage extends StatefulWidget {
  final Recipe recipe;
  final Function(String, dynamic) onDataChanged;
  final GlobalKey<FormState> formKey;

  RecipeBasicsPage({
    Key? key,
    required this.recipe,
    required this.onDataChanged,
    required this.formKey,
  }) : super(key: key);

  @override
  _RecipeBasicsPageState createState() => _RecipeBasicsPageState();
}

class _RecipeBasicsPageState extends State<RecipeBasicsPage> {
  String _selectedUnit = 'minutes';
  String? _cookingTimeValue;

  @override
  void initState() {
    super.initState();
    _cookingTimeValue = widget.recipe.cookingTime.isNotEmpty
        ? widget.recipe.cookingTime.replaceAll(RegExp(r'\D'), '')
        : null;

    _selectedUnit =
        widget.recipe.cookingTime.contains('hours') ? 'hours' : 'minutes';
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: ListView(
        padding: EdgeInsets.all(16.0),
        children: <Widget>[
          TextFormField(
            initialValue: widget.recipe.title,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
            validator: (value) =>
                value!.trim().isEmpty ? 'Please enter a title' : null,
            onChanged: (value) => widget.onDataChanged('title', value.trim()),
            onSaved: (value) => widget.recipe.title = value!.trim(),
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: widget.recipe.description,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
            maxLines: 3,
            validator: (value) =>
                value!.trim().isEmpty ? 'Please enter a description' : null,
            onChanged: (value) =>
                widget.onDataChanged('description', value.trim()),
            onSaved: (value) => widget.recipe.description = value!.trim(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 58, // Provide a fixed height for the text field
                  child: TextFormField(
                    initialValue: _cookingTimeValue,
                    decoration: const InputDecoration(
                      labelText: 'Cooking Time',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a cooking time';
                      }
                      if (int.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      _cookingTimeValue = value;
                      _updateCookingTime();
                    },
                    onSaved: (value) {
                      _cookingTimeValue = value!;
                      _updateCookingTime();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Wrap DropdownButtonFormField in SizedBox or Expanded to ensure size constraints
              Expanded(
                child: SizedBox(
                  height: 58, // Provide a fixed height for the dropdown
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    ),
                    value: _selectedUnit,
                    items: <String>['minutes', 'hours'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedUnit = newValue!;
                        _updateCookingTime();
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _updateCookingTime() {
    if (_cookingTimeValue != null && _cookingTimeValue!.isNotEmpty) {
      final cookingTimeString = '$_cookingTimeValue $_selectedUnit';
      widget.onDataChanged('cookingTime', cookingTimeString);
      widget.recipe.cookingTime = cookingTimeString;
    }
  }
}
