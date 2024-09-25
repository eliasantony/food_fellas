import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
        child: SingleChildScrollView( // Wrap in SingleChildScrollView to prevent overflow
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              widget.recipe.imageFile != null
                  ? _displaySelectedImage(widget.recipe.imageFile!)
                  : widget.recipe.imageUrl != null
                      ? _displayNetworkImage(widget.recipe.imageUrl!)
                      : Text('No image selected.'),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _pickImage,
                child: Text('Upload Image'),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  // Future implementation for AI image generation
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text('AI-generated image feature coming soon!')),
                  );
                },
                child: Text('Generate Image with AI'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _displaySelectedImage(File imageFile) {
    return Image.file(imageFile, height: 200, fit: BoxFit.cover);
  }

  Widget _displayNetworkImage(String imageUrl) {
    return Image.network(imageUrl, height: 200, fit: BoxFit.cover);
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedImage = await picker.pickImage(source: ImageSource.gallery);
      if (pickedImage != null) {
        final File imageFile = File(pickedImage.path);

        setState(() {
          widget.recipe.imageFile = imageFile;
        });

        widget.onDataChanged('imageFile', imageFile);
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image. Please try again.')),
      );
    }
  }
}
