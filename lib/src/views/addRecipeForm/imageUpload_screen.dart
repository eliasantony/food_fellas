import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/recipe.dart';

class ImageUploadPage extends StatefulWidget {
  final Recipe recipe;
  final Function(String, dynamic) onDataChanged;
  final GlobalKey<FormState> formKey;

  ImageUploadPage({
    Key? key,
    required this.recipe,
    required this.onDataChanged,
    required this.formKey,
  }) : super(key: key);

  @override
  _ImageUploadPageState createState() => _ImageUploadPageState();
}

class _ImageUploadPageState extends State<ImageUploadPage> {
  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            widget.recipe.imageUrl.isNotEmpty
                ? _displaySelectedImage(widget.recipe.imageUrl)
                : Text('No image selected.'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _pickImage(),
              child: Text('Upload Image'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Future implementation for AI image generation
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('AI-generated image feature coming soon!')),
                );
              },
              child: Text('Generate Image with AI'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _displaySelectedImage(String imageUrl) {
    try {
      if (File(imageUrl).existsSync()) {
        return Image.file(File(imageUrl), height: 200, fit: BoxFit.cover);
      } else {
        return Image.asset(imageUrl, height: 200, fit: BoxFit.cover);
      }
    } catch (e) {
      return Text('Failed to load image.');
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedImage = await picker.pickImage(source: ImageSource.gallery);
      if (pickedImage != null) {
        final directory = await getApplicationDocumentsDirectory();
        final fileName = basename(pickedImage.path);
        final localImagePath = '${directory.path}/$fileName';

        final File localImageFile =
            await File(pickedImage.path).copy(localImagePath);

        setState(() {
          widget.recipe.imageUrl = localImageFile.path;
        });

        widget.onDataChanged('imageUrl', localImageFile.path);
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context as BuildContext).showSnackBar(
        SnackBar(content: Text('Failed to pick image. Please try again.')),
      );
    }
  }
}
