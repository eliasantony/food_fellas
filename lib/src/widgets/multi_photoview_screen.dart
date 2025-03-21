import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:food_fellas/providers/userProvider.dart';
import 'package:food_fellas/src/widgets/editCommentAndPhotosDialog.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MultiPhotoViewScreen extends StatefulWidget {
  final List<Map<String, dynamic>> photoItems;
  final int initialIndex;

  const MultiPhotoViewScreen({
    super.key,
    required this.photoItems,
    required this.initialIndex,
  });

  @override
  State<MultiPhotoViewScreen> createState() => _MultiPhotoViewScreenState();
}

class _MultiPhotoViewScreenState extends State<MultiPhotoViewScreen> {
  late PageController _pageController;
  late int currentIndex; // which photo is currently displayed

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = widget.photoItems.length;
    final currentPhoto = widget.photoItems[currentIndex];

    final ownerId = currentPhoto['userId'] as String?;
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner = (currentUser != null && currentUser.uid == ownerId);

    // check if user is admin
    final userProvider = Provider.of<UserDataProvider>(context, listen: false);
    final isAdmin = (userProvider.userData?['role'] == 'admin');

    final canEditOrDelete = isOwner || isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: Text('${currentIndex + 1} / $itemCount'),
        actions: [
          if (canEditOrDelete)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _editComment(context, currentIndex);
                } else if (value == 'delete') {
                  _deleteComment(context, currentIndex);
                }
              },
              itemBuilder: (ctx) => [
                // EDIT
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit),
                    title: Text('Edit'),
                  ),
                ),
                // DELETE entire comment doc
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete, color: Colors.red),
                    title: Text('Delete Comment'),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Stack(
        children: [
          // Photo carousel
          PhotoViewGallery.builder(
            pageController: _pageController,
            itemCount: itemCount,
            builder: (context, index) {
              final photoData = widget.photoItems[index];
              final imageUrl = photoData['imageUrl'] ?? '';
              return PhotoViewGalleryPageOptions(
                imageProvider: CachedNetworkImageProvider(imageUrl),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2,
              );
            },
            onPageChanged: (idx) {
              setState(() {
                currentIndex = idx;
              });
            },
            scrollPhysics: const BouncingScrollPhysics(),
            backgroundDecoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
            ),
          ),
          // Transparent info overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.all(12.0),
              child:
                  _buildPhotoOverlay(context, widget.photoItems[currentIndex]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoOverlay(
      BuildContext context, Map<String, dynamic> photoData) {
    final userName = photoData['userName'] ?? 'Anonymous';
    final timestamp = photoData['timestamp'] as Timestamp?;
    final dateString = timestamp != null
        ? timestamp.toDate().toLocal().toString().split(' ')[0]
        : '';
    final rating = photoData['rating']?.toDouble() ?? 0.0;
    final comment = (photoData['comment'] ?? '').toString().trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Username & date
          Text(
            '$userName • $dateString',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          // If rating, show it
          if (rating > 0) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                Text(
                  rating.toStringAsFixed(1),
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ],
          // If there's a comment text
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              comment,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  // ************ EDIT COMMENT ************
  void _editComment(BuildContext context, int index) async {
    final photoData = widget.photoItems[index];
    final recipeId = photoData['recipeId'];
    final commentId = photoData['commentId'] as String?;

    if (commentId == null) {
      // no doc to edit
      return;
    }

    // We gather all the data we need for the existing comment
    // so we can pass it to your EditCommentAndPhotosDialog
    // We'll do a quick Firestore get() to ensure we have the latest fields
    final docRef = FirebaseFirestore.instance
        .collection('recipes')
        .doc(recipeId)
        .collection('comments')
        .doc(commentId);

    final docSnap = await docRef.get();
    if (!docSnap.exists) {
      // doc is gone or invalid
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment does not exist!')),
      );
      return;
    }

    final data = docSnap.data()!;
    final text = data['comment'] ?? '';
    final photos = List<String>.from(data['photos'] ?? []);
    final rating =
        data['rating'] != null ? (data['rating'] as num).toDouble() : null;

    final result = await showDialog<bool>(
      context: context,
      builder: (_) {
        return EditCommentAndPhotosDialog(
          recipeId: recipeId,
          commentId: commentId,
          initialText: text,
          initialRating: rating,
          initialPhotos: photos,
        );
      },
    );

    if (result == true) {
      // user saved changes
      // you might want to refresh the parent or pop this screen
      // For now, let's just do a small message:
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment updated successfully!')),
      );

      // Option 1: simply pop back:
      Navigator.pop(context); // close the multi photo view

      // Option 2: re-fetch the doc and rebuild the list
      // but you likely have a stream in the parent so it auto-updates
    }
  }

  // ************ DELETE COMMENT ************
  void _deleteComment(BuildContext context, int index) async {
    final photoData = widget.photoItems[index];
    final recipeId = photoData['recipeId'];
    final commentId = photoData['commentId'] as String?;

    if (commentId == null) {
      // nothing to delete
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Comment?'),
        content:
            const Text('Are you sure you want to delete this entire comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: TextStyle(color: Theme.of(context).colorScheme.onError)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // user wants to delete
      final docRef = FirebaseFirestore.instance
          .collection('recipes')
          .doc(recipeId)
          .collection('comments')
          .doc(commentId);

      // Optionally: remove the photos from Storage if you want:
      // 1) get doc to see the photos array
      final docSnap = await docRef.get();
      if (docSnap.exists) {
        final data = docSnap.data()!;
        final photos = data['photos'] as List<dynamic>? ?? [];
        for (String url in photos) {
          try {
            await FirebaseStorage.instance.refFromURL(url).delete();
          } catch (e) {
            // If you want to handle errors if the file is missing
          }
        }
      }

      // 2) delete the doc
      await docRef.delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment deleted successfully!')),
      );

      // close the gallery
      Navigator.pop(context);
    }
  }
}
