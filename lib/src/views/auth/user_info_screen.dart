import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/user_data.dart';
import 'dietary_preferences_screen.dart';
import 'avatar_builder_screen.dart';

class UserInfoScreen extends StatefulWidget {
  const UserInfoScreen({Key? key}) : super(key: key);

  @override
  _UserInfoScreenState createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends State<UserInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _shortDescriptionController = TextEditingController();
  final _preferredServingsController = TextEditingController();
  Uint8List? _profileImage;
  String? _profileImageError;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      Uint8List imageBytes = await pickedFile.readAsBytes();
      setState(() {
        _profileImage = imageBytes;
        _profileImageError = null; // Clear the error when an image is selected
      });
    }
  }

  void _navigateToNext() {
    if (_profileImage == null) {
      setState(() {
        _profileImageError = "Profile image is required!";
      });
    }

    if (_formKey.currentState!.validate() && _profileImage != null) {
      UserData userData = UserData();
      userData.displayName = _displayNameController.text.trim();
      userData.shortDescription = _shortDescriptionController.text.trim();
      userData.preferredServings =
          int.tryParse(_preferredServingsController.text);
      userData.profileImage = _profileImage;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DietaryPreferencesScreen(userData: userData),
        ),
      );
    }
  }

  void _navigateToAvatarBuilder() async {
    final Uint8List? avatarImage = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AvatarBuilderScreen(),
      ),
    );

    if (avatarImage != null) {
      setState(() {
        _profileImage = avatarImage;
        _profileImageError = null; // Clear the error
      });
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _shortDescriptionController.dispose();
    _preferredServingsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile Infos')),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _pickImage,
                            child: CircleAvatar(
                              radius: 70,
                              backgroundImage: _profileImage != null
                                  ? MemoryImage(_profileImage!)
                                  : null,
                              backgroundColor: Colors.transparent,
                              child: _profileImage == null
                                  ? Icon(Icons.person,
                                      size: 60,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant)
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Tap to Upload Photo',
                            style: const TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500),
                          ),
                          if (_profileImageError !=
                              null) // Show error if image is not selected
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                _profileImageError!,
                                style:
                                    TextStyle(color: Colors.red, fontSize: 14),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _displayNameController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.person_outline),
                        labelText: 'Display Name',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      maxLength: 50,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Display Name is required!";
                        }
                        if (value.trim().length > 50) {
                          return "Display Name must be under 50 characters!";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _shortDescriptionController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.text_snippet_outlined),
                        labelText: 'Short Description',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      maxLines: 3,
                      maxLength: 300,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Short Description is required!";
                        }
                        if (value.trim().length > 300) {
                          return "Short Description must be under 300 characters!";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _preferredServingsController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.people_outline),
                        labelText: 'Preferred Servings',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Preferred Servings is required!";
                        }
                        int? servings = int.tryParse(value);
                        if (servings == null ||
                            servings <= 0 ||
                            servings >= 10) {
                          return "Preferred Servings must be a number between 1 and 9!";
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            // The Next Button at the Bottom
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 32.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _navigateToNext,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Next',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward,
                          color: Theme.of(context).colorScheme.onPrimary),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
