// ignore_for_file: use_build_context_synchronously

import 'dart:developer';
import 'dart:io';
import 'package:food_fellas/src/views/profile_screen.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
import 'package:food_fellas/providers/recipeProvider.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:food_fellas/src/models/recipe.dart';
import 'package:food_fellas/src/utils/dialog_utils.dart';
import 'package:path_provider/path_provider.dart';

class RecipeDetailScreen extends StatefulWidget {
  final String recipeId;

  RecipeDetailScreen({required this.recipeId});

  @override
  _RecipeDetailScreenState createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late Future<DocumentSnapshot> _recipeFuture;
  bool isRecipeSaved = false;
  String _recipeTitle = 'Recipe Details';
  bool _isTitleSet = false;
  int? servings;
  int? initialServings;
  double userRating = 0.0;
  Map<int, int> ratingCounts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
  int totalRatings = 0;
  bool _hasRatingChanged = false;
  final TextEditingController _commentController = TextEditingController();
  ValueNotifier<Set<String>> shoppingListItemsNotifier =
      ValueNotifier<Set<String>>({});
  late ValueNotifier<int> servingsNotifier;

  @override
  void initState() {
    super.initState();
    _recipeFuture = FirebaseFirestore.instance
        .collection('recipes')
        .doc(widget.recipeId)
        .get();
    servingsNotifier = ValueNotifier<int>(initialServings ?? 2);
    shoppingListItemsNotifier.value = Set<String>();
    _fetchShoppingListItems();
    _checkIfRecipeIsSaved();
  }

  void _checkIfRecipeIsSaved() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    QuerySnapshot collectionsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('collections')
        .get();

    bool saved = false;

    for (var collection in collectionsSnapshot.docs) {
      List<dynamic> recipes = collection['recipes'] ?? [];
      if (recipes.contains(widget.recipeId)) {
        saved = true;
        break;
      }
    }

