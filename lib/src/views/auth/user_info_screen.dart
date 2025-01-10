import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/user_data.dart';
import 'dietary_preferences_screen.dart';
import 'package:screenshot/screenshot.dart';
import 'avatar_builder_screen.dart';

class UserInfoScreen extends StatefulWidget {
  const UserInfoScreen({Key? key}) : super(key: key);

  @override
  _UserInfoScreenState createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends State<UserInfoScreen> {
  final _displayNameController = TextEditingController();
  final _shortDescriptionController = TextEditingController();
  final _preferredServingsController = TextEditingController();
  Uint8List? _profileImage;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      Uint8List imageBytes = await pickedFile.readAsBytes();
      setState(() {
        _profileImage = imageBytes;
      });
    }
  }

  void _navigateToNext() {
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

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Upload a Picture'),
                onTap: () {
                  _pickImage();
                },
              ),
              ListTile(
                leading: Icon(Icons.person),
                title: Text('Create an Avatar'),
                onTap: () {
                  _navigateToAvatarBuilder();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Infos'),
      ),
      body: Column(
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
                          onTap: _showImageSourceDialog,
                          child: CircleAvatar(
                            radius: 70,
                            backgroundImage: _profileImage != null
                                ? MemoryImage(_profileImage!)
                                : null,
                            backgroundColor: Colors.transparent,
                            child: _profileImage == null
                                ? Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Tap to Upload Photo',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _pickImage(),
                        icon: const Icon(Icons.add_a_photo),
                        label: const Text('Upload Photo'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _navigateToAvatarBuilder(),
                        icon: const Icon(Icons.person),
                        label: const Text('Create Avatar'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'Tell us about yourself',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  TextField(
                    controller: _displayNameController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.person_outline),
                      labelText: 'Display Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _shortDescriptionController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.text_snippet_outlined),
                      labelText: 'Short Description',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'For how many people do you usually cook?',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _preferredServingsController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.people_outline),
                      labelText: 'Preferred Servings',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
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
                    horizontal: 30,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Next',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
