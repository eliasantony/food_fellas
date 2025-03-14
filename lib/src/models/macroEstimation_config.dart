import 'dart:convert';

import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:food_fellas/src/models/recipe.dart';

GenerativeModel? getMacroEstimation() {
  final model = FirebaseVertexAI.instance.generativeModel(
    model: 'gemini-2.0-flash',
    systemInstruction: Content.system(
        '''Based on the Ingredients and Amounts, try to estimate exactly how many Calories, Carbs, Proteins and Fat one serving of this recipe has! Only return output in a JSON structured like this:
          {
            "Calories": double (kcal)
            "Carbs": double (g)
            "Proteins": double (g)
            "Fat": double (g)
          }
        '''),
  );
  return model;
}

String buildMacroPrompt(Recipe recipe) {
  // Example: Provide the list of ingredients + amounts + serving size
  // The system instructions in getMacroEstimation() handle the rest.

  final sb = StringBuffer();
  sb.writeln("We have a recipe titled '${recipe.title}'.");
  sb.writeln("It makes ${recipe.initialServings} servings.");
  sb.writeln(
      "Ingredients list (with base amounts for ${recipe.initialServings} servings):");

  for (final ingr in recipe.ingredients) {
    sb.writeln(
        "- ${ingr.ingredient.ingredientName}: ${ingr.baseAmount} ${ingr.unit}");
  }

  sb.writeln(
      "\nEstimate how many Calories (kcal), Carbs (g), Proteins (g), and Fat (g) one serving has.");

  return sb.toString();
}

Map<String, dynamic> safeJsonParse(String responseText) {
  // Regular expression to match JSON object
  final jsonRegex = RegExp(r'\{.*?\}', dotAll: true);
  final match = jsonRegex.firstMatch(responseText);

  if (match == null) {
    throw FormatException('No valid JSON object found in AI response');
  }

  String jsonString = match.group(0)!;

  return Map<String, dynamic>.from(jsonDecode(jsonString));
}
