import 'package:flutter/material.dart';
import '../views/recipeDetails_screen.dart';

class RecipeCard extends StatelessWidget {
  final String recipeId;
  final String title;
  final String description;
  final double rating;
  final String cookTime;
  final String thumbnailUrl;
  final String author;
  final bool big;

  const RecipeCard({
    Key? key,
    required this.recipeId,
    required this.title,
    required this.description,
    required this.rating,
    required this.cookTime,
    required this.thumbnailUrl,
    required this.author,
    this.big = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    bool isLiked = false; // Manage this state as needed

    return Container(
      width: big ? 400 : 250,
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
                        RecipeDetailScreen(recipeId: recipeId),
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
                        Text(
                          title,
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontSize: 16),
                        ),
                        SizedBox(height: 4),
                        Text(
                          author,
                          style: theme.textTheme.titleSmall,
                        ),
                        SizedBox(height: 8),
                        Text(
                          description,
                          style: theme.textTheme.bodyMedium,
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Icon(
                                  Icons.star,
                                  color: Colors.yellow.shade800,
                                  size: 24,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  rating.toStringAsFixed(1),
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
                                  cookTime,
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
            // Like button (optional)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child: CircleAvatar(
                  key: ValueKey<bool>(isLiked),
                  backgroundColor:
                      Colors.white.withAlpha(200), // Slight transparency
                  child: IconButton(
                    icon: isLiked
                        ? Icon(Icons.favorite, color: Colors.red)
                        : Icon(Icons.favorite_border, color: Colors.grey),
                    onPressed: () {
                      // Handle like functionality
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeImage() {
    if (thumbnailUrl == null || thumbnailUrl.isEmpty) {
      return Image.network(
        'https://via.placeholder.com/400x225',
        fit: BoxFit.cover,
      );
    } else if (thumbnailUrl.startsWith('http')) {
      return Image.network(
        thumbnailUrl,
        fit: BoxFit.cover,
      );
    } else {
      return Image.asset(
        thumbnailUrl,
        fit: BoxFit.cover,
      );
    }
  }
}
