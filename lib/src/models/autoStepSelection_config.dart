import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:food_fellas/src/models/recipe.dart';

GenerativeModel? getAutoStepSelection({required Recipe recipe}) {
  final model = FirebaseVertexAI.instance.generativeModel(
    model: 'gemini-2.0-flash',
    systemInstruction: Content.system(
      '''Generate clear and structured cooking steps for the provided recipe. 
      The response should be a numbered list of instructions. 
      Do not add extra text or explanations. Return just the steps.''',
    ),
  );
  return model;
}
