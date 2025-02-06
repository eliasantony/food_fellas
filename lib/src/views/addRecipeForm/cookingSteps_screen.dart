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
  final ScrollController _scrollController = ScrollController();
  List<GlobalKey> _itemKeys = [];

  @override
  void initState() {
    super.initState();
    widget.recipe.cookingSteps = widget.recipe.cookingSteps ?? [];
    _initializeControllers();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeControllers() {
    if (widget.recipe.cookingSteps.isEmpty) {
      widget.recipe.cookingSteps.add('');
      _itemKeys.add(GlobalKey());
    } else {
      _itemKeys =
          List.generate(widget.recipe.cookingSteps.length, (_) => GlobalKey());
    }
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
              scrollController: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              itemCount: _controllers.length,
              onReorder: _onReorder,
              itemBuilder: (context, index) {
                return Material(
                    key: _itemKeys[index],
                    child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
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
                                  widget.onDataChanged('cookingSteps',
                                      widget.recipe.cookingSteps);
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
                                  widget.onDataChanged('cookingSteps',
                                      widget.recipe.cookingSteps);
                                });
                              },
                            ),
                          ],
                        )));
              },
            ),
          ),
          // "Add Step" button stays pinned at the bottom
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton(
              onPressed: _addStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: EdgeInsets.symmetric(horizontal: 30),
              ),
              child: Text(
                'Add Step',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addStep() {
    setState(() {
      _controllers.add(TextEditingController());
      widget.recipe.cookingSteps.add('');
      _itemKeys.add(GlobalKey()); // Add a new key for the new step
      widget.onDataChanged('cookingSteps', widget.recipe.cookingSteps);
    });
    // Scroll to the bottom after the frame is rendered.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;

      // Move the controller
      final controller = _controllers.removeAt(oldIndex);
      _controllers.insert(newIndex, controller);

      // Move the key
      final key = _itemKeys.removeAt(oldIndex);
      _itemKeys.insert(newIndex, key);

      // Reorder the cooking steps in the model
      final step = widget.recipe.cookingSteps.removeAt(oldIndex);
      widget.recipe.cookingSteps.insert(newIndex, step);

      widget.onDataChanged('cookingSteps', widget.recipe.cookingSteps);
    });
  }
}
