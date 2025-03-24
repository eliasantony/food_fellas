import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:food_fellas/src/views/profile_screen.dart';
import 'package:food_fellas/src/widgets/editCommentAndPhotosDialog.dart';
import 'package:food_fellas/src/widgets/multi_photoview_screen.dart';

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

  void _editComment(BuildContext context) async {
    // show the new unified dialog
    await showDialog<bool>(
      context: context,
      builder: (_) {
        return EditCommentAndPhotosDialog(
          recipeId: commentData['recipeId'],
          commentId: commentData['id'],
          initialText: commentData['comment'] ?? '',
          initialRating: commentData['rating']?.toDouble(), // if you use rating
          initialPhotos: List<String>.from(commentData['photos'] ?? []),
        );
      },
    );

    // after the dialog, we can optionally do something like refresh or show a Toast
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
                      backgroundColor: Theme.of(context).colorScheme.error),
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
            .doc(commentData['id'])
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
    final List photos = commentData['photos'] ?? [];

    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (photos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 0, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: photos.map<Widget>((photoUrl) {
                    return GestureDetector(
                      onTap: () {
                        // If tapped, open the photo in MultiPhotoViewScreen
                        // (or single photo viewer). We'll do multi for a gallery:
                        final photoItems = photos
                            .map((url) => {
                                  'imageUrl': url,
                                  'userName':
                                      commentData['userName'] ?? 'Anonymous',
                                  'timestamp': commentData['timestamp'],
                                  'rating': rating,
                                  'comment': commentData['comment'],
                                  'commentId': commentData['id'],
                                  'userId': commentData['userId'],
                                  'recipeId': commentData['recipeId'],
                                })
                            .toList();

                        final initialIndex = photos.indexOf(photoUrl);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MultiPhotoViewScreen(
                              photoItems: photoItems,
                              initialIndex: initialIndex,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: 60,
                        height: 60,
                        margin: const EdgeInsets.only(right: 8.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: photoUrl,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
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
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
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
                SizedBox(height: 4),
                Text(commentData['comment'] ?? ''),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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
          ),
        ],
      ),
    );
  }
}
