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
              itemCount: widget.recipe.cookingSteps.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }

                  // Reorder the cooking steps in the model
                  final step = widget.recipe.cookingSteps.removeAt(oldIndex);
                  widget.recipe.cookingSteps.insert(newIndex, step);

                  // Update the data
                  widget.onDataChanged('cookingSteps', widget.recipe.cookingSteps);
                });
              },
              itemBuilder: (context, index) {
                // Create a new controller for each step's text dynamically
                final stepController = TextEditingController(
                  text: widget.recipe.cookingSteps[index],
                );

                return Padding(
                  key: ValueKey('step_$index'),
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
                      // Multiline TextFormField for step input
                      Expanded(
                        child: TextFormField(
                          controller: stepController,
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
                            // Directly update the recipe model on text change
                            widget.recipe.cookingSteps[index] = value;
                            widget.onDataChanged('cookingSteps', widget.recipe.cookingSteps);
                          },
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            widget.recipe.cookingSteps.removeAt(index);
                            widget.onDataChanged('cookingSteps', widget.recipe.cookingSteps);
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
                  // Add a new empty step
                  widget.recipe.cookingSteps.add('');
                  widget.onDataChanged('cookingSteps', widget.recipe.cookingSteps);
                });
              },
              child: Text('Add Step'),
            ),
          ),
        ],
      ),
    );
  }
}
