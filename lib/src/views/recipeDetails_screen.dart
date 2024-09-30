import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:food_fellas/src/utils/dialog_utils.dart';

class RecipeDetailScreen extends StatefulWidget {
  final String recipeId;

  RecipeDetailScreen({required this.recipeId});

  @override
  _RecipeDetailScreenState createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late Future<DocumentSnapshot> _recipeFuture;
  int? servings;
  int? initialServings;
  double userRating = 0.0;
  final TextEditingController _commentController = TextEditingController();
  Set<String> _shoppingListItems = Set();

  @override
  void initState() {
    super.initState();
    _recipeFuture = FirebaseFirestore.instance
        .collection('recipes')
        .doc(widget.recipeId)
        .get();
    _fetchUserRating(); // Fetch the user's rating
    _fetchShoppingListItems(); // Fetch shopping list items
  }

  void _fetchShoppingListItems() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('shoppingList')
        .get();

    setState(() {
      _shoppingListItems =
          snapshot.docs.map((doc) => doc['item'] as String).toSet();
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // Fetch average rating and count
  Future<Map<String, dynamic>> _fetchAverageRating() async {
    final ratingsSnapshot = await FirebaseFirestore.instance
        .collection('recipes')
        .doc(widget.recipeId)
        .collection('ratings')
        .get();

    int ratingsCount = ratingsSnapshot.docs.length;

    if (ratingsCount == 0) {
      return {'averageRating': 0.0, 'ratingsCount': 0};
    }

    double totalRating = 0.0;
    ratingsSnapshot.docs.forEach((doc) {
      totalRating += doc.data()['rating']?.toDouble() ?? 0.0;
    });

    double averageRating = totalRating / ratingsCount;

    return {'averageRating': averageRating, 'ratingsCount': ratingsCount};
  }

  // Fetch user's rating
  Future<void> _fetchUserRating() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    final userRatingDoc = await FirebaseFirestore.instance
        .collection('recipes')
        .doc(widget.recipeId)
        .collection('ratings')
        .doc(user.uid)
        .get();

    if (userRatingDoc.exists) {
      setState(() {
        userRating = userRatingDoc.data()?['rating']?.toDouble() ?? 0.0;
      });
    }
  }

  // Submit user's rating
  void _submitRating(double rating) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You must be logged in to submit a rating.')),
      );
      return;
    }

    await FirebaseFirestore.instance
        .collection('recipes')
        .doc(widget.recipeId)
        .collection('ratings')
        .doc(user.uid)
        .set({
      'rating': rating,
      'timestamp': FieldValue.serverTimestamp(),
    });

    setState(() {
      userRating = rating;
    });
  }

  // Submit user's comment
  void _submitComment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You must be logged in to submit a comment.')),
      );
      return;
    }

    final userData = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    String userName = userData.data()?['display_name'] ?? 'Anonymous';

    // Get the user's rating
    double rating = userRating;

    await FirebaseFirestore.instance
        .collection('recipes')
        .doc(widget.recipeId)
        .collection('comments')
        .add({
      'userId': user.uid,
      'userName': userName,
      'comment': _commentController.text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'rating': rating > 0 ? rating : null,
    });

    _commentController.clear();
  }

  // Add ingredient to shopping list
  void _addIngredientToShoppingList(
      String ingredientName, double amount, String unit) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('You must be logged in to add to the shopping list.')),
      );
      return;
    }

    // Check if item already exists
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('shoppingList')
        .where('item', isEqualTo: ingredientName)
        .get();

    if (snapshot.docs.isNotEmpty) {
      // Update the amount
      var docRef = snapshot.docs.first.reference;
      double existingAmount = snapshot.docs.first['amount'] ?? 0.0;
      await docRef.update({
        'amount': existingAmount + amount,
      });
    } else {
      // Add new item
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('shoppingList')
          .add({
        'item': ingredientName,
        'amount': amount,
        'unit': unit,
        'status': 'active',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    setState(() {
      _shoppingListItems.add(ingredientName);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$ingredientName added to your shopping list.')),
    );
  }

  void _removeIngredientFromShoppingList(
      String ingredientName, double amount, String unit) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('shoppingList')
        .where('item', isEqualTo: ingredientName)
        .get();

    if (snapshot.docs.isNotEmpty) {
      var docRef = snapshot.docs.first.reference;
      double existingAmount = snapshot.docs.first['amount'] ?? 0.0;
      double newAmount = existingAmount - amount;
      if (newAmount <= 0) {
        // Remove the item
        await docRef.delete();
        setState(() {
          _shoppingListItems.remove(ingredientName);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('$ingredientName removed from your shopping list.')),
        );
      } else {
        // Update the amount
        await docRef.update({
          'amount': newAmount,
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Updated $ingredientName in your shopping list.')),
        );
      }
    }
  }

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
          builder: (context, setState) {
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
                                setState(() {
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

  void _createNewCollection(String name, String icon, bool isPublic) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final collectionRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('collections')
        .doc();

    await collectionRef.set({
      'name': name,
      'icon': icon,
      'isPublic': isPublic,
      'recipes': [widget.recipeId],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Build the screen
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe Details'),
        leading: BackButton(
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.bookmark_border), // Change icon if recipe is saved
            onPressed: _showSaveDialog,
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: _recipeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          } else if (snapshot.hasError) {
            return const Center(
              child: Text('Error fetching recipe'),
            );
          } else if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text('Recipe not found'),
            );
          } else {
            final recipeData = snapshot.data!.data() as Map<String, dynamic>;
            // Set initialServings and servings only if they are null
            if (initialServings == null) {
              initialServings = recipeData['initialServings'] ?? 1;
              servings = initialServings;
            }

            return _buildRecipeDetail(recipeData);
          }
        },
      ),
    );
  }

  // Build the detailed recipe view
  Widget _buildRecipeDetail(Map<String, dynamic> recipeData) {
    String imageUrl = recipeData['imageUrl'] ?? '';
    String title = recipeData['title'] ?? '';
    String authorId = recipeData['authorId'] ?? '';
    String description = recipeData['description'] ?? '';
    String cookingTime = recipeData['cookingTime'] ?? '';
    List<dynamic> ingredientsData = recipeData['ingredients'] ?? [];
    List<dynamic> cookingSteps = recipeData['cookingSteps'] ?? [];
    List<dynamic> tags = recipeData['tags'] ?? [];
    Map<String, dynamic>? nutrition = recipeData['nutrition'];

    print(tags);

    int ingredientsCount = ingredientsData.length;
    int stepsCount = cookingSteps.length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Image Section with Overlay
          _buildImageSection(
            imageUrl,
            title,
            authorId,
            ingredientsCount,
            stepsCount,
            cookingTime,
          ),
          // Rating Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildRatingSection(),
                SizedBox(height: 16),
                // Description
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          // Tags Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildTagsSection(tags),
          ),
          // Ingredients Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildIngredientsSection(ingredientsData),
          ),
          SizedBox(height: 16),
          // Instructions Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildInstructionsSection(cookingSteps),
          ),
          SizedBox(height: 16),
          // Comments and Reviews Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildCommentsAndReviewsSection(),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  // Image Section with Overlay
  Widget _buildImageSection(
    String imageUrl,
    String title,
    String authorId,
    int ingredientsCount,
    int stepsCount,
    String cookingTime,
  ) {
    return Stack(
      children: [
        // Recipe Image
        imageUrl.startsWith('http')
            ? Image.network(
                imageUrl,
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
              )
            : Image.asset(
                imageUrl,
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
              ),
        // Overlay Container
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            color: Colors.black54,
            padding: EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Recipe Title
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 4),
                // Author Name
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(authorId)
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Text(
                        'Loading author...',
                        style: TextStyle(color: Colors.white),
                      );
                    } else if (snapshot.hasError ||
                        !snapshot.hasData ||
                        !snapshot.data!.exists) {
                      return Text(
                        'Unknown author',
                        style: TextStyle(color: Colors.white),
                      );
                    } else {
                      final authorData =
                          snapshot.data!.data() as Map<String, dynamic>;
                      String authorName =
                          authorData['display_name'] ?? 'Unknown author';
                      return Text(
                        'by $authorName',
                        style: TextStyle(color: Colors.white),
                      );
                    }
                  },
                ),
                SizedBox(height: 4),
                // Details Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Ingredients Count
                    Row(
                      children: [
                        Icon(Icons.restaurant_menu,
                            color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          '$ingredientsCount ingredients',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                    SizedBox(width: 16),
                    // Steps Count
                    Row(
                      children: [
                        Icon(Icons.list, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          '$stepsCount steps',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                    SizedBox(width: 16),
                    // Cooking Time
                    Row(
                      children: [
                        Icon(Icons.timer, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          '$cookingTime',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Rating Section
  Widget _buildRatingSection() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchAverageRating(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return Text('Error fetching rating');
        } else {
          double averageRating = snapshot.data?['averageRating'] ?? 0.0;
          int ratingsCount = snapshot.data?['ratingsCount'] ?? 0;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    averageRating.toStringAsFixed(1),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 4),
                  RatingBarIndicator(
                    rating: averageRating,
                    itemBuilder: (context, index) => Icon(
                      Icons.star,
                      color: Colors.amber,
                    ),
                    itemCount: 5,
                    itemSize: 24.0,
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                '$ratingsCount ratings',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          );
        }
      },
    );
  }

  // Tags Section
  Widget _buildTagsSection(List<dynamic> tags) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tags.map((tag) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Chip(
              label: Text('${tag['icon']} ${tag['name']}'),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Ingredients Section
  Widget _buildIngredientsSection(List<dynamic> ingredientsData) {
    List<Map<String, dynamic>> ingredients =
        ingredientsData.cast<Map<String, dynamic>>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Servings Adjustment
        SizedBox(height: 8),
        Text(
          'Ingredients',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: () {
                if (servings! > 1) {
                  setState(() {
                    servings = servings! - 1;
                  });
                }
              },
            ),
            Text(
              '$servings Servings',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                setState(() {
                  servings = servings! + 1;
                });
              },
            ),
          ],
        ),
        SizedBox(height: 8),
        // Ingredients List Header
        Container(
          color: Colors.grey[200],
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'Amount',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                flex: 5,
                child: Text(
                  'Ingredient',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 1,
                child: Icon(Icons
                    .shopping_cart_outlined), // Placeholder for the button column
              ),
            ],
          ),
        ),
        // Ingredients List
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: ingredients.length,
          itemBuilder: (context, index) {
            final ingredient = ingredients[index];
            final ingredientName =
                ingredient['ingredient']['ingredientName'] ?? 'Unknown';
            final baseAmount = ingredient['baseAmount']?.toDouble() ?? 0.0;
            final unit = ingredient['unit'] ?? '';
            final initialIngredientServings =
                ingredient['servings'] ?? initialServings;
            final totalAmount =
                (baseAmount * servings!) / initialIngredientServings;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  // Amount and unit
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${totalAmount % 1 == 0 ? totalAmount.toInt() : totalAmount.toStringAsFixed(1)} $unit',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // Ingredient name
                  Expanded(
                    flex: 5,
                    child: Text(ingredientName),
                  ),
                  // Plus button
                  // Plus/check button
                  Expanded(
                    flex: 1,
                    child: IconButton(
                      icon: Icon(
                        _shoppingListItems.contains(ingredientName)
                            ? Icons.check
                            : Icons.add,
                      ),
                      onPressed: () {
                        if (_shoppingListItems.contains(ingredientName)) {
                          // Remove from shopping list
                          _removeIngredientFromShoppingList(
                              ingredientName, totalAmount, unit);
                        } else {
                          // Add to shopping list
                          _addIngredientToShoppingList(
                              ingredientName, totalAmount, unit);
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildInstructionsSection(List<dynamic> cookingSteps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Instructions',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: cookingSteps.length,
          itemBuilder: (context, index) {
            return ListTile(
              leading: CircleAvatar(
                child: Text('${index + 1}'),
                radius: 16,
              ),
              title: Text(cookingSteps[index]),
            );
          },
        ),
      ],
    );
  }

  // Comments and Reviews Section
  Widget _buildCommentsAndReviewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rating and Comments Input
        Text('Ratings & Comments',
            style: Theme.of(context).textTheme.headlineSmall),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Rate this recipe:',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            RatingBar.builder(
              initialRating: userRating,
              minRating: 1,
              direction: Axis.horizontal,
              allowHalfRating: true,
              itemCount: 5,
              itemSize: 20.0,
              itemPadding: EdgeInsets.symmetric(horizontal: 1.0),
              itemBuilder: (context, _) => Icon(
                Icons.star,
                color: Colors.amber,
              ),
              onRatingUpdate: (rating) {
                _submitRating(rating);
              },
            ),
          ],
        ),
        SizedBox(height: 8),
        // Comments Text Field
        TextField(
          controller: _commentController,
          decoration: InputDecoration(
            labelText: 'Leave a comment',
            border: OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(Icons.send),
              onPressed: _submitComment,
            ),
          ),
          maxLines: null,
        ),
        SizedBox(height: 16),
        // Display Comments
        Text(
          'Comments',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('recipes')
              .doc(widget.recipeId)
              .collection('comments')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return CircularProgressIndicator();
            } else if (snapshot.hasError) {
              return Text('Error loading comments');
            } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Text('No comments yet. Be the first to comment!');
            } else {
              return ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final commentData =
                      snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  double rating = commentData['rating']?.toDouble() ?? 0.0;
                  return ListTile(
                    title: Text(commentData['userName'] ?? 'Anonymous'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (rating > 0)
                          RatingBarIndicator(
                            rating: rating,
                            itemBuilder: (context, index) => Icon(
                              Icons.star,
                              color: Colors.amber,
                            ),
                            itemCount: 5,
                            itemSize: 16.0,
                          ),
                        Text(commentData['comment'] ?? ''),
                      ],
                    ),
                    trailing: Text(
                      commentData['timestamp'] != null
                          ? (commentData['timestamp'] as Timestamp)
                              .toDate()
                              .toLocal()
                              .toString()
                              .split(' ')[0]
                              .split('-')
                              .reversed
                              .join('.')
                          : '',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  );
                },
              );
            }
          },
        ),
      ],
    );
  }
}
