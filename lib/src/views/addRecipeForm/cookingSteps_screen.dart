import 'package:flutter/material.dart';
import '../../models/recipe.dart';

class CookingStepsPage extends StatefulWidget {
  final Recipe recipe;
  final Function(String, dynamic) onDataChanged;
  final GlobalKey<FormState> formKey; // Add the GlobalKey from the parent

  CookingStepsPage({
    Key? key,
    required this.recipe,
    required this.onDataChanged,
    required this.formKey, // Ensure formKey is passed in
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
    return Form(
      key: widget.formKey, // Use the formKey passed from the parent
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), // Ensure button stays above keyboard
        child: Column(
          children: [
            // Expand the ListView.builder inside a fixed height widget like SizedBox
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.7, // Adjust the height as needed
              child: ListView.builder(
                itemCount: _controllers.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _controllers[index],
                            decoration: InputDecoration(
                              labelText: 'Step ${index + 1}',
                            ),
                            maxLines: null,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a description for this step';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              widget.recipe.cookingSteps[index] = value;
                              widget.onDataChanged(
                                  'cookingSteps', widget.recipe.cookingSteps);
                            },
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _controllers.removeAt(index);
                              widget.recipe.cookingSteps.removeAt(index);
                              widget.onDataChanged(
                                  'cookingSteps', widget.recipe.cookingSteps);
                            });
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Button is moved above the keyboard when the keyboard is shown
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _controllers.add(TextEditingController());
                    widget.recipe.cookingSteps.add(''); // Add a new empty step
                    widget.onDataChanged(
                        'cookingSteps', widget.recipe.cookingSteps); // Update the data
                  });
                },
                child: Text('Add Step'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controllers.forEach((controller) => controller.dispose());
    super.dispose();
  }
}