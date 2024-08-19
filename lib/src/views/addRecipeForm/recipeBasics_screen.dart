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

    _selectedUnit = widget.recipe.cookingTime.contains('hours')
        ? 'hours'
        : 'minutes';
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
            decoration: InputDecoration(labelText: 'Title'),
            validator: (value) => value!.trim().isEmpty ? 'Please enter a title' : null,
            onChanged: (value) => widget.onDataChanged('title', value.trim()),
            onSaved: (value) => widget.recipe.title = value!.trim(),
          ),
          TextFormField(
            initialValue: widget.recipe.description,
            decoration: InputDecoration(labelText: 'Description'),
            validator: (value) => value!.trim().isEmpty ? 'Please enter a description' : null,
            onChanged: (value) => widget.onDataChanged('description', value.trim()),
            onSaved: (value) => widget.recipe.description = value!.trim(),
          ),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: _cookingTimeValue,
                  decoration: InputDecoration(labelText: 'Cooking Time'),
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
              SizedBox(width: 10),
              DropdownButton<String>(
                value: _selectedUnit,
                items: <String>['minutes', 'hours']
                    .map<DropdownMenuItem<String>>((String value) {
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