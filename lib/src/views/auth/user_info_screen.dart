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
                  Navigator.of(context).pop();
                  _pickImage();
                },
              ),
              ListTile(
                leading: Icon(Icons.person),
                title: Text('Create an Avatar'),
                onTap: () {
                  Navigator.of(context).pop();
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
        title: const Text('Tell Us About Yourself'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _showImageSourceDialog,
              child: CircleAvatar(
                radius: 60,
                backgroundImage:
                    _profileImage != null ? MemoryImage(_profileImage!) : null,
                child: _profileImage == null
                    ? Icon(
                        Icons.person,
                        size: 60,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 20),
            // Display Name
            TextField(
              controller: _displayNameController,
              decoration: InputDecoration(
                labelText: 'Display Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Short Description
            TextField(
              controller: _shortDescriptionController,
              decoration: InputDecoration(
                labelText: 'Short Description',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 10),
            Text(
              'For how many people do you usually cook?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextField(
              controller: _preferredServingsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Preferred Servings',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _navigateToNext,
                child: const Text('Next'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
