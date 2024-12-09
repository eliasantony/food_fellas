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
    widget.recipe.cookingSteps = widget.recipe.cookingSteps ?? [];
    _initializeControllers();
  }

  @override
  void dispose() {
    // Dispose all controllers
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeControllers() {
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
              onReorder: _onReorder,
              itemBuilder: (context, index) {
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
                            // Update the recipe model when text changes
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
                            // Remove the controller and the step
                            _controllers[index].dispose();
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
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton(
              onPressed: _addStep,
              child: Text('Add Step'),
            ),
          ),
        ],
      ),
    );
  }

  void _addStep() {
    setState(() {
      // Add a new controller and a new empty step
      _controllers.add(TextEditingController());
      widget.recipe.cookingSteps.add('');
      widget.onDataChanged('cookingSteps', widget.recipe.cookingSteps);
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;

      // Move the controller
      final controller = _controllers.removeAt(oldIndex);
      _controllers.insert(newIndex, controller);

      // Reorder the cooking steps in the model
      final step = widget.recipe.cookingSteps.removeAt(oldIndex);
      widget.recipe.cookingSteps.insert(newIndex, step);

      widget.onDataChanged('cookingSteps', widget.recipe.cookingSteps);
    });
  }
}
