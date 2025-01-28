import 'dart:io';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:food_fellas/src/models/recipe.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'dart:convert';
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
    return Image.asset(
      'lib/assets/images/dinner-placeholder.png', // Local placeholder
      width: double.infinity,
      height: 200,
      fit: BoxFit.cover,
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
      progressIndicatorBuilder: (context, url, downloadProgress) =>
          CircularProgressIndicator(value: downloadProgress.progress),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Or customize the settings to create an image of your dish with AI!',
            style: TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.left,
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

        // Check the file size
        final int imageSizeInBytes = await imageFile.length();
        final double imageSizeInMB = imageSizeInBytes / (1024 * 1024);
        print('Original Image Size: ${imageSizeInMB.toStringAsFixed(2)} MB');

        // Compress the image if it's larger than 2 MB (adjust threshold as needed)
        File compressedImageFile = imageFile;
        if (imageSizeInMB > 2) {
          print('Compressing image...');
          compressedImageFile = await _compressImage(imageFile);
          print('Image compressed successfully.');
        }

        setState(() {
          widget.recipe.imageFile = compressedImageFile;
        });

        widget.onDataChanged('imageFile', compressedImageFile);
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image. Please try again.')),
      );
    }
  }

  Future<File> _compressImage(File imageFile) async {
    // Read the image data
    final Uint8List imageBytes = await imageFile.readAsBytes();
    final img.Image? originalImage = img.decodeImage(imageBytes);

    if (originalImage == null) {
      throw Exception('Failed to decode image');
    }

    // Resize or compress the image
    final int maxWidth = 1080; // Max width (adjust as needed)
    final int maxHeight = 1080; // Max height (adjust as needed)
    final int quality = 85; // Compression quality (1-100)

    final img.Image resizedImage = img.copyResize(
      originalImage,
      width: maxWidth,
      height: maxHeight,
    );

    // Encode the resized/compressed image to JPEG format
    final Uint8List compressedBytes =
        Uint8List.fromList(img.encodeJpg(resizedImage, quality: quality));

    // Save the compressed image back to a temporary file
    final String tempDir = (await getTemporaryDirectory()).path;
    final File compressedImageFile = File('$tempDir/compressed_image.jpg');
    await compressedImageFile.writeAsBytes(compressedBytes);

    return compressedImageFile;
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

      // Create a FirebaseFunctions instance for the specific region
      final FirebaseFunctions functions =
          FirebaseFunctions.instanceFor(region: 'europe-west1');

      // Call the Cloud Function
      final HttpsCallable callable = functions.httpsCallable('generateImage');
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
      if (e != "Invalid argument(s): Unknown key: imageUrl") {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating image: $e')),
        );
      }
    }
  }
}
