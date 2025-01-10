// lib/src/utils/dialog_utils.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

Future<String> _createCollection(
    String name, String icon, bool isPublic) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return '';

  final collectionRef = FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('collections')
      .doc();

  await collectionRef.set({
    'name': name,
    'icon': icon,
    'isPublic': isPublic,
    'recipes': [],
    'createdAt': FieldValue.serverTimestamp(),
  });

  return collectionRef.id;
}

void toggleRecipeInCollection(
    String collectionId, bool add, String recipeId) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final collectionRef = FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('collections')
      .doc(collectionId);

  if (add) {
    // Add the recipe to the collection
    await collectionRef.update({
      'recipes': FieldValue.arrayUnion([recipeId]),
    });
  } else {
    // Remove the recipe from the collection
    await collectionRef.update({
      'recipes': FieldValue.arrayRemove([recipeId]),
    });
  }
}

Future<void> showCreateCollectionDialog(BuildContext context,
    {bool autoAddRecipe = false,
    String? recipeId,
    String? initialName,
    String? initialIcon,
    bool? initialVisibility,
    String? collectionId}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  String newCollectionName = initialName ?? '';
  ValueNotifier<String> selectedIcon =
      ValueNotifier<String>(initialIcon ?? '🍽');
  bool isPublic = initialVisibility ?? true;
  bool showEmojiPicker = false;

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Create New Collection'),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  // Collection Name
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Collection Name',
                    ),
                    controller: TextEditingController(text: newCollectionName),
                    onChanged: (value) {
                      newCollectionName = value;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Emoji Selection
                  const Text('Select Icon:'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      _showEmojiPicker(context, selectedIcon);
                    },
                    child: ValueListenableBuilder<String>(
                      valueListenable: selectedIcon,
                      builder: (context, value, child) {
                        return Container(
                          width: 80,
                          height: 80,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.grey.shade200,
                          ),
                          child: Text(
                            value,
                            style: const TextStyle(fontSize: 40),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Visibility Selection
                  const Text('Visibility:'),
                  const SizedBox(height: 8),
                  ToggleButtons(
                    isSelected: [isPublic, !isPublic],
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                    selectedBorderColor: Theme.of(context).colorScheme.primary,
                    selectedColor: Theme.of(context).colorScheme.primary,
                    fillColor:
                        Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    color: Theme.of(context).colorScheme.primary,
                    onPressed: (index) {
                      setState(() {
                        isPublic = index == 0;
                      });
                    },
                    children: const [
                      Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
                        child: Column(
                          children: [
                            Icon(Icons.lock_open),
                            Text('Public'),
                          ],
                        ),
                      ),
                      Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
                        child: Column(
                          children: [
                            Icon(Icons.lock),
                            Text('Private'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (newCollectionName.isNotEmpty) {
                    if (collectionId == null) {
                      // Create new collection
                      String newCollectionId = await _createCollection(
                          newCollectionName, selectedIcon.value, isPublic);
                      if (autoAddRecipe && recipeId != null) {
                        toggleRecipeInCollection(
                            newCollectionId, true, recipeId);
                      }
                    } else {
                      // Update existing collection
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .collection('collections')
                          .doc(collectionId)
                          .update({
                        'name': newCollectionName,
                        'icon': selectedIcon.value,
                        'isPublic': isPublic,
                      });
                    }
                    Navigator.pop(context);
                  }
                },
                child: Text(collectionId == null ? 'Create' : 'Update'),
              ),
            ],
          );
        },
      );
    },
  );
}

void _showEmojiPicker(
    BuildContext context, ValueNotifier<String> selectedIcon) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return Container(
        height: 300,
        padding: const EdgeInsets.all(10),
        child: EmojiPicker(
          onEmojiSelected: (category, emoji) {
            selectedIcon.value = emoji.emoji;
            Navigator.pop(context); // Close the picker after selection
          },
          config: Config(
            height: 300, // Adjust the height of the Emoji Picker
            emojiTextStyle: const TextStyle(
                fontSize: 24), // Define text style for better readability
            emojiViewConfig: EmojiViewConfig(
              columns: 8, // More emojis per row for better use of space
              emojiSizeMax: 28, // Control the size of the displayed emojis
              backgroundColor: Colors.white,
              verticalSpacing: 8,
              horizontalSpacing: 8,
              gridPadding: const EdgeInsets.symmetric(horizontal: 10),
              noRecents: const Text(
                'No Recents',
                style: TextStyle(fontSize: 16, color: Colors.black26),
                textAlign: TextAlign.center,
              ),
            ),
            categoryViewConfig: CategoryViewConfig(
              tabBarHeight: 50.0,
              backgroundColor: Colors.grey.shade200,
              indicatorColor: Theme.of(context).colorScheme.primary,
              iconColor: Colors.grey,
              iconColorSelected: Theme.of(context).colorScheme.primary,
              recentTabBehavior: RecentTabBehavior.NONE,
              categoryIcons:
                  const CategoryIcons(), // Use default icons, can be customized if needed
            ),
            bottomActionBarConfig: BottomActionBarConfig(
              showBackspaceButton: true,
              showSearchViewButton: true,
              backgroundColor: Colors.grey.shade200,
              buttonIconColor: Theme.of(context).colorScheme.primary,
            ),
            searchViewConfig: SearchViewConfig(
              backgroundColor: Colors.grey.shade200,
              buttonIconColor: Colors.grey,
              hintText: 'Search Emoji',
              hintTextStyle: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ),
      );
    },
  );
}
