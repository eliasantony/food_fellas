// lib/src/utils/dialog_utils.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:food_fellas/providers/recipeProvider.dart';
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
  required bool currentlyFollowing,
}) async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) return;
  debugPrint('currentUser.uid: ${currentUser.uid}');
  debugPrint('collectionOwnerUid: $collectionOwnerUid');
  debugPrint('collectionId: $collectionId');
  debugPrint('currentlyFollowing: $currentlyFollowing');

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
    debugPrint('Unfollowing collection');
    // UNFOLLOW: delete docs and decrement followersCount
    batch.delete(followerDoc);
    batch.delete(userFollowedCollectionDoc);
    batch.update(ownerCollectionDoc, {
      'followersCount': FieldValue.increment(-1),
    });
  } else {
    debugPrint('Following collection');
    // FOLLOW: add docs and increment followersCount
    batch.set(followerDoc, {
      'followerUid': currentUser.uid,
      'followedAt': FieldValue.serverTimestamp(),
    });
    batch.set(userFollowedCollectionDoc, {
      'collectionId': collectionId,
      'collectionOwnerUid': collectionOwnerUid,
      'followedAt': FieldValue.serverTimestamp(),
    });
    batch.update(ownerCollectionDoc, {
      'followersCount': FieldValue.increment(1),
    });
    debugPrint('Batch commit...');
  }

  try {
    await batch.commit();
    debugPrint('Batch commit successful');
  } catch (e) {
    debugPrint('Error during batch commit: $e');
    // Rethrow or handle the error as needed.
    throw e;
  }
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
  required BuildContext context,
  required String ownerUid,
  required String collectionId,
  required String contributorUid,
  required String contributorName,
}) async {
  if (contributorUid.isEmpty) {
    print('Cannot add contributor: UID is empty.');
    return;
  }

  final collectionRef = FirebaseFirestore.instance
      .collection('users')
      .doc(ownerUid)
      .collection('collections')
      .doc(collectionId);

  // 1) Update the owner's doc
  await collectionRef.update({
    'contributors': FieldValue.arrayUnion([contributorUid])
  });

  // 2) (New) Also create a doc in the contributor’s sharedCollections subcoll
  final contributorSharedDocRef = FirebaseFirestore.instance
      .collection('users')
      .doc(contributorUid)
      .collection('sharedCollections')
      .doc(collectionId);

  // optionally fetch the collection name/icon to store them
  final collectionSnap = await collectionRef.get();
  final data = collectionSnap.data() ?? {};
  final name = data['name'] ?? 'Unnamed';
  final icon = data['icon'] ?? '🍽';

  await contributorSharedDocRef.set({
    'collectionOwnerUid': ownerUid,
    'collectionId': collectionId,
    'name': name,
    'icon': icon,
    'addedAt': FieldValue.serverTimestamp(),
  });

  // Show Snackbar
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Added $contributorName as contributor!'),
      duration: const Duration(seconds: 2),
    ),
  );
}

Future<void> removeContributorFromCollection({
  required BuildContext context,
  required String ownerUid,
  required String collectionId,
  required String contributorUid,
  required String contributorName,
}) async {
  if (contributorUid.isEmpty) {
    print('Cannot remove contributor: UID is empty.');
    return;
  }

  final collectionRef = FirebaseFirestore.instance
      .collection('users')
      .doc(ownerUid)
      .collection('collections')
      .doc(collectionId);

  // 1) Remove from the owners doc
  await collectionRef.update({
    'contributors': FieldValue.arrayRemove([contributorUid])
  });

  // 2) Also delete from the contributor’s subcollection
  final contributorSharedDocRef = FirebaseFirestore.instance
      .collection('users')
      .doc(contributorUid)
      .collection('sharedCollections')
      .doc(collectionId);

  await contributorSharedDocRef.delete();

  // Show Snackbar
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Removed $contributorName as contributor!'),
      duration: const Duration(seconds: 2),
    ),
  );
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

// Inside showManageContributorsDialog

