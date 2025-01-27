// lib/src/utils/dialog_utils.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:food_fellas/providers/searchProvider.dart';
import 'package:provider/provider.dart';

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

Future<void> toggleRecipeInCollection({
  required String collectionOwnerUid,
  required String collectionId,
  required bool add,
  required String recipeId,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final collectionRef = FirebaseFirestore.instance
      .collection('users')
      .doc(collectionOwnerUid) // <-- owner of the collection
      .collection('collections')
      .doc(collectionId);

  // 1) Fetch the collection to see if the user is allowed to add recipes
  final doc = await collectionRef.get();
  if (!doc.exists) {
    print('Collection does not exist!');
    return;
  }
  final data = doc.data() as Map<String, dynamic>;
  final ownerUid = collectionOwnerUid;
  final contributors = (data['contributors'] ?? []) as List;

  // 2) Check if current user is the owner or a contributor
  final isOwner = (user.uid == ownerUid);
  final isContributor = contributors.contains(user.uid);

  if (!isOwner && !isContributor) {
    // Not allowed
    print('User is neither owner nor contributor. Abort.');
    return;
  }

  // 3) Proceed with add/remove
  if (add) {
    await collectionRef.update({
      'recipes': FieldValue.arrayUnion([recipeId]),
    });
  } else {
    await collectionRef.update({
      'recipes': FieldValue.arrayRemove([recipeId]),
    });
  }
}

Future<void> toggleFollowCollection({
  required String collectionOwnerUid,
  required String collectionId,
  required bool currentlyFollowing, // is the user currently following?
}) async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) return; // not logged in

  final batch = FirebaseFirestore.instance.batch();

  // Collection doc reference
  final ownerCollectionDoc = FirebaseFirestore.instance
      .collection('users')
      .doc(collectionOwnerUid)
      .collection('collections')
      .doc(collectionId);

  // The subcollection doc: who is following
  final followerDoc =
      ownerCollectionDoc.collection('followers').doc(currentUser.uid);

  // In the follower’s user document
  final userFollowedCollectionDoc = FirebaseFirestore.instance
      .collection('users')
      .doc(currentUser.uid)
      .collection('followedCollections')
      .doc(collectionId);

  if (currentlyFollowing) {
    // == UNFOLLOW ==
    batch.delete(followerDoc);
    batch.delete(userFollowedCollectionDoc);
    // Decrement the followersCount
    batch.update(ownerCollectionDoc, {
      'followersCount': FieldValue.increment(-1),
    });
  } else {
    // == FOLLOW ==
    batch.set(followerDoc, {
      'followerUid': currentUser.uid,
      'followedAt': FieldValue.serverTimestamp(),
    });
    batch.set(userFollowedCollectionDoc, {
      'collectionId': collectionId,
      'collectionOwnerUid': collectionOwnerUid,
      'followedAt': FieldValue.serverTimestamp(),
    });
    // Increment the followersCount
    batch.update(ownerCollectionDoc, {
      'followersCount': FieldValue.increment(1),
    });
  }

  await batch.commit();
}

Future<void> rateCollection({
  required String collectionOwnerUid,
  required String collectionId,
  required double rating,
}) async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) return; // Ensure user is logged in

  final collectionRef = FirebaseFirestore.instance
      .collection('users')
      .doc(collectionOwnerUid)
      .collection('collections')
      .doc(collectionId);

  final ratingDocRef = collectionRef.collection('ratings').doc(currentUser.uid);

  await FirebaseFirestore.instance.runTransaction((transaction) async {
    // Fetch all existing ratings
    final allRatingsSnap = await collectionRef.collection('ratings').get();

    // Get the user's current rating, if any
    final existingRatingSnapshot = await transaction.get(ratingDocRef);
    double existingRating = 0;
    if (existingRatingSnapshot.exists) {
      existingRating = (existingRatingSnapshot['rating'] ?? 0).toDouble();
    }

    // Calculate the new average rating
    final allRatings = allRatingsSnap.docs.map((doc) {
      return (doc['rating'] ?? 0.0) as double;
    }).toList();

    // Adjust the ratings list by removing the user's old rating (if any)
    if (existingRating > 0) {
      allRatings.remove(existingRating);
    }

    // Add the new rating
    final newRatings = [...allRatings, rating];
    final newCount = newRatings.length;
    final newAverage = newRatings.reduce((a, b) => a + b) / newCount;

    // Save or update the user's rating
    transaction.set(ratingDocRef, {
      'rating': rating,
      'ratedAt': FieldValue.serverTimestamp(),
    });

    // Update the collection's average rating and rating count
    transaction.update(collectionRef, {
      'averageRating': newAverage,
      'ratingsCount': newCount,
    });

    print(
        "Rating successfully updated: Average = $newAverage, Count = $newCount");
  });
}

