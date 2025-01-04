import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/recipe.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:lottie/lottie.dart';
import 'package:cloud_functions/cloud_functions.dart';

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
  bool _isLoading = false;
  // Remove the prompt controller
  // final TextEditingController _promptController = TextEditingController();

  // Customization options
  List<String> backgrounds = [
    'Wooden Table',
    'Marble Countertop',
    'Rustic Setting'
  ];
  List<String> styles = ['Bright and Airy', 'Dark and Moody', 'Vibrant Colors'];
  List<String> platingStyles = ['Minimalist', 'Garnished', 'Family Style'];

  String selectedBackground = 'Wooden Table';
  String selectedStyle = 'Bright and Airy';
  String selectedPlating = 'Minimalist';

  @override
  void dispose() {
    // _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading)
                _buildLoadingIndicator()
              else
                _buildImageDisplay(),
              SizedBox(height: 20),
              _isLoading ? Container() : _buildButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Lottie.asset(
          'lib/assets/lottie/loadingAnim.json', // Path to your Lottie file
          width: 200,
          height: 200,
          fit: BoxFit.fill,
        ),
        SizedBox(height: 20),
        Text(
          'Our chefs are cooking up your image...',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildImageDisplay() {
    if (widget.recipe.imageFile != null) {
      return _displaySelectedImage(widget.recipe.imageFile!);
    } else if (widget.recipe.imageUrl != null) {
      return _displayNetworkImage(widget.recipe.imageUrl!);
    } else {
      widget.recipe.imageUrl = 'https://via.placeholder.com/150';
      return _displayNetworkImage(widget.recipe.imageUrl!);
    }
  }

  Widget _displaySelectedImage(File imageFile) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: FileImage(imageFile),
          fit: BoxFit.cover,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _displayNetworkImage(String imageUrl) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: CachedNetworkImageProvider(imageUrl),
          fit: BoxFit.cover,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _buildButtons() {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: _pickImage,
          icon: Icon(Icons.upload_file),
          label: Text('Upload Image'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          ),
        ),
        SizedBox(height: 8),
        _buildCustomizationOptions(),
        SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _generateImageWithAI,
          icon: Icon(Icons.auto_awesome),
          label: Text('Generate Image with AI'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomizationOptions() {
    return Column(
      children: [
        _buildDropdown('Background', backgrounds, selectedBackground,
            (String? newValue) {
          setState(() {
            selectedBackground = newValue!;
          });
        }),
        SizedBox(height: 8),
        _buildDropdown('Style', styles, selectedStyle, (String? newValue) {
          setState(() {
            selectedStyle = newValue!;
          });
        }),
        SizedBox(height: 8),
        _buildDropdown('Plating', platingStyles, selectedPlating,
            (String? newValue) {
          setState(() {
            selectedPlating = newValue!;
          });
        }),
      ],
    );
  }

  Widget _buildDropdown(String label, List<String> items, String selectedItem,
      ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Text('$label: ', style: TextStyle(fontSize: 16)),
          SizedBox(width: 10),
          Expanded(
            child: DropdownButton<String>(
              value: selectedItem,
              onChanged: onChanged,
              isExpanded: true,
              items: items.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
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

  Future<void> _generateImageWithAI() async {
    // Build the prompt
    String ingredientList = widget.recipe.ingredients
        .take(3)
        .map((ingredient) => ingredient.ingredient.ingredientName)
        .join(', ');

    String cuisine = '';
    String dishType = '';

    for (var tag in widget.recipe.tags) {
      if (tag.category == 'Cuisines') {
        cuisine = tag.name;
      } else if (tag.category == 'Meal Types') {
        dishType = tag.name;
      }
    }

    if (cuisine.isEmpty) cuisine = 'international';
    if (dishType.isEmpty) dishType = 'dish';

    String prompt =
        'Create a high-quality, hyperrealistic photograph of "${widget.recipe.title}", '
        'a delicious $cuisine $dishType made with $ingredientList. '
        'Styled in a professional food photography setting with a $selectedBackground background, '
        '$selectedStyle style, and $selectedPlating plating.';

    print('Prompt: $prompt');
    try {
      setState(() {
        _isLoading = true;
      });

      // Call the Cloud Function
      HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('generateImage');
      final result = await callable.call(<String, dynamic>{
        'prompt': prompt,
      });

      setState(() {
        _isLoading = false;
      });

      final imageUrl = result.data['url'];

      setState(() {
        widget.recipe.imageUrl = imageUrl;
      });

      widget.onDataChanged('imageUrl', imageUrl);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error generating image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating image: $e')),
      );
    }
  }
}
