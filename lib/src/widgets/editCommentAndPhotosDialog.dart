import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

class EditCommentAndPhotosDialog extends StatefulWidget {
  final String recipeId;
  final String commentId;
  final String initialText;
  final double? initialRating; // if you want to allow rating changes here
  final List<String> initialPhotos;

  const EditCommentAndPhotosDialog({
    Key? key,
    required this.recipeId,
    required this.commentId,
    required this.initialText,
    this.initialRating,
    required this.initialPhotos,
  }) : super(key: key);

  @override
  State<EditCommentAndPhotosDialog> createState() =>
      _EditCommentAndPhotosDialogState();
}

class _EditCommentAndPhotosDialogState
    extends State<EditCommentAndPhotosDialog> {
  late TextEditingController _textController;
  late List<String> _photos; // current list of photo URLs
  double? _rating; // if you need it

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText);
    _photos = List.from(widget.initialPhotos);
    _rating = widget.initialRating;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  // For picking & cropping a single new image
  Future<String?> _pickAndUploadNewPhoto() async {
    // 1) Use your same logic with ImagePicker + ImageCropper
    final picker = ImagePicker();
    final XFile? pickedFile =
        await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return null; // user canceled

    // Crop
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      compressFormat: ImageCompressFormat.png,
      compressQuality: 80,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: Colors.green,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: false,
        ),
        IOSUiSettings(title: 'Crop Image'),
      ],
    );
    if (croppedFile == null) return null;

    final file = File(croppedFile.path);

    // 2) Upload to Firebase Storage
    final storageRef = FirebaseStorage.instance.ref(
        'recipeImages/${widget.recipeId}/${DateTime.now().millisecondsSinceEpoch}.png');

    final uploadTask = storageRef.putFile(file);
    final snapshot = await uploadTask.whenComplete(() {});
    final newUrl = await snapshot.ref.getDownloadURL();

    return newUrl;
  }

  // Called when user taps "Replace Photo"
  Future<void> _replacePhoto(int index) async {
    final oldUrl = _photos[index];
    final newUrl = await _pickAndUploadNewPhoto();
    if (newUrl == null) return; // user canceled

    setState(() {
      _photos[index] = newUrl;
    });

    // If you want, you can immediately remove old file from storage
    // FirebaseStorage.instance.refFromURL(oldUrl).delete();
  }

  // Called when user taps "Remove"
  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
    });
  }

  // Called when user taps "Add Photo"
  Future<void> _addPhoto() async {
    if (_photos.length >= 3) {
      // obey your max 3 photos rule
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum of 3 photos allowed')),
      );
      return;
    }
    final newUrl = await _pickAndUploadNewPhoto();
    if (newUrl == null) return; // user canceled
    setState(() {
      _photos.add(newUrl);
    });
  }

  // Save changes to Firestore
  Future<void> _saveChanges() async {
    final commentText = _textController.text.trim();
    // rating if needed: final ratingValue = _rating ?? ...

    // 1) Update the doc
    final docRef = FirebaseFirestore.instance
        .collection('recipes')
        .doc(widget.recipeId)
        .collection('comments')
        .doc(widget.commentId);

    await docRef.update({
      'comment': commentText,
      'photos': _photos,
      // 'rating': ratingValue, if you want to store rating updates
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 2) done
    Navigator.pop(context, true); // pass "true" to indicate success
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Comment & Photos'),
      content: SizedBox(
        width: double.maxFinite, // Ensure the dialog has a bounded width
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight:
                  MediaQuery.of(context).size.height * 0.6, // Limit height
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      labelText: 'Comment text',
                      border: OutlineInputBorder(),
                    ),
                    minLines: 1,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 12),
                  if (_photos.isNotEmpty)
                    SizedBox(
                      height: 90,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _photos.length,
                        itemBuilder: (ctx, i) {
                          final url = _photos[i];
                          return Stack(
                            children: [
                              Container(
                                margin: const EdgeInsets.only(right: 8.0),
                                width: 80,
                                height: 80,
                                child: CachedNetworkImage(
                                  imageUrl: url,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'replace') {
                                      _replacePhoto(i);
                                    } else if (value == 'remove') {
                                      _removePhoto(i);
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(
                                      value: 'replace',
                                      child: Text('Replace'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'remove',
                                      child: Text('Remove'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  if (_photos.length < 3)
                    TextButton.icon(
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Add Photo'),
                      onPressed: _addPhoto,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveChanges,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
          child: Text('Save',
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
        ),
      ],
    );
  }
}