    setState(() {
      isRecipeSaved = saved;
    });
  }

  void _fetchShoppingListItems() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('shoppingList')
        .get();

    Set<String> items =
        snapshot.docs.map((doc) => doc['item'] as String).toSet();

    shoppingListItemsNotifier.value = items;
  }

  void _fetchRatingBreakdown(Map<String, dynamic> recipeData) {
    setState(() {
      ratingCounts = Map<int, int>.from(recipeData['ratingCounts'] ??
          {
            1: 0,
            2: 0,
            3: 0,
            4: 0,
            5: 0,
          });
      totalRatings = recipeData['ratingsCount'] ?? 0;
      userRating = recipeData['averageRating']?.toDouble() ?? 0.0;
    });
  }

  @override
  void dispose() {
    if (_hasRatingChanged) {
      _submitRating(userRating);
    }
    _commentController.dispose();
    super.dispose();
  }

  // Submit user's rating
  Future<void> _submitRating(double rating) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You must be logged in to submit a rating.')),
      );
      return;
    }

    try {
      final recipeRef =
          FirebaseFirestore.instance.collection('recipes').doc(widget.recipeId);
      final ratingsCollection = recipeRef.collection('ratings');
      final userRatingDoc = await ratingsCollection.doc(user.uid).get();

      await ratingsCollection.doc(user.uid).set({
        'rating': rating,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        userRating = rating;
      });

      final recipeProvider =
          Provider.of<RecipeProvider>(context, listen: false);
      // recipeProvider.refreshRecipe(widget.recipeId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('An error occurred while submitting your rating.')),
        );
      }
    }
  }

  void _updateRating(double rating) {
    setState(() {
      userRating = rating;
      _hasRatingChanged = true;
    });

    // Submit rating in the background
    Future.microtask(() => _submitRating(rating));
  }

  // Submit user's comment
  void _submitComment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You must be logged in to submit a comment.')),
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
    // Submit the rating if it has changed
    if (_hasRatingChanged) {
      _submitRating(userRating);
      _hasRatingChanged = false;
    }
  }

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

    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('shoppingList')
        .where('item', isEqualTo: ingredientName)
        .get();

    if (snapshot.docs.isNotEmpty) {
      var docRef = snapshot.docs.first.reference;
      double existingAmount = snapshot.docs.first['amount'] ?? 0.0;
      await docRef.update({'amount': existingAmount + amount});
    } else {
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

    // Update the ValueNotifier
    shoppingListItemsNotifier.value = {
      ...shoppingListItemsNotifier.value,
      ingredientName
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.add_shopping_cart_rounded, color: Colors.green),
            SizedBox(width: 8),
            Text('$ingredientName added to your shopping list.'),
          ],
        ),
      ),
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
        await docRef.delete();
        shoppingListItemsNotifier.value = {
          ...shoppingListItemsNotifier.value..remove(ingredientName)
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.remove_shopping_cart_outlined, color: Colors.red),
                SizedBox(width: 8),
                Text('$ingredientName removed from your shopping list.'),
              ],
            ),
          ),
        );
      } else {
        await docRef.update({'amount': newAmount});
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
        const SnackBar(content: Text('You must be logged in to save recipes.')),
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

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Save Recipe to Collections'),
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
                              leading: const Icon(Icons.add),
                              title: const Text('Create New Collection'),
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
                                      style: const TextStyle(fontSize: 24)),
                                  const SizedBox(width: 8),
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
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
    _checkIfRecipeIsSaved();
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

  @override
  Widget build(BuildContext context) {
    final recipeProvider = Provider.of<RecipeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_recipeTitle),
        leading: BackButton(
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isRecipeSaved ? Icons.bookmark : Icons.bookmark_border,
              color: isRecipeSaved ? Colors.green : null,
            ),
            onPressed: _showSaveDialog,
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: recipeProvider.getRecipeById(widget.recipeId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          } else if (snapshot.hasError) {
            return const Center(
              child: Text('Error fetching recipe'),
            );
          } else if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
              child: Text('Recipe not found'),
            );
          } else {
            final recipeData = snapshot.data!;
            // In the FutureBuilder
            if (!_isTitleSet) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                setState(() {
                  _recipeTitle = recipeData['title'] ?? 'Recipe Details';
                  _isTitleSet = true;
                });
              });
            }
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

  //void _printOutJSONObject(Map<String, dynamic> recipeData) async {
  //Recipe recipe = Recipe.fromJson(recipeData!);
  //String jsonString = recipe.toJsonString();
  //log(jsonString);
  //final directory = await getApplicationDocumentsDirectory();
  //final logFile = File('${directory.path}/logFile.txt');
  //await logFile.writeAsString(jsonString, mode: FileMode.append);
  //}

  // Build the detailed recipe view
  Widget _buildRecipeDetail(Map<String, dynamic> recipeData) {
    String imageUrl = recipeData['imageUrl'] ?? '';
    String title = recipeData['title'] ?? '';
    String authorId = recipeData['authorId'] ?? '';
    String description = recipeData['description'] ?? '';
    int cookingTime = recipeData['totalTime'] ?? '';
    List<dynamic> ingredientsData = recipeData['ingredients'] ?? [];
    List<dynamic> cookingSteps = recipeData['cookingSteps'] ?? [];
    List<dynamic> tags = recipeData['tags'] ?? [];
    bool createdByAI = recipeData['createdByAI'] ?? false;
    final averageRating = recipeData['averageRating']?.toDouble() ?? 0.0;
    final ratingsCount = recipeData['ratingsCount'] ?? 0;
    final ratingCounts = Map<int, int>.from(
        recipeData['ratingCounts'] ?? {1: 0, 2: 0, 3: 0, 4: 0, 5: 0});

    // _printOutJSONObject(recipeData);

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
                _buildRatingSection(averageRating, ratingsCount),
                const SizedBox(height: 16),
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
            child: _buildTagsSection(tags, createdByAI),
          ),
          // Ingredients Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildIngredientsSection(ingredientsData),
          ),
          const SizedBox(height: 16),
          // Instructions Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildInstructionsSection(cookingSteps),
          ),
          const SizedBox(height: 16),
          // Comments and Reviews Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: _buildRatingAndCommentsSection(),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildRatingBreakdown(
                averageRating, ratingsCount, ratingCounts),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: _buildCommentsList(),
          ),
          const SizedBox(height: 16),
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
    int cookingTime,
  ) {
    return Stack(
      children: [
        // Recipe Image
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PhotoViewScreen(imageUrl: imageUrl),
              ),
            );
          },
          child: imageUrl.startsWith('http')
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
        ),
        // Overlay Container
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            color: Colors.black54,
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Recipe Title
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                // Author Name
                GestureDetector(
                  onTap: () {
                    // Navigate to the author's profile
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileScreen(userId: authorId),
                      ),
                    );
                  },
                  child: FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(authorId)
                        .get(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Text(
                          'Loading author...',
                          style: TextStyle(color: Colors.white),
                        );
                      } else if (snapshot.hasError ||
                          !snapshot.hasData ||
                          !snapshot.data!.exists) {
                        return const Text(
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
                          style: const TextStyle(
                            color: Colors.white,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white,
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(height: 4),
                // Details Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Ingredients Count
                    Row(
                      children: [
                        const Icon(Icons.restaurant_menu,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '$ingredientsCount ingredients',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // Steps Count
                    Row(
                      children: [
                        const Icon(Icons.list, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '$stepsCount steps',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // Cooking Time
                    Row(
                      children: [
                        const Icon(Icons.timer, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '$cookingTime min',
                          style: const TextStyle(color: Colors.white),
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
  Widget _buildRatingSection(averageRating, ratingsCount) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              averageRating.toStringAsFixed(1),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            RatingBarIndicator(
              rating: averageRating,
              itemBuilder: (context, index) => const Icon(
                Icons.star,
                color: Colors.amber,
              ),
              itemCount: 5,
              itemSize: 24.0,
            ),
            const SizedBox(width: 4),
            Text(
              '($ratingsCount)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTagsSection(List<dynamic> tags, bool createdByAI) {
    List<Widget> chips = [];

    if (createdByAI == true) {
      chips.add(
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.0),
          child: Chip(
            label: Text('✨ AI Generated'),
          ),
        ),
      );
      chips.add(
        Container(
          height: 24,
          child: const VerticalDivider(
            color: Colors.grey,
            thickness: 1,
          ),
        ),
      );
    }

    chips.addAll(
      tags.map((tag) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Chip(
            label: Text('${tag['icon']} ${tag['name']}'),
          ),
        );
      }).toList(),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips,
      ),
    );
  }

  Widget _buildServingsSection() {
    return ValueListenableBuilder<int>(
      valueListenable: servingsNotifier,
      builder: (context, currentServings, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: () {
                if (currentServings > 1) {
                  servingsNotifier.value = currentServings - 1;
                }
              },
            ),
            Text('$currentServings Servings'),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                servingsNotifier.value = currentServings + 1;
              },
            ),
          ],
        );
      },
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
        const SizedBox(height: 8),
        Text(
          'Ingredients',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        _buildServingsSection(),
        const SizedBox(height: 8),
        // Ingredients List Header
        Container(
          color: Colors.grey[200],
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: const Row(
            children: [
              SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Text(
                  'Amount',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.left,
                ),
              ),
              Expanded(
                flex: 4,
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
        ValueListenableBuilder<int>(
          valueListenable: servingsNotifier,
          builder: (context, currentServings, _) {
            return ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: ingredients.length,
              itemBuilder: (context, index) {
                final ingredient = ingredients[index];
                final ingredientName =
                    ingredient['ingredient']['ingredientName'] ?? 'Unknown';
                final baseAmount = ingredient['baseAmount'] is num
                    ? ingredient['baseAmount'].toDouble()
                    : 1;
                final unit = ingredient['unit'] ?? '';
                final initialIngredientServings =
                    ingredient['servings'] ?? initialServings;

                // Calculate the total amount based on the current servings
                final totalAmount =
                    (baseAmount * currentServings) / initialIngredientServings;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      // Amount and unit
                      Expanded(
                        flex: 3,
                        child: Text(
                          '${totalAmount % 1 == 0 ? totalAmount.toInt() : totalAmount.toStringAsFixed(1)} $unit',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // Ingredient name
                      Expanded(
                        flex: 4,
                        child: Text(ingredientName),
                      ),
                      // Shopping list button
                      Expanded(
                        flex: 1,
                        child: ValueListenableBuilder<Set<String>>(
                          valueListenable: shoppingListItemsNotifier,
                          builder: (context, shoppingListItems, _) {
                            bool isInShoppingList =
                                shoppingListItems.contains(ingredientName);

                            return AnimatedSwitcher(
                              duration: Duration(milliseconds: 300),
                              transitionBuilder:
                                  (Widget child, Animation<double> animation) {
                                return ScaleTransition(
                                    scale: animation, child: child);
                              },
                              child: IconButton(
                                key: ValueKey<bool>(isInShoppingList),
                                icon: Icon(
                                  isInShoppingList
                                      ? Icons.check
                                      : Icons.add_shopping_cart_rounded,
                                  color: isInShoppingList ? Colors.green : null,
                                ),
                                onPressed: () {
                                  if (isInShoppingList) {
                                    _removeIngredientFromShoppingList(
                                        ingredientName, totalAmount, unit);
                                  } else {
                                    _addIngredientToShoppingList(
                                        ingredientName, totalAmount, unit);
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
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
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
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

  Widget _buildRatingAndCommentsSection() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rate this Recipe!',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Center(
              child: RatingBar.builder(
                initialRating: userRating,
                minRating: 1,
                direction: Axis.horizontal,
                allowHalfRating: false,
                itemCount: 5,
                itemSize: 40.0,
                itemBuilder: (context, _) => const Icon(
                  Icons.star,
                  color: Colors.amber,
                ),
                onRatingUpdate: _updateRating,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              decoration: InputDecoration(
                labelText: 'Leave a comment',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _submitComment,
                ),
              ),
              maxLines: null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingBreakdown(averageRating, totalRatings, ratingCounts) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Average Rating Section
        Column(
          children: [
            Text(
              averageRating.toStringAsFixed(1),
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w600),
            ),
            // SizedBox(height: 8),
            RatingBarIndicator(
              rating: averageRating,
              itemBuilder: (context, index) => const Icon(
                Icons.star,
                color: Colors.amber,
              ),
              itemCount: 5,
              itemSize: 14.0,
            ),
            //SizedBox(height: 8),
            Text('$totalRatings'),
          ],
        ),
        const SizedBox(width: 24),
        // Rating Breakdown Section
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 5; i >= 1; i--)
                Row(
                  children: [
                    Text('$i'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 6,
                        child: LinearProgressIndicator(
                          value: totalRatings > 0
                              ? (ratingCounts[i]! / totalRatings)
                              : 0,
                          backgroundColor: Colors.grey[300],
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${ratingCounts[i]}'),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommentsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('recipes')
          .doc(widget.recipeId)
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return const Text('Error loading comments');
        } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text('No comments yet. Be the first to comment!');
        } else {
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Comments',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final commentData = snapshot.data!.docs[index].data()
                        as Map<String, dynamic>;
                    double rating = commentData['rating']?.toDouble() ?? 0.0;
                    return ListTile(
                      title: Text(commentData['userName'] ?? 'Anonymous'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (rating > 0)
                            RatingBarIndicator(
                              rating: rating,
                              itemBuilder: (context, index) => const Icon(
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
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        }
      },
    );
  }
}

class PhotoViewScreen extends StatelessWidget {
  final String imageUrl;

  PhotoViewScreen({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: PhotoView(
          imageProvider: imageUrl.startsWith('http')
              ? NetworkImage(imageUrl)
              : AssetImage(imageUrl) as ImageProvider,
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 2,
        ),
      ),
    );
  }
}
