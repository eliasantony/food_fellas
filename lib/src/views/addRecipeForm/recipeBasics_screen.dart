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
  String _prepTimeUnit = 'minutes';
  String _cookTimeUnit = 'minutes';
  String? _prepTimeValue;
  String? _cookTimeValue;

  @override
  void initState() {
    super.initState();

    // Initialize Preparation Time
    if (widget.recipe.prepTime != null) {
      if (widget.recipe.prepTime! >= 60 && widget.recipe.prepTime! % 60 == 0) {
        // If prepTime is in whole hours
        _prepTimeUnit = 'hours';
        _prepTimeValue = (widget.recipe.prepTime! ~/ 60).toString();
      } else {
        _prepTimeUnit = 'minutes';
        _prepTimeValue = widget.recipe.prepTime!.toString();
      }
    } else {
      _prepTimeUnit = 'minutes';
      _prepTimeValue = '';
    }

    // Initialize Cooking Time
    if (widget.recipe.cookTime != null) {
      if (widget.recipe.cookTime! >= 60 && widget.recipe.cookTime! % 60 == 0) {
        // If cookTime is in whole hours
        _cookTimeUnit = 'hours';
        _cookTimeValue = (widget.recipe.cookTime! ~/ 60).toString();
      } else {
        _cookTimeUnit = 'minutes';
        _cookTimeValue = widget.recipe.cookTime!.toString();
      }
    } else {
      _cookTimeUnit = 'minutes';
      _cookTimeValue = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: ListView(
        padding: EdgeInsets.all(16.0),
        children: <Widget>[
          Text('Whats this recipe about?',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
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
          const SizedBox(height: 8),
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
          const SizedBox(height: 32),
          Text('How long does it take to make this recipe?',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildTimeInput(
            label: 'Preparation Time',
            timeValue: _prepTimeValue,
            timeUnit: _prepTimeUnit,
            onValueChanged: (value) {
              _prepTimeValue = value;
              _updateTotalTime();
            },
            onUnitChanged: (value) {
              _prepTimeUnit = value!;
              _updateTotalTime();
            },
          ),
          const SizedBox(height: 8),
          _buildTimeInput(
            label: 'Cooking Time',
            timeValue: _cookTimeValue,
            timeUnit: _cookTimeUnit,
            onValueChanged: (value) {
              _cookTimeValue = value;
              _updateTotalTime();
            },
            onUnitChanged: (value) {
              _cookTimeUnit = value!;
              _updateTotalTime();
            },
          ),
          const SizedBox(height: 16),
          Text('Total Time: ${_getTotalTimeString()}'),
        ],
      ),
    );
  }

  Widget _buildTimeInput({
    required String label,
    required String? timeValue,
    required String timeUnit,
    required ValueChanged<String> onValueChanged,
    required ValueChanged<String?> onUnitChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 58,
            child: TextFormField(
              initialValue: timeValue,
              decoration: InputDecoration(
                labelText: label,
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter $label';
                }
                if (int.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                return null;
              },
              onChanged: onValueChanged,
              onSaved: (value) {
                onValueChanged(value!);
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 58,
            child: DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Unit',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
              value: timeUnit,
              items: <String>['minutes', 'hours'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: onUnitChanged,
            ),
          ),
        ),
      ],
    );
  }

  void _updateTotalTime() {
    int prepTime = 0;
    int cookTime = 0;

    if (_prepTimeValue != null && _prepTimeValue!.isNotEmpty) {
      int? value = int.tryParse(_prepTimeValue!);
      if (value != null) {
        prepTime = _prepTimeUnit == 'hours' ? value * 60 : value;
        widget.recipe.prepTime = prepTime;
        widget.onDataChanged('prepTime', prepTime);
      }
    }

    if (_cookTimeValue != null && _cookTimeValue!.isNotEmpty) {
      int? value = int.tryParse(_cookTimeValue!);
      if (value != null) {
        cookTime = _cookTimeUnit == 'hours' ? value * 60 : value;
        widget.recipe.cookTime = cookTime;
        widget.onDataChanged('cookTime', cookTime);
      }
    }

    int totalTime = prepTime + cookTime;
    widget.recipe.totalTime = totalTime;
    widget.onDataChanged('totalTime', totalTime);
  }

  String _getTotalTimeString() {
    int totalTime = widget.recipe.totalTime ?? 0;
    if (totalTime >= 60) {
      int hours = totalTime ~/ 60;
      int minutes = totalTime % 60;
      if (minutes == 0) {
        return '$hours hours';
      } else {
        return '$hours hours $minutes minutes';
      }
    } else {
      return '$totalTime minutes';
    }
  }
}