Future<void> showManageContributorsDialog({
  required BuildContext context,
  required String ownerUid,
  required String collectionId,
  required List<String> existingContributors,
}) async {
  final searchProvider = Provider.of<SearchProvider>(context, listen: false);

  // Create a local copy of existingContributors to avoid modifying the original list directly
  List<String> localContributors = List.from(existingContributors);

  // Fetch contributor data asynchronously and store in a list
  List<Map<String, dynamic>> contributorsData = [];
  for (String uid in localContributors) {
    if (uid.isNotEmpty) {
      // Prevent fetching with empty uid
      final data = await searchProvider.fetchUserByUid(uid);
      if (data != null) {
        contributorsData.add(data);
      }
    }
  }

  // Fetch initial list of users, excluding existing contributors
  await searchProvider.fetchUsers('', excludeUids: localContributors);

  showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setStateDialog) {
          final users = searchProvider.users;
          final query = searchProvider.query;

          Future<void> doSearch(String q) async {
            if (q.isEmpty) {
              await searchProvider.fetchUsers('',
                  excludeUids: localContributors);
            } else {
              await searchProvider.fetchUsers(q,
                  excludeUids: localContributors);
            }
            setStateDialog(() {});
          }

          return AlertDialog(
            title: Text('Manage Contributors'),
            content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Search Field
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
                    // Contributors and Users List
                    Expanded(
                      child: searchProvider.isLoading
                          ? Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              itemCount: query.isEmpty
                                  ? contributorsData.length + users.length
                                  : users.length,
                              itemBuilder: (context, index) {
                                if (query.isEmpty) {
                                  if (index < contributorsData.length) {
                                    // Display existing contributors at the top
                                    final contributorData =
                                        contributorsData[index];
                                    final displayName =
                                        contributorData['display_name'] ??
                                            'User';
                                    final profilePicture =
                                        contributorData['photo_url'] ?? '';
                                    final contributorUid =
                                        contributorData['uid'] ?? '';

                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundImage:
                                            profilePicture.isNotEmpty
                                                ? NetworkImage(profilePicture)
                                                : null,
                                        backgroundColor: Colors.transparent,
                                        child: profilePicture.isEmpty
                                            ? Icon(Icons.person)
                                            : null,
                                      ),
                                      title: Text(displayName),
                                      trailing: IconButton(
                                        icon: Icon(Icons.remove_circle,
                                            color: Colors.red),
                                        onPressed: () async {
                                          await removeContributorFromCollection(
                                            context: context,
                                            ownerUid: ownerUid,
                                            collectionId: collectionId,
                                            contributorUid: contributorUid,
                                            contributorName: displayName,
                                          );
                                          // Remove from local lists
                                          int removeIndex = localContributors
                                              .indexOf(contributorUid);
                                          if (removeIndex != -1) {
                                            localContributors
                                                .removeAt(removeIndex);
                                            contributorsData
                                                .removeAt(removeIndex);
                                            users.add(contributorData);
                                          }
                                          setStateDialog(() {});
                                        },
                                      ),
                                    );
                                  } else {
                                    // Display other users
                                    final userIndex =
                                        index - contributorsData.length;
                                    final userData = users[userIndex];
                                    final userUid = userData['uid'] ?? '';
                                    final displayName =
                                        userData['display_name'] ?? 'User';
                                    final profilePicture =
                                        userData['photo_url'] ?? '';
                                    final isContributor =
                                        localContributors.contains(userUid);

                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundImage:
                                            profilePicture.isNotEmpty
                                                ? NetworkImage(profilePicture)
                                                : null,
                                        backgroundColor: Colors.transparent,
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
                                                  context: context,
                                                  ownerUid: ownerUid,
                                                  collectionId: collectionId,
                                                  contributorUid: userUid,
                                                  contributorName: displayName,
                                                );
                                                // Remove from local lists
                                                int removeIndex =
                                                    localContributors
                                                        .indexOf(userUid);
                                                if (removeIndex != -1) {
                                                  localContributors
                                                      .removeAt(removeIndex);
                                                  contributorsData
                                                      .removeAt(removeIndex);
                                                  users.add(userData);
                                                }
                                                setStateDialog(() {});
                                              },
                                            )
                                          : IconButton(
                                              icon: Icon(Icons.add_circle,
                                                  color: Colors.green),
                                              onPressed: () async {
                                                await addContributorToCollection(
                                                  context: context,
                                                  ownerUid: ownerUid,
                                                  collectionId: collectionId,
                                                  contributorUid: userUid,
                                                  contributorName: displayName,
                                                );
                                                // Add to local lists and remove from users list
                                                localContributors.add(userUid);
                                                contributorsData.add(userData);
                                                users.removeAt(userIndex);
                                                setStateDialog(() {});
                                              },
                                            ),
                                    );
                                  }
                                } else {
                                  // When query is not empty, display search results (excluding contributors)
                                  final userData = users[index];
                                  final userUid = userData['uid'] ?? '';
                                  final displayName =
                                      userData['display_name'] ?? 'User';
                                  final profilePicture =
                                      userData['photo_url'] ?? '';
                                  final isContributor =
                                      localContributors.contains(userUid);

                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundImage: profilePicture.isNotEmpty
                                          ? NetworkImage(profilePicture)
                                          : null,
                                      backgroundColor: Colors.transparent,
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
                                                context: context,
                                                ownerUid: ownerUid,
                                                collectionId: collectionId,
                                                contributorUid: userUid,
                                                contributorName: displayName,
                                              );
                                              // Remove from local lists
                                              int removeIndex =
                                                  localContributors
                                                      .indexOf(userUid);
                                              if (removeIndex != -1) {
                                                localContributors
                                                    .removeAt(removeIndex);
                                                contributorsData
                                                    .removeAt(removeIndex);
                                                users.add(userData);
                                              }
                                              setStateDialog(() {});
                                            },
                                          )
                                        : IconButton(
                                            icon: Icon(Icons.add_circle,
                                                color: Colors.green),
                                            onPressed: () async {
                                              await addContributorToCollection(
                                                context: context,
                                                ownerUid: ownerUid,
                                                collectionId: collectionId,
                                                contributorUid: userUid,
                                                contributorName: displayName,
                                              );
                                              // Add to local lists and remove from users list
                                              localContributors.add(userUid);
                                              contributorsData.add(userData);
                                              users.removeAt(index);
                                              setStateDialog(() {});
                                            },
                                          ),
                                  );
                                }
                              },
                            ),
                    ),
                  ],
                )),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close the dialog
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
                child: Text('Done',
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

/// Call this from anywhere (RecipeCard or RecipeDetailScreen):
Future<void> showSaveRecipeDialog(
  BuildContext context, {
  required String recipeId,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('You must be logged in to save recipes.')),
    );
    return;
  }

  // 1) Fetch Owned Collections
  List<QueryDocumentSnapshot> ownedDocs = [];
  try {
    final ownedSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('collections')
        .get();
    ownedDocs = ownedSnap.docs;
  } catch (e) {
    debugPrint('Error fetching owned collections: $e');
  }

  // 2) Fetch Shared Collections
  //    i.e. /users/{currentUser}/sharedCollections/
  //    Each doc should contain e.g. {"collectionOwnerUid":..., "collectionId":..., "name":..., "icon":..., ...}
  List<Map<String, dynamic>> sharedList = [];
  try {
    final sharedSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('sharedCollections')
        .get();

    // Option A: If you only store a "reference" or minimal fields, you might
    //           need to fetch the real doc to see its "recipes" array.
    for (var sharedDoc in sharedSnap.docs) {
      final data = sharedDoc.data();
      final ownerUid = data['collectionOwnerUid'];
      final colId = data['collectionId'];

      // fetch the actual doc to see 'recipes', 'contributors', etc.
      final colRef = FirebaseFirestore.instance
          .collection('users')
          .doc(ownerUid)
          .collection('collections')
          .doc(colId);

      final colSnap = await colRef.get();
      if (colSnap.exists) {
        final colData = colSnap.data()!;
        sharedList.add({
          'ref': colRef, // we can store the reference
          'id': colSnap.id,
          'ownerUid': ownerUid,
          ...colData,
        });
      }
    }

    // Option B (alternative):
    // If you stored the entire doc data in sharedCollections,
    // you wouldn't need to fetch colSnap again.
    // In that case, just add the sharedDoc data to the list.
  } catch (e) {
    debugPrint('Error fetching sharedCollections: $e');
  }

  // 3) Combine Owned + Shared
  // We'll unify them into a single List<Map<String,dynamic>> for the dialog
  // For "ownedDocs", we can convert them similarly:
  List<Map<String, dynamic>> ownedList = [];
  for (var doc in ownedDocs) {
    final docData = doc.data() as Map<String, dynamic>;
    ownedList.add({
      'ref': doc.reference,
      'id': doc.id,
      'ownerUid': user.uid,
      ...docData,
    });
  }

  // Put them together
  List<Map<String, dynamic>> allCollections = [
    ...ownedList,
    ...sharedList,
  ];

  // 4) Check whether the recipe is already in each collection
  Map<String, bool> collectionSelection = {};
  for (var c in allCollections) {
    final recipes = (c['recipes'] as List?) ?? [];
    collectionSelection[c['id']] = recipes.contains(recipeId);
  }

  final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);

  // 5) Show the AlertDialog
  await showDialog(
    context: context,
    builder: (dialogCtx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Save Recipe to Collections'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount:
                          allCollections.length + 1, // +1 for "Create New"
                      itemBuilder: (ctx, index) {
                        if (index == allCollections.length) {
                          // "Create new collection" tile
                          return ListTile(
                            leading: const Icon(Icons.add),
                            title: const Text('Create New Collection'),
                            onTap: () {
                              Navigator.pop(ctx);
                              showCreateCollectionDialog(context,
                                  autoAddRecipe: true, recipeId: recipeId);
                            },
                          );
                        }

                        final c = allCollections[index];
                        final colId = c['id'];
                        final icon = c['icon'] ?? '🍽';
                        final name = c['name'] ?? 'Unnamed';
                        final isOwned = (c['ownerUid'] == user.uid);
                        final isSelected = collectionSelection[colId] ?? false;

                        return CheckboxListTile(
                          value: isSelected,
                          title: Row(
                            children: [
                              Text(icon, style: const TextStyle(fontSize: 24)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(isOwned ? 'Owned' : 'Contributor'),
                          onChanged: (bool? value) async {
                            final add = (value ?? false);

                            setState(() {
                              collectionSelection[colId] = add;
                            });

                            // Figure out the real ownerUid
                            final ownerUid = c['ownerUid'] as String;

                            // Call your toggleRecipeInCollection
                            await toggleRecipeInCollection(
                              collectionOwnerUid: ownerUid,
                              collectionId: colId,
                              add: add,
                              recipeId: recipeId,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.pop(ctx),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                ),
                onPressed: () =>
                    {recipeProvider.refreshSavedRecipes(), Navigator.pop(ctx)},
                child:
                    const Text('Done', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      );
    },
  );
}
