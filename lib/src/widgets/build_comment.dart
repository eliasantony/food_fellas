import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:food_fellas/src/views/profile_screen.dart';

class BuildComment extends StatelessWidget {
  const BuildComment({
    super.key,
    required this.commentData,
    required this.rating,
    required this.isAdmin,
  });

  final Map<String, dynamic> commentData;
  final double rating;
  final bool isAdmin;

  void _editComment(BuildContext context) {
    final TextEditingController commentController =
        TextEditingController(text: commentData['comment']);
    double updatedRating = rating;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Comment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RatingBar.builder(
                initialRating: updatedRating,
                minRating: 1,
                direction: Axis.horizontal,
                allowHalfRating: false,
                itemCount: 5,
                itemSize: 30.0,
                itemBuilder: (context, _) => const Icon(
                  Icons.star,
                  color: Colors.amber,
                ),
                onRatingUpdate: (newRating) {
                  updatedRating = newRating;
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: commentController,
                decoration: const InputDecoration(
                  labelText: 'Update your comment',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance
                      .collection('recipes')
                      .doc(commentData['recipeId'])
                      .collection('comments')
                      .doc(commentData['commentId'])
                      .update({
                    'comment': commentController.text.trim(),
                    'rating': updatedRating,
                    'timestamp': FieldValue.serverTimestamp(),
                  });
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Comment updated successfully')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update comment: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: Text('Save',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary)),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteComment(BuildContext context) async {
    bool confirm = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Delete Comment?'),
              content:
                  const Text('Are you sure you want to delete this comment?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: Text(
                    'Delete',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.onError),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;

    if (confirm) {
      try {
        await FirebaseFirestore.instance
            .collection('recipes')
            .doc(commentData['recipeId'])
            .collection('comments')
            .doc(commentData['commentId'])
            .delete();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment deleted successfully')),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete comment: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final bool isOwnComment = currentUser?.uid == commentData['userId'];

    return ListTile(
      title: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ProfileScreen(userId: commentData['userId']),
            ),
          );
        },
        child: Text(commentData['userName'] ?? 'Anonymous'),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rating > 0)
            RatingBarIndicator(
              rating: rating,
              itemBuilder: (context, index) => const Icon(
                Icons.star,
                color: Colors.amber,
              ),
              itemCount: 5,
              itemSize: 16.0,
            ),
          Text(commentData['comment'] ?? ''),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            commentData['timestamp'] != null
                ? (commentData['timestamp'] as Timestamp)
                    .toDate()
                    .toLocal()
                    .toString()
                    .split(' ')[0]
                    .split('-')
                    .reversed
                    .join('.')
                : '',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          if (isOwnComment || isAdmin)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'edit') {
                  _editComment(context);
                } else if (value == 'delete') {
                  _confirmDeleteComment(context);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
