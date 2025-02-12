import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_fellas/providers/recipeProvider.dart';
import '../views/recipeDetails_screen.dart';
import '../utils/dialog_utils.dart';
import 'package:provider/provider.dart';

class RecipeCard extends StatefulWidget {
  final String? recipeId;
  final Map<String, dynamic>? recipeData;
  final bool big;

  const RecipeCard({
    Key? key,
    this.recipeId,
    this.recipeData,
    this.big = false,
  }) : super(key: key);

  @override
  _RecipeCardState createState() => _RecipeCardState();
}

class _RecipeCardState extends State<RecipeCard> {
  Future<Map<String, dynamic>?>? _recipeFuture;
  Map<String, dynamic>? _recipeData; // If already provided or once fetched

  @override
  void initState() {
    super.initState();

    // Case A: If widget.recipeData is not null, we already have the data
    if (widget.recipeData != null) {
      _recipeData = widget.recipeData;
      if (_recipeData!['authorName'] == null) {
        final recipeProvider =
            Provider.of<RecipeProvider>(context, listen: false);

        // Suppose getAuthorById returns a Future<Map<String, dynamic>>
        recipeProvider
            .getAuthorById(_recipeData!['authorId'])
            .then((authorData) {
          setState(() {
            _recipeData!['authorName'] =
                authorData?['display_name'] ?? 'Unknown';
          });
        });
      }
    }
    // Case B: If not, and we have a recipeId, fetch/cached it
    else if (widget.recipeId != null) {
      final recipeProvider =
          Provider.of<RecipeProvider>(context, listen: false);
      _recipeFuture = recipeProvider.getRecipeById(widget.recipeId!);
    }
    // If neither is provided, there's not much we can do—maybe throw an error
  }

  @override
  Widget build(BuildContext context) {
    // If we already have recipeData, just build the card immediately
    if (_recipeData != null) {
      return _buildRecipeCard(_recipeData!);
    }

    // Otherwise, we must be fetching from `_recipeFuture`
    if (_recipeFuture == null) {
      // Means no recipeId and no recipeData => error or empty
      return Text('No recipe data or ID provided.');
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: _recipeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildPlaceholderSpinner();
        } else if (snapshot.hasError ||
            !snapshot.hasData ||
            snapshot.data == null) {
          // Instead of showing an error message, simply return an empty container
          // or a placeholder indicating the recipe is unavailable.
          return SizedBox.shrink();
        } else {
          _recipeData = snapshot.data!;
          return _buildRecipeCard(_recipeData!);
        }
      },
    );
  }

  Widget _buildPlaceholderSpinner() {
    return Container(
      width: widget.big ? 400 : 250,
      height: widget.big ? null : 220, // or some stable height
      alignment: Alignment.center,
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildRecipeCard(Map<String, dynamic> recipeData) {
    // Example from your existing code
    // Extract needed fields from `recipeData`
    final theme = Theme.of(context);
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);

    String title = recipeData['title'] ?? 'Unnamed Recipe';
    String description = recipeData['description'] ?? '';
    double rating = (recipeData['averageRating'] ?? 0.0).toDouble();
    int ratingsCount = recipeData['ratingsCount'] ?? 0;
    int totalTime = recipeData['totalTime'] ?? 0;
    String thumbnailUrl = recipeData['imageUrl'] ?? '';
    String authorName = recipeData['authorName'] ?? 'Unknown author';
    final recipeId = recipeData['id'] ?? widget.recipeId;

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
              onTap: () {
                // Navigate with either the local ID or fallback
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RecipeDetailScreen(
                      recipeId: recipeId,
                    ),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
            // The bookmark button using Selector
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.white.withAlpha(200),
                child: Selector<RecipeProvider, bool>(
                  selector: (_, provider) => provider.isRecipeSaved(recipeId),
                  builder: (context, isSaved, child) {
                    return IconButton(
                      icon: isSaved
                          ? Icon(Icons.bookmark, color: Colors.green)
                          : Icon(Icons.bookmark_border, color: Colors.grey),
                      onPressed: () async {
                        await showSaveRecipeDialog(context, recipeId: recipeId);
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
        progressIndicatorBuilder: (context, url, downloadProgress) => Center(
          child: SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(value: downloadProgress.progress),
          ),
        ),
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
