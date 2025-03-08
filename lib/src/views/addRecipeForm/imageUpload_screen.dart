import 'dart:io';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:food_fellas/src/models/recipe.dart';
import 'package:food_fellas/src/services/analytics_service.dart';
import 'package:food_fellas/src/services/imageCompression.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:lottie/lottie.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:path_provider/path_provider.dart';

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
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Here you can either upload a picture of your dish...',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.left,
                ),
                SizedBox(height: 16),
                Form(
                  key: widget.formKey,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isLoading)
                          _buildLoadingIndicator()
                        else
                          _buildImageDisplay(),
                        SizedBox(height: 20),
                        if (!_isLoading) _buildButtons(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
    // Check if the recipe has a locally selected image
    if (widget.recipe.imageFile != null) {
      return _displaySelectedImage(widget.recipe.imageFile!);
    }

    // Check if the recipe has a valid imageUrl
    if (widget.recipe.imageUrl != null &&
        _isValidUrl(widget.recipe.imageUrl!)) {
      return _displayNetworkImage(widget.recipe.imageUrl!);
    }

    // Fallback to a local placeholder image
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
                'lib/assets/images/dinner-placeholder.png'), // Local placeholder
            fit: BoxFit.cover,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
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
    return CachedNetworkImage(
      imageUrl: imageUrl,
      progressIndicatorBuilder: (context, url, downloadProgress) => Center(
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(value: downloadProgress.progress),
        ),
      ),
      errorWidget: (context, url, error) => Image.asset(
        'lib/assets/images/dinner-placeholder.png', // Local fallback
        width: double.infinity,
        height: 200,
        fit: BoxFit.cover,
      ),
      width: double.infinity,
      height: 200,
      fit: BoxFit.cover,
    );
  }

  bool _isValidUrl(String url) {
    return url.isNotEmpty &&
        (url.startsWith('http') || url.startsWith('https'));
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
            padding: EdgeInsets.symmetric(horizontal: 30),
          ),
        ),
        SizedBox(height: 8),
        // Only show AI options if recipe.source is not "image_to_recipe"
        if (widget.recipe.source != "image_to_recipe") ...[
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Text(
                  'Or let AI create a picture for you!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.left,
                ),
              ],
            ),
          ),
          _buildCustomizationOptions(),
          SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _generateImageWithAI,
            icon: Icon(Icons.auto_awesome),
            label: Text('Generate Image with AI'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: EdgeInsets.symmetric(horizontal: 30),
            ),
          ),
        ] else ...[
          // Optionally, show a message that an image has already been provided
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'A real image is already uploaded, so AI generation is disabled.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
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
        SizedBox(height: 4),
        _buildDropdown('Style', styles, selectedStyle, (String? newValue) {
          setState(() {
            selectedStyle = newValue!;
          });
        }),
        SizedBox(height: 4),
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
      final ImageSource? selectedSource =
          await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (BuildContext context) {
          return SafeArea(
            child: Wrap(
              children: <Widget>[
                ListTile(
                  leading: Icon(Icons.camera_alt),
                  title: Text('Take a Photo'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: Icon(Icons.photo_library),
                  title: Text('Choose from Gallery'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          );
        },
      );

      // If user cancels selection, return early
      if (selectedSource == null) return;

      final XFile? image = await picker.pickImage(source: selectedSource);

      if (image != null) {
        File imageFile = File(image.path);

        final compressed = await compressImagePreservingAspectRatio(imageFile);

        setState(() {
          widget.recipe.imageFile = compressed;
        });

        widget.onDataChanged('imageFile', compressed);
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

    try {
      int startTime = DateTime.now().millisecondsSinceEpoch; // Start timing
      setState(() {
        _isLoading = true;
      });

      // Create a FirebaseFunctions instance for the specific region
      final FirebaseFunctions functions =
          FirebaseFunctions.instanceFor(region: 'europe-west1');

      // Call the Cloud Function
      final HttpsCallable callable = functions.httpsCallable('generateImage');
      final result = await callable.call(<String, dynamic>{
        'prompt': prompt,
      });

      int endTime = DateTime.now().millisecondsSinceEpoch; // End timing
      int responseTime = endTime - startTime;

      AnalyticsService.logEvent(
        name: "ai_image_generation_time",
        parameters: {
          "duration_ms": responseTime,
          "prompt": prompt,
        },
      );

      AnalyticsService.logEvent(
        name: "ai_image_generation_prefs",
        parameters: {
          "background": selectedBackground,
          "style": selectedStyle,
          "plating": selectedPlating,
        },
      );

      setState(() {
        _isLoading = false;
      });

      final imageUrl = result.data['url'];

      // Log event in Firebase Analytics

      setState(() {
        widget.recipe.imageUrl = imageUrl;
      });

      widget.onDataChanged('imageUrl', imageUrl);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error generating image: $e');
      if (e != "Invalid argument(s): Unknown key: imageUrl") {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating image: $e')),
        );
      }
    }
  }
}
