// admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:food_fellas/providers/feedbackProvider.dart';
import 'package:food_fellas/src/views/addRecipeForm/importRecipes_screen.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final feedbackProvider = Provider.of<FeedbackProvider>(context);

    return DefaultTabController(
      length: 3, // Updated to 3 tabs
      child: Scaffold(
        appBar: AppBar(
          title: Text('Admin Dashboard'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Overall Feedback'),
              Tab(text: 'Recipe Feedback'),
              Tab(text: 'Import Recipes'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Overall Feedback Tab
            FeedbackList(
              stream: feedbackProvider.getOverallFeedback(),
              feedbackType: 'Overall Feedback',
            ),
            // Recipe Feedback Tab
            FeedbackList(
              stream: feedbackProvider.getRecipeFeedback(),
              feedbackType: 'Recipe Feedback',
            ),
            // Import Recipes Tab
            ImportRecipesTab(),
          ],
        ),
      ),
    );
  }
}

// admin_dashboard.dart

class FeedbackList extends StatelessWidget {
  final Stream<QuerySnapshot> stream;
  final String feedbackType;

  const FeedbackList({super.key, required this.stream, required this.feedbackType});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final feedbacks = snapshot.data!.docs;

        if (feedbacks.isEmpty) {
          return Center(child: Text('No $feedbackType yet.'));
        }

        return ListView.builder(
          itemCount: feedbacks.length,
          itemBuilder: (context, index) {
            final doc = feedbacks[index];
            final data = doc.data() as Map<String, dynamic>;
            final docId = doc.id; // Extract the document ID
            return FeedbackTile(
              data: data,
              feedbackType: feedbackType,
              docId: docId, // Pass the document ID
              parentContext: context, // Pass the parent context
            );
          },
        );
      },
    );
  }
}

class FeedbackTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final String feedbackType;
  final String docId;
  final BuildContext parentContext;

  const FeedbackTile({
    super.key,
    required this.data,
    required this.feedbackType,
    required this.docId,
    required this.parentContext,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Feedback Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'User ID: ${data['userId']}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 5),
                  if (feedbackType == 'Recipe Feedback') ...[
                    Text('Recipe ID: ${data['recipeId']}'),
                    Text('Ease of Use: ${data['easeOfUseRating']} ⭐'),
                    Text(
                        'Ingredients Satisfaction: ${data['ingredientsSatisfactionRating']} ⭐'),
                    Text('Experienced Bugs: ${data['experiencedBugs']}'),
                  ] else ...[
                    Text('Category: ${data['category']}'),
                    Text('Screen: ${data['screen']}'),
                    Text('Rating: ${data['rating']} ⭐'),
                  ],
                  SizedBox(height: 5),
                  Text('Feedback: ${data['feedback']}'),
                  SizedBox(height: 5),
                  Text(
                    'Submitted on: ${data['timestamp'] != null ? (data['timestamp'] as Timestamp).toDate().toString() : 'N/A'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),

            // Vertical Divider
            Container(
              height: 120, // Adjust height to align with content
              width: 1,
              color: Colors.grey.shade300,
              margin: EdgeInsets.symmetric(horizontal: 10),
            ),

            // Delete Button
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () => _confirmDelete(parentContext),
            ),
          ],
        ),
      ),
    );
  }

  /// Displays a confirmation dialog before deletion
  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Feedback'),
          content: Text('Are you sure you want to delete this feedback?'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(); // Dismiss the dialog
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error),
              onPressed: () {
                _deleteFeedback(context);
                Navigator.of(context).pop();
              },
              child: Text(
                'Delete',
                style: TextStyle(color: Theme.of(context).colorScheme.onError),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Deletes the feedback document from Firestore
  Future<void> _deleteFeedback(BuildContext context) async {
    try {
      // Determine the correct collection based on feedback type
      String collectionName =
          feedbackType == 'Recipe Feedback' ? 'recipe_feedback' : 'feedback';

      await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(docId)
          .delete();

      // Show a success message
      ScaffoldMessenger.of(parentContext).showSnackBar(
        SnackBar(
          content: Text('Feedback deleted successfully.'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // Handle any errors
      ScaffoldMessenger.of(parentContext).showSnackBar(
        SnackBar(
          content: Text('Failed to delete feedback: $e'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

// New Widget for Import Recipes Tab
class ImportRecipesTab extends StatelessWidget {
  const ImportRecipesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ImportRecipesPage(); // Embed the existing ImportRecipesPage
  }
}
