import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RecipeFeedbackDialog extends StatefulWidget {
  final String recipeId; // Optional: Link feedback to a specific recipe

  const RecipeFeedbackDialog({Key? key, required this.recipeId})
      : super(key: key);

  @override
  State<RecipeFeedbackDialog> createState() => _RecipeFeedbackDialogState();
}

class _RecipeFeedbackDialogState extends State<RecipeFeedbackDialog> {
  final _formKey = GlobalKey<FormState>();
  String feedback = '';
  String question1Answer = ''; // Open-ended feedback
  int easeOfUseRating = 5;
  int ingredientsSatisfactionRating = 5;
  String experiencedBugs = 'No';

  Future<void> _submitFeedback() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      try {
        await FirebaseFirestore.instance.collection('recipe_feedback').add({
          'userId': userId,
          'recipeId': widget.recipeId,
          'easeOfUseRating': easeOfUseRating,
          'ingredientsSatisfactionRating': ingredientsSatisfactionRating,
          'experiencedBugs': experiencedBugs,
          'feedback': question1Answer,
          'timestamp': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Thank you for your feedback!'),
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit feedback: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Provide Feedback'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Question 1: How easy was it to add a recipe?
              Align(
                alignment: Alignment.centerLeft,
                child: Text('How easy was it to add a recipe?'),
              ),
              SizedBox(height: 4),
              RatingBar.builder(
                initialRating: easeOfUseRating.toDouble(),
                minRating: 1,
                direction: Axis.horizontal,
                allowHalfRating: false,
                itemCount: 5,
                itemPadding: const EdgeInsets.symmetric(horizontal: 2.0),
                itemBuilder: (context, _) => const Icon(
                  Icons.star,
                  color: Colors.amber,
                ),
                onRatingUpdate: (newRating) {
                  setState(() {
                    easeOfUseRating = newRating.toInt();
                  });
                },
              ),
              SizedBox(height: 16),

              // Question 2: Did you find everything you were looking for in the ingredients?
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Did you find everything you were looking for in ingredients?',
                ),
              ),
              SizedBox(height: 4),
              RatingBar.builder(
                initialRating: ingredientsSatisfactionRating.toDouble(),
                minRating: 1,
                direction: Axis.horizontal,
                allowHalfRating: false,
                itemCount: 5,
                itemPadding: const EdgeInsets.symmetric(horizontal: 2.0),
                itemBuilder: (context, _) => const Icon(
                  Icons.star,
                  color: Colors.amber,
                ),
                onRatingUpdate: (newRating) {
                  setState(() {
                    ingredientsSatisfactionRating = newRating.toInt();
                  });
                },
              ),
              SizedBox(height: 16),

              // Question 3: Did you experience any bugs? (Dropdown)
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Did you experience any bugs?'),
              ),
              SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: experiencedBugs,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: ['No', 'Yes'].map((value) {
                  return DropdownMenuItem(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    experiencedBugs = value ?? 'No';
                  });
                },
              ),
              SizedBox(height: 16),

              // Question 4: Additional feedback (open-ended)
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Any additional feedback?'),
              ),
              SizedBox(height: 4),
              TextFormField(
                maxLines: 4,
                minLines: 3,
                decoration: InputDecoration(
                  hintText: 'Enter your feedback here...',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  question1Answer = value;
                },
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please provide some feedback.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submitFeedback,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
          child: Text(
            'Submit',
            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
          ),
        ),
      ],
    );
  }
}
