import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:food_fellas/providers/userProvider.dart';
import 'package:food_fellas/src/models/autoStepSelection_config.dart';
import 'package:food_fellas/src/utils/aiTokenUsage.dart';
import 'package:food_fellas/src/views/subscriptionScreen.dart';
import 'package:provider/provider.dart';
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

  bool _isLoading = false; // Loading state for AI request

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
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    _addStep();
                    // After adding the step, focus on the new TextFormField
                    Future.delayed(Duration(milliseconds: 100), () {
                      if (_itemKeys.isNotEmpty) {
                        FocusScope.of(context).requestFocus(FocusNode(
                            debugLabel: 'step_${_controllers.length - 1}'));
                      }
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: EdgeInsets.symmetric(horizontal: 15),
                  ),
                  icon: Icon(Icons.add),
                  label: Text(
                    'Add Step',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                  ),
                ),
                if (widget.recipe.source != 'image_to_recipe' &&
                    widget.recipe.source != 'ai_chat' &&
                    !widget.recipe.hasGeneratedAISteps) ...[
                  SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: (widget.recipe.hasGeneratedAISteps || _isLoading)
                        ? null
                        : _generateCookingStepsWithAI,
                    icon: _isLoading
                        ? SizedBox(
                            width: 8,
                            height: 8,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ))
                        : Icon(Icons.auto_awesome),
                    label: Text('AI Generate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (widget.recipe.hasGeneratedAISteps)
                          ? Colors.grey
                          : Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: EdgeInsets.symmetric(horizontal: 15),
                    ),
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _addStep() {
    print(widget.recipe.source);
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

  Future<void> _generateCookingStepsWithAI() async {
    if (widget.recipe.hasGeneratedAISteps) return;

    setState(() {
      _isLoading = true;
    });

    final model = getAutoStepSelection(recipe: widget.recipe);

    final prompt = '''
  Generate a structured step-by-step cooking guide for the following recipe:
  Title: "${widget.recipe.title}"
  Description: "${widget.recipe.description}"
  Cooking Time: "${widget.recipe.totalTime ?? "Unknown"} minutes"
  Ingredients: ${widget.recipe.ingredients.map((i) => i.ingredient.ingredientName).join(", ")}
  
  Please return just the numbered steps, nothing else.
  ''';

    final currentUser = FirebaseAuth.instance.currentUser;
    final userProvider = Provider.of<UserDataProvider>(context, listen: false);
    final isSubscribed = userProvider.userData?['subscribed'] ?? false;
    final isAdmin = userProvider.userData?['isAdmin'] ?? false;
    if (await canUseAiChat(currentUser!.uid, isAdmin, isSubscribed, 2000) == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You have exceeded your daily AI usage limit. Please try again tommorow.',
          ),
          action: SnackBarAction(
            label: "Upgrade",
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => SubscriptionScreen()));
            },
          ),
        ),
      );
      return;
    }

    try {
      final response = await model?.generateContent([Content.text(prompt)]);
      final responseText = response?.text ?? '';
      if (responseText.isEmpty) {
        throw Exception('No steps returned from AI.');
      }
      // Track usage tokens
      final usedTokens = response?.usageMetadata?.totalTokenCount ?? 0;
      if (kDebugMode) debugPrint('Used tokens: $usedTokens');

      // Store or update user’s total tokens
      await updateDailyTokenUsage(currentUser.uid, usedTokens);

      // Strip numbering (e.g., "1. Add salt" -> "Add salt")
      List<String> generatedSteps = responseText
          .split('\n')
          .where((s) => s.trim().isNotEmpty)
          .map((step) => step.replaceFirst(RegExp(r'^\d+\.\s*'), ''))
          .toList();

      if (generatedSteps.isEmpty) {
        throw Exception('Invalid AI response.');
      }

      setState(() {
        _isLoading = false;
      });

      if (!mounted) {
        return; // Ensure widget is still in the tree before opening dialog
      }

      Future.delayed(Duration(milliseconds: 100), () {
        _showConfirmationDialog(generatedSteps);
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating steps: $e')),
      );
    }
  }

  void _showConfirmationDialog(List<String> generatedSteps) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('AI-Generated Steps'),
          content: Container(
            width: double.maxFinite, // Ensure it takes full width
            child: Column(
              mainAxisSize:
                  MainAxisSize.min, // Ensures it does not expand infinitely
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Instructions',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Flexible(
                  // Ensures proper height management
                  child: ListView.separated(
                    shrinkWrap: true, // Prevents infinite height issue
                    physics:
                        AlwaysScrollableScrollPhysics(), // Allows scrolling
                    itemCount: generatedSteps.length,
                    separatorBuilder: (context, index) => Divider(),
                    itemBuilder: (context, index) {
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 16,
                          child: Text('${index + 1}'),
                        ),
                        title: Text(generatedSteps[index]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Discard AI steps
              },
              child: Text('Discard'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  widget.recipe.cookingSteps = generatedSteps;
                  widget.recipe.hasGeneratedAISteps = true;
                });
                _initializeControllers();
                widget.onDataChanged('cookingSteps', generatedSteps);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary),
              child: Text('Apply Steps',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary)),
            ),
          ],
        );
      },
    );
  }
}
