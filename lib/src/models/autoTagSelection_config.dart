import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:food_fellas/src/models/recipe.dart';
import 'package:food_fellas/src/models/tag.dart';

GenerativeModel? getAutoTagSelection(
    {required Recipe recipe, required Map<String, List<Tag>> categorizedTags}) {
  final model = FirebaseVertexAI.instance.generativeModel(
    model: 'gemini-1.5-flash',
    systemInstruction: Content.system(
        '''Return just the tagNames of the tags that are most relevant to the recipe. Try to use as many fitting tags that could fit!'''),
  );
  return model;
}