Future<void> addContributorToCollection({
  required String ownerUid,
  required String collectionId,
  required String contributorUid,
}) async {
  final collectionRef = FirebaseFirestore.instance
      .collection('users')
      .doc(ownerUid)
      .collection('collections')
      .doc(collectionId);

  await collectionRef.update({
    'contributors': FieldValue.arrayUnion([contributorUid])
  });
}

Future<void> removeContributorFromCollection({
  required String ownerUid,
  required String collectionId,
  required String contributorUid,
}) async {
  final collectionRef = FirebaseFirestore.instance
      .collection('users')
      .doc(ownerUid)
      .collection('collections')
      .doc(collectionId);

  await collectionRef.update({
    'contributors': FieldValue.arrayRemove([contributorUid])
  });
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
            title: const Text('Create new Collection'),
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
                          collectionOwnerUid: user.uid,
                          collectionId: newCollectionId,
                          add: true,
                          recipeId: recipeId,
                        );
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
                child: Text(collectionId == null ? 'Create' : 'Update',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary)),
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

Future<void> showManageContributorsDialog({
  required BuildContext context,
  required String ownerUid,
  required String collectionId,
  required List<String> existingContributors,
}) async {
  final searchProvider = Provider.of<SearchProvider>(context, listen: false);

  String query = '';

  showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setStateDialog) {
          final users = searchProvider.users;

          Future<void> doSearch(String q) async {
            query = q;
            await searchProvider.fetchUsers(q);
            setStateDialog(() {});
          }

          return AlertDialog(
            title: Text('Manage Contributors'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Search users...',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      doSearch(val);
                    },
                  ),
                  SizedBox(height: 8),
                  Expanded(
                    child: searchProvider.isLoading
                        ? Center(child: CircularProgressIndicator())
                        : ListView.builder(
                            itemCount: users.length,
                            itemBuilder: (context, index) {
                              final userData = users[index];
                              final userUid = userData['uid'] ?? '';
                              final displayName =
                                  userData['display_name'] ?? 'User';
                              final profilePicture =
                                  userData['profile_url'] ?? '';
                              final isContributor =
                                  existingContributors.contains(userUid);
                              print('profilePicture: $profilePicture');
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: profilePicture.isNotEmpty
                                      ? NetworkImage(profilePicture)
                                      : null,
                                  child: profilePicture.isEmpty
                                      ? Icon(Icons.person)
                                      : null,
                                ),
                                title: Text(displayName),
                                trailing: isContributor
                                    ? IconButton(
                                        icon: Icon(Icons.remove_circle,
                                            color: Colors.red),
                                        onPressed: () async {
                                          await removeContributorFromCollection(
                                            ownerUid: ownerUid,
                                            collectionId: collectionId,
                                            contributorUid: userUid,
                                          );
                                          existingContributors.remove(userUid);
                                          setStateDialog(() {});
                                        },
                                      )
                                    : IconButton(
                                        icon: Icon(Icons.add_circle,
                                            color: Colors.green),
                                        onPressed: () async {
                                          await addContributorToCollection(
                                            ownerUid: ownerUid,
                                            collectionId: collectionId,
                                            contributorUid: userUid,
                                          );
                                          existingContributors.add(userUid);
                                          setStateDialog(() {});
                                        },
                                      ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: Text('Cancel'),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: Text('Done'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          );
        },
      );
    },
  );
}
