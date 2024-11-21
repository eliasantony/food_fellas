// edit_profile_screen.dart

import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:food_fellas/src/views/auth/avatar_builder_screen.dart';
import 'package:image_picker/image_picker.dart';
// Import other necessary packages and your models

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  EditProfileScreen({required this.userData});

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _displayNameController;
  late TextEditingController _shortDescriptionController;
  late TextEditingController _preferredServingsController;

  List<String> selectedDietaryPreferences = [];
  List<String> selectedFavoriteCuisines = [];
  String? selectedCookingSkillLevel;
  Uint8List? _profileImage; // For the profile picture/avatar

  @override
  void initState() {
    super.initState();

    // Initialize controllers with existing user data
    _displayNameController =
        TextEditingController(text: widget.userData['display_name']);
    _shortDescriptionController =
        TextEditingController(text: widget.userData['shortDescription']);
    _preferredServingsController = TextEditingController(
        text: widget.userData['preferredServings']?.toString() ?? '1');

    // Initialize other fields
    selectedDietaryPreferences =
        List<String>.from(widget.userData['dietaryPreferences'] ?? []);
    selectedFavoriteCuisines =
        List<String>.from(widget.userData['favoriteCuisines'] ?? []);
    selectedCookingSkillLevel = widget.userData['cookingSkillLevel'];
    // Load the profile image/avatar
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _shortDescriptionController.dispose();
    _preferredServingsController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    // Show a loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    // Prepare the data to be updated
    Map<String, dynamic> updatedData = {
      'display_name': _displayNameController.text.trim(),
      'shortDescription': _shortDescriptionController.text.trim(),
      'preferredServings':
          int.tryParse(_preferredServingsController.text.trim()) ?? 1,
      'dietaryPreferences': selectedDietaryPreferences,
      'favoriteCuisines': selectedFavoriteCuisines,
      'cookingSkillLevel': selectedCookingSkillLevel,
      // Other fields...
    };

    // If the profile image has changed, upload it to Firebase Storage
    if (_profileImage != null) {
      String uid = widget.userData['uid'];
      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('$uid.jpg');
      UploadTask uploadTask = storageRef.putData(_profileImage!);
      TaskSnapshot snapshot = await uploadTask.whenComplete(() => null);
      String photoUrl = await snapshot.ref.getDownloadURL();
      updatedData['photo_url'] = photoUrl;
    }

    // Update the user document in Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userData['uid'])
        .update(updatedData);

    // Close the loading indicator
    Navigator.of(context).pop();

    // Show a success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Profile updated successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Profile Picture Section
            _buildProfilePictureSection(),
            SizedBox(height: 20),
            // Display Name
            TextField(
              controller: _displayNameController,
              decoration: InputDecoration(labelText: 'Display Name'),
            ),
            SizedBox(height: 20),
            // Short Description
            TextField(
              controller: _shortDescriptionController,
              decoration: InputDecoration(labelText: 'Short Description'),
            ),
            SizedBox(height: 20),
            // Preferred Servings
            TextField(
              controller: _preferredServingsController,
              decoration: InputDecoration(labelText: 'Preferred Servings'),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 20),
            // Dietary Preferences
            _buildDietaryPreferencesSection(),
            SizedBox(height: 20),
            // Favorite Cuisines
            _buildFavoriteCuisinesSection(),
            SizedBox(height: 20),
            // Cooking Skill Level
            _buildCookingSkillLevelSection(),
            SizedBox(height: 20),
            // Save Button
            ElevatedButton(
              onPressed: _saveProfile,
              child: Text(
                'Save Changes',
                style: TextStyle(color: Theme.of(context).canvasColor),
              ),
              style: ButtonStyle(
                  backgroundColor:
                      WidgetStateProperty.all(Theme.of(context).primaryColor)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePictureSection() {
    return Column(
      children: [
        CircleAvatar(
          radius: 60,
          backgroundImage: _profileImage != null
              ? MemoryImage(_profileImage!)
              : NetworkImage(widget.userData['photo_url'] ??
                  'https://via.placeholder.com/150') as ImageProvider,
          backgroundColor: Colors.transparent,
        ),
        SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: Icon(Icons.photo_camera),
              label: Text('Upload Photo'),
              onPressed: _pickProfileImage,
            ),
            SizedBox(width: 10),
            ElevatedButton.icon(
              icon: Icon(Icons.brush),
              label: Text('Create Avatar'),
              onPressed: _createAvatar,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickProfileImage() async {
    // Use image_picker to allow the user to select an image from their gallery or take a new photo
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path).readAsBytesSync();
      });
    }
  }

  Future<void> _createAvatar() async {
    // Navigate to the AvatarBuilderScreen and wait for the result
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AvatarBuilderScreen()),
    );

    if (result != null && result is Uint8List) {
      setState(() {
        _profileImage = result;
      });
    }
  }

  Widget _buildDietaryPreferencesSection() {
    final List<Map<String, String>> preferences = [
      {'label': 'Vegetarian', 'icon': '🥕'},
      {'label': 'Vegan', 'icon': '🌱'},
      {'label': 'Pescatarian', 'icon': '🐟'},
      {'label': 'Low-Carb', 'icon': '🥦'},
      {'label': 'High-Protein', 'icon': '🍗'},
      {'label': 'Low-Fat', 'icon': '🍏'},
      {'label': 'Dairy-Free', 'icon': '🥛'},
      {'label': 'Nut-Free', 'icon': '🥜'},
      {'label': 'Keto', 'icon': '🥩'},
      {'label': 'Paleo', 'icon': '🍖'},
      {'label': 'Gluten-Free', 'icon': '🍞'},
      {'label': 'Halal', 'icon': '🕌'},
      {'label': 'Kosher', 'icon': '✡️'},
      {'label': 'No Preferences', 'icon': '🍽️'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Dietary Preferences',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SizedBox(height: 10),
        Wrap(
          spacing: 10,
          children: preferences.map((pref) {
            final isSelected =
                selectedDietaryPreferences.contains(pref['label']);
            return ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(pref['icon']!),
                  SizedBox(width: 4),
                  Text(pref['label']!),
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    selectedDietaryPreferences.add(pref['label']!);
                  } else {
                    selectedDietaryPreferences.remove(pref['label']!);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFavoriteCuisinesSection() {
    final List<Map<String, String>> cuisines = [
      {'label': 'Italian', 'icon': '🍕'},
      {'label': 'Mexican', 'icon': '🌮'},
      {'label': 'Chinese', 'icon': '🥡'},
      {'label': 'Indian', 'icon': '🍛'},
      {'label': 'Japanese', 'icon': '🍣'},
      {'label': 'Mediterranean', 'icon': '🥙'},
      {'label': 'American', 'icon': '🍔'},
      {'label': 'Thai', 'icon': '🍜'},
      {'label': 'French', 'icon': '🥐'},
      {'label': 'Greek', 'icon': '🥗'},
      {'label': 'Korean', 'icon': '🍱'},
      {'label': 'Vietnamese', 'icon': '🍜'},
      {'label': 'Spanish', 'icon': '🥘'},
      {'label': 'Middle Eastern', 'icon': '🥙'},
      {'label': 'Caribbean', 'icon': '🍹'},
      {'label': 'African', 'icon': '🍛'},
      {'label': 'German', 'icon': '🥨'},
      {'label': 'Brazilian', 'icon': '🍖'},
      {'label': 'Peruvian', 'icon': '🍤'},
      {'label': 'Russian', 'icon': '🍲'},
      {'label': 'Turkish', 'icon': '🍢'},
      {'label': 'Other', 'icon': '🌍'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Favorite Cuisines',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SizedBox(height: 10),
        Wrap(
          spacing: 10,
          children: cuisines.map((cuisine) {
            final isSelected =
                selectedFavoriteCuisines.contains(cuisine['label']);
            return ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(cuisine['icon']!),
                  SizedBox(width: 4),
                  Text(cuisine['label']!),
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    selectedFavoriteCuisines.add(cuisine['label']!);
                  } else {
                    selectedFavoriteCuisines.remove(cuisine['label']!);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCookingSkillLevelSection() {
    final List<Map<String, String>> skillLevels = [
      {
        'label': 'Beginner',
        'description': 'I\'m just starting out',
        'icon': '🥄'
      },
      {
        'label': 'Intermediate',
        'description': 'I\'ve got some experience',
        'icon': '🥘'
      },
      {'label': 'Expert', 'description': 'I\'m a pro chef!', 'icon': '👨🏻‍🍳'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cooking Skill Level',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SizedBox(height: 10),
        ...skillLevels.map((skill) {
          return ListTile(
            leading: Text(skill['icon']!, style: TextStyle(fontSize: 24)),
            title: Text(skill['label']!),
            subtitle: Text(skill['description']!),
            trailing: Radio<String>(
              value: skill['label']!,
              groupValue: selectedCookingSkillLevel,
              onChanged: (String? value) {
                setState(() {
                  selectedCookingSkillLevel = value;
                });
              },
            ),
            onTap: () {
              setState(() {
                selectedCookingSkillLevel = skill['label'];
              });
            },
          );
        }).toList(),
      ],
    );
  }
}
