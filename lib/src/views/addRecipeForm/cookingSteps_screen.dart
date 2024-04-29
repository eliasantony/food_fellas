import 'package:flutter/material.dart';
import '../../models/recipe.dart';

class CookingStepsPage extends StatefulWidget {
  final Recipe recipe;
  final Function(String, dynamic) onDataChanged;

  CookingStepsPage({
    Key? key,
    required this.recipe,
    required this.onDataChanged,
  }) : super(key: key);

  @override
  _CookingStepsPageState createState() => _CookingStepsPageState();
}

class _CookingStepsPageState extends State<CookingStepsPage> {
  List<TextEditingController> _controllers = [];

  @override
  void initState() {
    super.initState();
    _controllers = widget.recipe.cookingSteps
        .map((step) => TextEditingController(text: step))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _controllers.length,
            itemBuilder: (context, index) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: TextFormField(
                  controller: _controllers[index],
                  decoration: InputDecoration(
                    labelText: 'Step ${index + 1}',
                  ),
                  maxLines: null,
                ),
              );
            },
          ),
        ),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _controllers.add(TextEditingController());
            });
          },
          child: Text('Add Step'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controllers.forEach((controller) => controller.dispose());
    super.dispose();
  }
}
