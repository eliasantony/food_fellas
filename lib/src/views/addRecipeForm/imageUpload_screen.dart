import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/recipe.dart';

class ImageUploadPage extends StatefulWidget {
  final Recipe recipe;
  final Function(String, dynamic) onDataChanged;

  ImageUploadPage({
    Key? key,
    required this.recipe,
    required this.onDataChanged,
  }) : super(key: key);

  @override
  _ImageUploadPageState createState() => _ImageUploadPageState();
}

class _ImageUploadPageState extends State<ImageUploadPage> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          widget.recipe.imageUrl.isNotEmpty
              ? Image.asset(widget.recipe.imageUrl)
              : Text('No image selected.'),
          ElevatedButton(
            onPressed: () async {
              final picker = ImagePicker();
              final pickedImage =
                  await picker.pickImage(source: ImageSource.gallery);
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
            },
            child: Text('Upload Image'),
          ),
        ],
      ),
    );
  }
}
