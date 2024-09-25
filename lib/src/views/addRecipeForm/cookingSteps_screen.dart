import 'package:flutter/material.dart';
import '../../models/recipe.dart';

class CookingStepsPage extends StatefulWidget {
  final Recipe recipe;
  final Function(String, dynamic) onDataChanged;
  final GlobalKey<FormState> formKey;

  CookingStepsPage({
    Key? key,
    required this.recipe,
    required this.onDataChanged,
    required this.formKey,
  }) : super(key: key);

  @override
  _CookingStepsPageState createState() => _CookingStepsPageState();
}

class _CookingStepsPageState extends State<CookingStepsPage> {
  List<TextEditingController> _controllers = [];

  @override
  void initState() {
    super.initState();
    // Initialize controllers for existing steps
    _controllers = widget.recipe.cookingSteps
        .map((step) => TextEditingController(text: step))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: Column(
        children: [
          // Dynamically sized list view with reordering functionality
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              itemCount: _controllers.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  // Adjust the newIndex if necessary
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }

                  // Reorder the TextEditingControllers
                  final controller = _controllers.removeAt(oldIndex);
                  _controllers.insert(newIndex, controller);

                  // Reorder the actual cooking steps in the data model
                  final step = widget.recipe.cookingSteps.removeAt(oldIndex);
                  widget.recipe.cookingSteps.insert(newIndex, step);

                  // Ensure the data is correctly updated after reordering
                  widget.onDataChanged(
                      'cookingSteps', widget.recipe.cookingSteps);
                });
              },
              itemBuilder: (context, index) {
                return Padding(
                  key: ValueKey('step_$index'), // Unique key for reordering
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      // Handle to drag and reorder steps
                      ReorderableDragStartListener(
                        index: index,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Icon(Icons.drag_handle),
                        ),
                      ),
                      // Step input field with multiline support
                      Expanded(
                        child: TextFormField(
                          controller: _controllers[index],
                          decoration: InputDecoration(
                            labelText: 'Step ${index + 1}',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                          ),
                          keyboardType: TextInputType.multiline,
                          maxLines: null, // Allow multiline input
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a description for this step';
                            }
                            return null;
                          },
                          onChanged: (value) {
                            // Update the step description in the recipe model
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
          // "Add Step" button stays pinned at the bottom
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  // Add a new empty step and a corresponding controller
                  _controllers.add(TextEditingController());
                  widget.recipe.cookingSteps.add(''); // Add an empty step
                  widget.onDataChanged(
                      'cookingSteps', widget.recipe.cookingSteps);
                });
              },
              child: Text('Add Step'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controllers.forEach((controller) => controller.dispose());
    super.dispose();
  }
}
