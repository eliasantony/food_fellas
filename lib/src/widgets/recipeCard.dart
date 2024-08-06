import 'package:flutter/material.dart';

import '../views/recipeDetails_screen.dart';

class RecipeCard extends StatefulWidget {
  final String title;
  final String description;
  final double rating;
  final String cookTime;
  final String thumbnailUrl;
  final String author;
  final bool big;

  const RecipeCard({
    super.key,
    required this.title,
    required this.description,
    required this.rating,
    required this.cookTime,
    required this.thumbnailUrl,
    required this.author,
    this.big = false,
  });

  @override
  _RecipeCardState createState() => _RecipeCardState();
}

class _RecipeCardState extends State<RecipeCard> {
  bool isLiked = false;

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
                    builder: (context) => RecipeDetailScreen(),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.asset(
                      widget.thumbnailUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.title,
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontSize: 16),
                        ),
                        SizedBox(height: 4),
                        Text(
                          widget.author,
                          style: theme.textTheme.titleSmall,
                        ),
                        SizedBox(height: 8),
                        Text(
                          widget.description,
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
                                  widget.rating.toString(),
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
                                  widget.cookTime,
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
                      setState(() {
                        isLiked = !isLiked;
                      });
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
}
