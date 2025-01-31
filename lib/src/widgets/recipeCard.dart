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
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);

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
          return _buildRecipeCard(context, recipeProvider, recipeData);
        }
      },
    );
  }

  Widget _buildRecipeCard(BuildContext context, RecipeProvider recipeProvider,
      Map<String, dynamic> recipeData) {
    ThemeData theme = Theme.of(context);

    // Extract data from recipeData
    String title = recipeData['title'] ?? 'Unnamed Recipe';
    String description = recipeData['description'] ?? '';
    double rating = recipeData['averageRating']?.toDouble() ?? 0.0;
    int ratingsCount = recipeData['ratingsCount'] ?? 0;
    int totalTime = recipeData['totalTime'] ?? 0; // Corrected default value
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
                child: Selector<RecipeProvider, bool>(
                  selector: (_, provider) =>
                      provider.isRecipeSaved(widget.recipeId),
                  builder: (context, isSaved, child) {
                    return IconButton(
                      icon: isSaved
                          ? Icon(Icons.bookmark, color: Colors.green)
                          : Icon(Icons.bookmark_border, color: Colors.grey),
                      onPressed: () async {
                        await showSaveRecipeDialog(context,
                            recipeId: widget.recipeId);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeImage(String? thumbnailUrl) {
    // Validate the thumbnail URL
    bool isValidUrl(String? url) {
      return url != null &&
          url.isNotEmpty &&
          (url.startsWith('http') || url.startsWith('https'));
    }

    if (isValidUrl(thumbnailUrl)) {
      return CachedNetworkImage(
        imageUrl: thumbnailUrl!,
        progressIndicatorBuilder: (context, url, downloadProgress) =>
            CircularProgressIndicator(value: downloadProgress.progress),
        errorWidget: (context, url, error) => Image.asset(
          'lib/assets/images/dinner-placeholder.png',
          fit: BoxFit.cover,
        ),
        fit: BoxFit.cover,
      );
    } else {
      // Fallback to local asset placeholder
      return Image.asset(
        'lib/assets/images/dinner-placeholder.png',
        fit: BoxFit.cover,
      );
    }
  }
}
