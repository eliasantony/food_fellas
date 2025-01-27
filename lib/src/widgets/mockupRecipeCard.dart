import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../views/recipeDetails_screen.dart';
import '../utils/dialog_utils.dart'; // Adjust the path as needed

class MockupRecipeCard extends StatefulWidget {
  final String recipeId;
  final String title;
  final String description;
  final double rating;
  final int ratingsCount; // Added this parameter
  final String totalTime;
  final String thumbnailUrl;
  final String author;
  final bool big;

  const MockupRecipeCard({
    Key? key,
    required this.recipeId,
    required this.title,
    required this.description,
    required this.rating,
    required this.ratingsCount, // Added this parameter
    required this.totalTime,
    required this.thumbnailUrl,
    required this.author,
    this.big = false,
  }) : super(key: key);

  @override
  _MockupRecipeCardState createState() => _MockupRecipeCardState();
}

class _MockupRecipeCardState extends State<MockupRecipeCard> {
  bool isSaved = false;

  @override
  void initState() {
    super.initState();
    _checkIfSaved();
  }

  // Check if the recipe is saved in any collection
  void _checkIfSaved() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final collectionsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('collections')
        .get();

    for (var collection in collectionsSnapshot.docs) {
      List<dynamic> recipes = collection['recipes'] ?? [];
      if (recipes.contains(widget.recipeId)) {
        setState(() {
          isSaved = true;
        });
        break;
      }
    }
  }

  // Show the save dialog
  void _showSaveDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You must be logged in to save recipes.')),
      );
      return;
    }

    // Fetch the user's collections
    QuerySnapshot collectionsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('collections')
        .get();

    List<DocumentSnapshot> collections = collectionsSnapshot.docs;

    Map<String, bool> collectionSelection = {};

    // For each collection, check if the recipe is already in it
    for (var collection in collections) {
      List<dynamic> recipes = collection['recipes'] ?? [];
      collectionSelection[collection.id] = recipes.contains(widget.recipeId);
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Save Recipe to Collections'),
              content: Container(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // List of collections
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: collections.length + 1,
                        itemBuilder: (context, index) {
                          if (index == collections.length) {
                            // Create New Collection
                            return ListTile(
                              leading: Icon(Icons.add),
                              title: Text('Create New Collection'),
                              onTap: () {
                                Navigator.pop(context);
                                showCreateCollectionDialog(context,
                                    autoAddRecipe: true,
                                    recipeId: widget.recipeId);
                              },
                            );
                          } else {
                            var collection = collections[index];
                            bool isSelected =
                                collectionSelection[collection.id] ?? false;
                            return CheckboxListTile(
                              value: isSelected,
                              title: Row(
                                children: [
                                  Text(collection['icon'] ?? '🍽',
                                      style: TextStyle(fontSize: 24)),
                                  SizedBox(width: 8),
                                  Text(collection['name'] ?? 'Unnamed'),
                                ],
                              ),
                              onChanged: (bool? value) {
                                setStateDialog(() {
                                  collectionSelection[collection.id] =
                                      value ?? false;
                                });
                                toggleRecipeInCollection(
                                  collectionOwnerUid: user
                                      .uid, // because user is the *owner* of their own collection
                                  collectionId: collection.id,
                                  add: value ?? false,
                                  recipeId: widget.recipeId,
                                );
                                // Update isSaved state
                                setState(() {
                                  isSaved = value ?? false;
                                });
                              },
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);

    return Container(
      width: widget.big ? 400 : 250,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InkWell(
              splashColor: theme.colorScheme.primary.withOpacity(0.1),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        RecipeDetailScreen(recipeId: widget.recipeId),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _buildRecipeImage(),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // Title with max 2 lines
                        Text(
                          widget.title,
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontSize: 16),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          widget.author,
                          style: theme.textTheme.titleSmall,
                        ),
                        SizedBox(height: 8),
                        // Description with max 2 lines
                        Text(
                          widget.description,
                          style: theme.textTheme.bodyMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            // Rating with number of ratings
                            Row(
                              children: <Widget>[
                                Icon(
                                  Icons.star,
                                  color: Colors.yellow.shade800,
                                  size: 24,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '${widget.rating.toStringAsFixed(1)} (${widget.ratingsCount})',
                                  style: theme.textTheme.titleMedium,
                                ),
                              ],
                            ),
                            Row(
                              children: <Widget>[
                                Icon(
                                  Icons.timer,
                                  size: 18,
                                  color: theme.colorScheme.onSurface,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  widget.totalTime,
                                  style: theme.textTheme.titleMedium,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Bookmark button
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor:
                    Colors.white.withAlpha(200), // Slight transparency
                child: IconButton(
                  icon: isSaved
                      ? Icon(Icons.bookmark, color: Colors.blue)
                      : Icon(Icons.bookmark_border, color: Colors.grey),
                  onPressed: _showSaveDialog,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeImage() {
    if (widget.thumbnailUrl == null || widget.thumbnailUrl.isEmpty) {
      return CachedNetworkImage(
        imageUrl: 'https://via.placeholder.com/400x225',
        fit: BoxFit.cover,
      );
    } else if (widget.thumbnailUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: widget.thumbnailUrl,
        fit: BoxFit.cover,
      );
    } else {
      return Image.asset(
        widget.thumbnailUrl,
        fit: BoxFit.cover,
      );
    }
  }
}
