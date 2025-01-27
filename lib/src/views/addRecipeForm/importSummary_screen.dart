import 'package:flutter/material.dart';
import 'package:food_fellas/src/models/recipe.dart';

/// Simple data class to hold error info
class RecipeImportError {
  final Recipe recipe;
  final String errorMessage;

  RecipeImportError(this.recipe, this.errorMessage);
}

class ImportSummaryPage extends StatelessWidget {
  final List<Recipe> successList;
  final List<RecipeImportError> failureList;

  const ImportSummaryPage({
    Key? key,
    required this.successList,
    required this.failureList,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Import Summary'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                'Successfully imported: ${successList.length}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              for (var recipe in successList)
                ListTile(
                  title: Text(recipe.title.isEmpty ? 'No Title' : recipe.title),
                  subtitle: Text('ID: ${recipe.id ?? 'N/A'}'),
                  leading: Icon(Icons.check_circle, color: Colors.green),
                ),
              Divider(height: 32),
              Text(
                'Failures: ${failureList.length}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              for (var failure in failureList)
                ListTile(
                  title: Text(failure.recipe.title.isEmpty
                      ? 'No Title'
                      : failure.recipe.title),
                  subtitle: Text(failure.errorMessage),
                  leading: Icon(Icons.error, color: Colors.red),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
