import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class FeedbackModal extends StatefulWidget {
  @override
  _FeedbackModalState createState() => _FeedbackModalState();
}

class _FeedbackModalState extends State<FeedbackModal> {
  String feedback = '';
  String selectedCategory = 'Suggestion';
    String selectedScreen = 'Home';
  int rating = 5;
  final _formKey = GlobalKey<FormState>();

  void _submitFeedback() {
    FirebaseFirestore.instance.collection('feedback').add({
      'feedback': feedback,
      'category': selectedCategory,
      'screen': selectedScreen,
      'rating': rating,
      'timestamp': FieldValue.serverTimestamp(),
      'userId': FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Thank you for your feedback!'),
        duration: Duration(seconds: 2),
      ),
    );
    Navigator.of(context).pop();
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
              // Feedback Categories Dropdown
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: [
                  'Urgent',
                  'Bug Report',
                  'Suggestion',
                  'Praise',
                  'Other',
                ].map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      selectedCategory = value;
                    });
                  }
                },
              ),
              SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedScreen,
                decoration: InputDecoration(
                  labelText: 'Screen',
                  border: OutlineInputBorder(),
                ),
                items: [
                  'Home',
                  'Add Recipe Form',
                  'Search',
                  'Shopping List',
                  'AI Chat'
                  'Profile',
                  'Settings',
                  'Other',
                ].map((screen) {
                  return DropdownMenuItem(
                    value: screen,
                    child: Text(screen),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      selectedScreen = value;
                    });
                  }
                },
              ),
              SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Rate your experience:'),
              ),
              SizedBox(height: 8),
              // Rating System
              RatingBar.builder(
                initialRating: rating.toDouble(),
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
                    rating = newRating.toInt();
                  });
                },
              ),
              SizedBox(height: 8),
              // Multi-line Feedback TextField
              TextFormField(
                maxLines: 5,
                minLines: 3,
                onChanged: (value) {
                  setState(() {
                    feedback = value;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Your Feedback',
                  hintText: 'Enter detailed feedback here...',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your feedback.';
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
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              _submitFeedback();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
          child: Text('Submit', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
        ),
      ],
    );
  }
}