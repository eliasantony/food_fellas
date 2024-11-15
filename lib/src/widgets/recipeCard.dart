import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_fellas/providers/recipeProvider.dart';
import '../views/recipeDetails_screen.dart';
import '../utils/dialog_utils.dart';
import 'package:provider/provider.dart';

class RecipeCard extends StatefulWidget {
  final String recipeId;
  final bool big;

  const RecipeCard({
    Key? key,
    required this.recipeId,
    this.big = false,
  }) : super(key: key);

  @override
  _RecipeCardState createState() => _RecipeCardState();
}

class _RecipeCardState extends State<RecipeCard> {
  // Removed the isSaved variable and _checkIfSaved() method

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    final recipeProvider = Provider.of<RecipeProvider>(context);
    bool isSaved = recipeProvider.isRecipeSaved(widget.recipeId);

    return FutureBuilder<Map<String, dynamic>?>(
      future: recipeProvider.getRecipeById(widget.recipeId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: widget.big ? 400 : 250,
            child: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return Text('Error loading recipe');
        } else if (!snapshot.hasData || snapshot.data == null) {
          return Text('Recipe not found');
        } else {
          final recipeData = snapshot.data!;
          // Now you have recipeData, you can build the card
          return _buildRecipeCard(context, recipeProvider, recipeData, isSaved);
        }
      },
    );
  }

  Widget _buildRecipeCard(BuildContext context, RecipeProvider recipeProvider,
      Map<String, dynamic> recipeData, bool isSaved) {
    ThemeData theme = Theme.of(context);

    // Extract data from recipeData
    String title = recipeData['title'] ?? 'Unnamed Recipe';
    String description = recipeData['description'] ?? '';
    double rating = recipeData['averageRating']?.toDouble() ?? 0.0;
    int ratingsCount = recipeData['ratingsCount'] ?? 0;
    int totalTime = recipeData['totalTime'] ?? '';
    String thumbnailUrl = recipeData['imageUrl'] ?? '';
    String authorName = recipeData['authorName'] ?? 'Unknown author';

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
                    child: _buildRecipeImage(thumbnailUrl),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // Title with max 2 lines
                        SizedBox(
                          height: 20,
                          child: Text(
                            title,
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'by $authorName',
                          style: theme.textTheme.titleSmall,
                        ),
                        SizedBox(height: 8),
                        // Description with max 2 lines
                        SizedBox(
                          height: 40,
                          child: Text(
                            description,
                            style: theme.textTheme.bodyMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
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
                                  '${rating.toStringAsFixed(1)} ($ratingsCount)',
                                  style: theme.textTheme.titleMedium,
                                ),
                              ],
                            ),
                            Row(
                              children: <Widget>[
                                Icon(
                                  Icons.timer_outlined,
                                  size: 18,
                                  color: theme.colorScheme.onSurface,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '$totalTime min',
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
                backgroundColor: Colors.white.withAlpha(200),
                child: IconButton(
                  icon: isSaved
                      ? Icon(Icons.bookmark, color: Colors.green)
                      : Icon(Icons.bookmark_border, color: Colors.grey),
                  onPressed: () async {
                    // Show save dialog
                    _showSaveDialog();
                    // After saving, you may want to refresh the saved recipes
                    // by calling recipeProvider.refreshSavedRecipes();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeImage(String thumbnailUrl) {
    if (thumbnailUrl.isEmpty) {
      return CachedNetworkImage(
        imageUrl: 'https://via.placeholder.com/400x225',
        progressIndicatorBuilder: (context, url, downloadProgress) =>
            CircularProgressIndicator(value: downloadProgress.progress),
        errorWidget: (context, url, error) => Icon(Icons.error),
        fit: BoxFit.cover,
      );
    } else if (thumbnailUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: thumbnailUrl,
        progressIndicatorBuilder: (context, url, downloadProgress) =>
            CircularProgressIndicator(value: downloadProgress.progress),
        errorWidget: (context, url, error) => Icon(Icons.error),
        fit: BoxFit.cover,
      );
    } else {
      return Image.asset(
        thumbnailUrl,
        fit: BoxFit.cover,
      );
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
                                if (value == true) {
                                  // Add recipe to collection
                                  toggleRecipeInCollection(
                                      collection.id, true, widget.recipeId);
                                } else {
                                  // Remove recipe from collection
                                  toggleRecipeInCollection(
                                      collection.id, false, widget.recipeId);
                                }
                                // After modifying collections, refresh saved recipes
                                final recipeProvider =
                                    Provider.of<RecipeProvider>(context,
                                        listen: false);
                                recipeProvider.refreshSavedRecipes();
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
}
