import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:food_fellas/providers/userProvider.dart';
import 'package:food_fellas/src/models/aiPhotoRecognitionModel_config.dart';
import 'package:food_fellas/src/models/recipe.dart';
import 'package:food_fellas/src/services/analytics_service.dart';
import 'package:food_fellas/src/services/imageCompression.dart';
import 'package:food_fellas/src/views/addRecipeForm/addRecipe_form.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:food_fellas/src/views/subscriptionScreen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class ImageToRecipeScreen extends StatefulWidget {
  @override
  _ImageToRecipeScreenState createState() => _ImageToRecipeScreenState();
}

class _ImageToRecipeScreenState extends State<ImageToRecipeScreen> {
  File? _selectedImage;
  String _description = '';
  bool _isLoading = false;
  late stt.SpeechToText _speech;
  bool _isListening = false;
  Timer? _hintTimer;
  late TextEditingController _descriptionController;

  final List<String> _loadingHints = [
    "This may take a moment...",
    "Remember, this is AI-generated and might have some inaccuracies.",
    "Hang tight! We're analyzing your delicious dish."
  ];

  String _currentHint = '';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _descriptionController = TextEditingController();
    _currentHint = _loadingHints[0];
    _startHintLoop();
  }

  void _startHintLoop() {
    int hintIndex = 0;
    _hintTimer = Timer.periodic(Duration(seconds: 3), (Timer timer) {
      if (mounted) {
        setState(() {
          hintIndex = (hintIndex + 1) % _loadingHints.length;
          _currentHint = _loadingHints[hintIndex];
        });
      }
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _speech.stop();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: ShaderMask(
          shaderCallback: (bounds) {
            if (Theme.of(context).brightness == Brightness.dark) {
              return LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ).createShader(bounds);
            } else {
              return LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ).createShader(bounds);
            }
          },
          child: Text(
            "Image to Recipe AI",
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Stack(
        children: [
          // Content
          SingleChildScrollView(
            child: Column(
              children: [
                GestureDetector(
                  onTap: () {
                    if (_selectedImage != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Scaffold(
                            appBar: AppBar(),
                            body: Center(
                              child: PhotoView(
                                imageProvider: FileImage(_selectedImage!),
                                minScale: PhotoViewComputedScale.contained,
                                maxScale: PhotoViewComputedScale.covered * 2,
                              ),
                            ),
                          ),
                        ),
                      );
                    } else {
                      _pickImage();
                    }
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20.0),
                      bottomRight: Radius.circular(20.0),
                    ),
                    child: _selectedImage == null
                        ? Image.asset(
                            'lib/assets/images/dinner-placeholder.png',
                            height: 250,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          )
                        : Image.file(
                            _selectedImage!,
                            height: 250,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                  icon: Icon(Icons.upload,
                      color: Theme.of(context).colorScheme.onPrimary),
                  label: Text('Upload Photo',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary)),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _descriptionController,
                          onChanged: (value) {
                            setState(() {
                              _description = value;
                            });
                          },
                          decoration: InputDecoration(
                            labelText: 'Description',
                            hintText:
                                'Enter a short description of the dish...',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                          textInputAction: TextInputAction.done,
                          onEditingComplete: () {
                            FocusScope.of(context).unfocus();
                          },
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: _isListening
                              ? Colors.red
                              : (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : Colors.black),
                        ),
                        onPressed: _listen,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 80),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'This will submit the image and description to the AI to try to figure out your recipe.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _canSubmit() ? _startProcessing : null,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                  icon: Icon(Icons.auto_awesome,
                      color: Theme.of(context).colorScheme.onPrimary),
                  label: Text('Identify Recipe',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary)),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
          // Loading Overlay
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  bool _canSubmit() {
    return _description.isNotEmpty && _selectedImage != null;
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          setState(() {
            _isListening = val == "listening";
          });
          print('Speech status: $val');
        },
        onError: (val) {
          print('Speech error: $val');
        },
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _descriptionController.text =
                val.recognizedWords; // Update with the latest result only
            print('Recognized words: ${val.recognizedWords}');
          }),
          listenFor: Duration(minutes: 1),
          pauseFor: Duration(seconds: 10),
          localeId: 'en_US',
          listenOptions: stt.SpeechListenOptions(
            partialResults: true,
            enableHapticFeedback: true,
            // Enable partial results
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Speech recognition is not available')),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Widget _buildLoadingOverlay() {
    return Stack(
      children: [
        // Blur Background
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            color: Colors.black.withOpacity(0.5),
          ),
        ),
        // Loading Animation and Hint
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset('lib/assets/lottie/loadingAnim.json'),
              SizedBox(height: 20),
              AnimatedSwitcher(
                duration: Duration(seconds: 3),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Center(
                    child: Align(
                      alignment: Alignment.center,
                      child: Text(
                        _currentHint,
                        key: ValueKey<String>(_currentHint),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

/*   void _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Cropper',
            toolbarColor: Colors.green,
            toolbarWidgetColor: Colors.white,
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio3x2,
              CropAspectRatioPreset.ratio4x3,
            ],
          ),
          IOSUiSettings(
            title: 'Cropper',
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio3x2,
              CropAspectRatioPreset.ratio4x3,
            ],
          ),
          WebUiSettings(
            context: context,
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() {
          _selectedImage = File(croppedFile.path);
        });
      }
    }
  } */

  Future<File> compressImage(File file) async {
    final tempDir = await getTemporaryDirectory();
    final targetPath =
        '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

    final compressedBytes = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      minWidth: 800, // resize to max 800px wide
      minHeight: 800, // resize to max 800px high
      quality: 80, // JPEG quality (0-100)
      format: CompressFormat.jpeg,
    );

    final compressedFile = File(targetPath)..writeAsBytesSync(compressedBytes!);

    return compressedFile;
  }

  void _pickImage() async {
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text('Take a photo'),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image =
                      await picker.pickImage(source: ImageSource.camera);
                  _processPickedImage(image);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Choose from gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image =
                      await picker.pickImage(source: ImageSource.gallery);
                  _processPickedImage(image);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _processPickedImage(XFile? image) async {
    if (image != null) {
      final File original = File(image.path);
      final File compressed =
          await compressImagePreservingAspectRatio(original);

      setState(() {
        _selectedImage = compressed;
      });
    }
  }

  Future<bool> canUseImageToRecipe(String userId) async {
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final lastUsedTimestamp =
        userDoc.data()?['lastImageToRecipeDate'] as Timestamp?;

    // Allow one per week
    if (lastUsedTimestamp != null) {
      DateTime lastUsed = lastUsedTimestamp.toDate();
      DateTime now = DateTime.now();

      // Get the first day of the current week (Monday)
      DateTime startOfCurrentWeek =
          DateTime(now.year, now.month, now.day - (now.weekday - 1));

      // Get the first day of the last week (Monday)
      DateTime startOfLastWeek = startOfCurrentWeek.subtract(Duration(days: 7));

      // Check if the last used date is within the current week (Monday to Sunday)
      if (lastUsed.isAfter(startOfCurrentWeek.subtract(Duration(days: 1)))) {
        return false;
      }
    }
    return true;
  }

  void _startProcessing() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final isSubscribed = Provider.of<UserDataProvider>(context, listen: false)
            .userData?['subscribed'] ??
        false;

    bool canUse = await canUseImageToRecipe(userId);
    if (!isSubscribed && !canUse) {
      // Prompt to upgrade
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Upgrade to Premium? ✨"),
          content: Text(
            "Free users can only use Image-to-Recipe once per week. Upgrade to Premium for unlimited access.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Not Now"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Navigate to your subscription screen or initiate purchase flow.
                // For example:
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => SubscriptionScreen()));
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary),
              child: Text("Upgrade"),
            ),
          ],
        ),
      );
      return;
    }

    // If allowed, proceed and then update last used date in Firestore:
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'lastImageToRecipeDate': Timestamp.now(),
    });
    setState(() {
      _isLoading = true;
    });

    // Display changing hints during processing
    for (int i = 0; i < _loadingHints.length; i++) {
      await Future.delayed(Duration(seconds: 2), () {
        setState(() {
          _currentHint = _loadingHints[i];
        });
      });
    }

    // Send the data to the AI for processing
    await _sendPhotoAndDescription(_selectedImage!, _description);

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _sendPhotoAndDescription(File image, String description) async {
    try {
      // Upload the image to Firebase Storage
      String imageUrl = await _uploadImageToFirestore(image);

      // Get the AI model for identifying the recipe
      final model = getRecipeFromPhotoModel();
      // final chat = model?.startChat();

      final _imageBytes = await image.readAsBytes();
      // Prepare the prompt with the description and image URL
      final prompt = TextPart(description);
      final imagePart = InlineDataPart('image/jpeg', _imageBytes);

      // --- Start API call timing ---
      final apiStart = DateTime.now();
      print('Calling API at $apiStart');
      final response = await model?.generateContent([
        Content.multi([prompt, imagePart])
      ]);
      final apiDuration = DateTime.now().difference(apiStart);
      print('API call finished at ${DateTime.now()}');
      print('API call duration: $apiDuration');
      AnalyticsService.logEvent(
        name: "image_to_recipe_api_response_time",
        parameters: {"duration_ms": apiDuration.inMilliseconds},
      );
      // --- End API call timing ---
      final responseText = response?.text ?? '';
      // Extract the JSON recipe from the AI response
      final recipeJson = extractJsonRecipe(responseText);

      if (recipeJson != null) {
        // Add the image URL to the recipe JSON object
        recipeJson['imageUrl'] = imageUrl;

        // Navigate to addRecipe form
        await _navigateToAddRecipeForm(context, recipeJson);
      } else {
        // Show error if recipe extraction failed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: Could not extract recipe information')),
        );
      }
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<String> _uploadImageToFirestore(File image) async {
    try {
      // Create a unique filename for the image
      String fileName = 'recipes/${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Upload the file to Firebase Storage
      final ref = FirebaseStorage.instance.ref().child(fileName);
      await ref.putFile(image);

      // Get the download URL
      String downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Error uploading image: $e');
    }
  }

  Future<void> _checkAndAddIngredients(Recipe recipe) async {
    final ingredientsCollection =
        FirebaseFirestore.instance.collection('ingredients');

    for (var recipeIngredient in recipe.ingredients) {
      String ingredientName = recipeIngredient.ingredient.ingredientName;

      // Check if ingredient exists
      QuerySnapshot snapshot = await ingredientsCollection
          .where('ingredientName', isEqualTo: ingredientName)
          .get();

      if (snapshot.docs.isEmpty) {
        // Ingredient doesn't exist, add it with approved: false
        await ingredientsCollection.add({
          'ingredientName': ingredientName,
          'category': recipeIngredient.ingredient.category,
          'approved': false,
        });
      }
    }
  }

  Future<void> _navigateToAddRecipeForm(
      BuildContext context, Map<String, dynamic>? recipeJson) async {
    if (recipeJson != null) {
      // Log that the image-to-recipe process is being continued
      AnalyticsService.logEvent(name: "image_to_recipe_started");
      Recipe recipe = Recipe.fromJson(recipeJson);
      recipe.createdByAI = true; // Set the AI-created flag
      recipe.source = "image_to_recipe";

      // Check and add missing ingredients
      await _checkAndAddIngredients(recipe);

      // Pop the current screen
      Navigator.pop(context);
      // Navigate to AddRecipeForm with the pre-filled recipe data
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddRecipeForm(
            initialRecipe: recipe,
          ),
        ),
      );
    }
  }

  Map<String, dynamic>? extractJsonRecipe(String text) {
    try {
      // Regular expression to find JSON code blocks
      final codeBlockRegExp =
          RegExp(r'```json\s*(\{[\s\S]*?\})\s*```', multiLine: true);
      final match = codeBlockRegExp.firstMatch(text);
      if (match != null) {
        String? jsonString = match.group(1);
        if (jsonString != null) {
          // Preprocess the JSON string to replace fractions with decimal equivalents
          jsonString = jsonString.replaceAllMapped(
            RegExp(r'(\d+)/(\d+)'),
            (match) {
              final numerator = int.parse(match.group(1)!);
              final denominator = int.parse(match.group(2)!);
              return (numerator / denominator).toString();
            },
          );

          final Map<String, dynamic> decoded = json.decode(jsonString);
          if (decoded.containsKey('title') &&
              decoded.containsKey('description') &&
              decoded.containsKey('ingredients') &&
              decoded.containsKey('cookingSteps')) {
            return decoded;
          }
        }
      }
    } catch (e) {
      print('Error parsing JSON: $e');
      // Ignore parsing errors, just return null
    }
    return null;
  }
}
