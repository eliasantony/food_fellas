import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:flutter/material.dart';
import 'package:food_fellas/providers/userProvider.dart';
import 'package:food_fellas/src/models/macroEstimation_config.dart';
import 'package:food_fellas/src/models/recipe.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

class MacrosSection extends StatefulWidget {
  final Recipe recipe;
  const MacrosSection({Key? key, required this.recipe}) : super(key: key);

  @override
  _MacrosSectionState createState() => _MacrosSectionState();
}

class _MacrosSectionState extends State<MacrosSection> {
  bool _isLoadingMacros = false;
  String? _currentUserRole;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserRole();
  }

  Future<void> _fetchCurrentUserRole() async {
    final userProvider = Provider.of<UserDataProvider>(context, listen: false);
    final userRole = userProvider.userData?['role'] ?? 'user';
    setState(() {
      _currentUserRole = userProvider.userData?['role'];
    });
  }

  Future<void> _estimateMacrosForRecipe() async {
    if (widget.recipe == null) return;
    setState(() {
      _isLoadingMacros = true;
    });

    try {
      // 1) Construct prompt from your recipe’s ingredients & servings
      final promptContent = buildMacroPrompt(widget.recipe!);

      // 2) Get the generative model
      final model = getMacroEstimation();
      if (model == null) {
        throw Exception('Macro estimation model is not configured properly.');
      }

      // 3) Send the prompt
      final response =
          await model.generateContent([Content.text(promptContent)]);

      // 4) Parse JSON from response
      final jsonString = response.text;
      // Make sure the model returns valid JSON
      final Map<String, dynamic> macros = safeJsonParse(jsonString!);

      double? estimatedCalories = (macros['Calories'] as num?)?.toDouble();
      double? estimatedCarbs = (macros['Carbs'] as num?)?.toDouble();
      double? estimatedProtein = (macros['Proteins'] as num?)?.toDouble();
      double? estimatedFat = (macros['Fat'] as num?)?.toDouble();

      if (estimatedCalories == null ||
          estimatedCarbs == null ||
          estimatedProtein == null ||
          estimatedFat == null) {
        throw Exception(
            'Could not parse macros from AI response. Raw: $jsonString');
      }

      // 5) Update Firestore
      await FirebaseFirestore.instance
          .collection('recipes')
          .doc(widget.recipe!.id)
          .update({
        'calories': estimatedCalories,
        'carbs': estimatedCarbs,
        'protein': estimatedProtein,
        'fat': estimatedFat,
      });

      // 6) Update local recipe
      setState(() {
        widget.recipe
          ..calories = estimatedCalories
          ..carbs = estimatedCarbs
          ..protein = estimatedProtein
          ..fat = estimatedFat;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Macro estimation saved!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error estimating macros: $e')),
      );
    } finally {
      setState(() {
        _isLoadingMacros = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Card(
          margin: const EdgeInsets.all(8.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estimated Macros',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Per Serving',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text('Information'),
                                  content: const Text(
                                      'These macro values are AI generated and may not be accurate. Do not rely on them for medical purposes.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline,
                                  color: Colors.grey, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                'AI generated estimations',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.grey,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (widget.recipe?.calories != null &&
                    widget.recipe?.carbs != null &&
                    widget.recipe?.protein != null &&
                    widget.recipe?.fat != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildMacroColumn(
                          'Calories', widget.recipe!.calories, 'kcal'),
                      _verticalDivider(),
                      _buildMacroColumn('Carbs', widget.recipe!.carbs, 'g'),
                      _verticalDivider(),
                      _buildMacroColumn('Protein', widget.recipe!.protein, 'g'),
                      _verticalDivider(),
                      _buildMacroColumn('Fat', widget.recipe!.fat, 'g'),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: Icon(
                        Icons.calculate,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                      label: Text(
                        'Estimate Macros',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                      ),
                      onPressed: () async {
                        setState(() {
                          _isLoadingMacros = true;
                        });
                        await _estimateMacrosForRecipe();
                        setState(() {
                          _isLoadingMacros = false;
                        });
                      },
                    ),
                  ),
                if (_currentUserRole == 'admin')
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: Icon(
                          Icons.refresh,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                        label: Text(
                          'Refetch Macros',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                        ),
                        onPressed: () async {
                          setState(() {
                            _isLoadingMacros = true;
                          });
                          await _estimateMacrosForRecipe();
                          setState(() {
                            _isLoadingMacros = false;
                          });
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_isLoadingMacros)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMacroColumn(String label, double? value, String unit) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value != null
              ? value.toStringAsFixed(0) + (label == 'Calories' ? '' : 'g')
              : '--',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _verticalDivider() {
    return Container(
      height: 50,
      width: 1,
      color: Colors.grey[300],
    );
  }
}
