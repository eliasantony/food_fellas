import 'package:flutter/material.dart';

import '../../models/recipe.dart';

class RecipeBasicsPage extends StatefulWidget {
  final Recipe recipe;
  final Function(String, dynamic) onDataChanged;

  RecipeBasicsPage({
    Key? key,
    required this.recipe,
    required this.onDataChanged,
  }) : super(key: key);

  @override
  _RecipeBasicsPageState createState() => _RecipeBasicsPageState();
}

class _RecipeBasicsPageState extends State<RecipeBasicsPage> {
  final _localFormKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _localFormKey,
      child: ListView(
        padding: EdgeInsets.all(16.0),
        children: <Widget>[
          TextFormField(
            initialValue: widget.recipe.title,
            decoration: InputDecoration(labelText: 'Title'),
            validator: (value) =>
                value!.isEmpty ? 'Please enter a title' : null,
            onSaved: (value) => widget.recipe.title = value!,
          ),
          TextFormField(
            initialValue: widget.recipe.description,
            decoration: InputDecoration(labelText: 'Description'),
            validator: (value) =>
                value!.isEmpty ? 'Please enter a description' : null,
            onSaved: (value) => widget.recipe.description = value!,
          ),
          TextFormField(
            initialValue: widget.recipe.cookingTime.toString(),
            decoration: InputDecoration(labelText: 'Cooking Time'),
            validator: (value) =>
                value!.isEmpty ? 'Please enter a cooking time' : null,
            onSaved: (value) => widget.recipe.cookingTime = value!,
          ),
        ],
      ),
    );
  }

  void _saveForm() {
    if (_localFormKey.currentState!.validate()) {
      _localFormKey.currentState!.save();
    }
  }
}
