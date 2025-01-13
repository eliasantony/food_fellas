import 'dart:developer';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:food_fellas/providers/searchProvider.dart';
import 'package:food_fellas/src/models/macroEstimation_config.dart';
import 'package:food_fellas/src/models/recipe.dart';
import 'package:food_fellas/src/views/addRecipeForm/addRecipe_form.dart';
import 'package:food_fellas/src/views/photoview_screen.dart';
import 'package:food_fellas/src/views/profile_screen.dart';
import 'package:food_fellas/src/widgets/build_comment.dart';
import 'package:food_fellas/src/widgets/horizontalRecipeRow.dart';
import 'package:food_fellas/src/widgets/macros_section.dart';
import 'package:food_fellas/src/widgets/similarRecipes_section.dart';
import 'package:marquee/marquee.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
import 'package:food_fellas/providers/recipeProvider.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:food_fellas/src/utils/dialog_utils.dart';

class RecipeDetailScreen extends StatefulWidget {
  final String recipeId;

  const RecipeDetailScreen({required this.recipeId});

  @override
  _RecipeDetailScreenState createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  Recipe? _currentRecipe;
  bool isRecipeSaved = false;
  String? _authorName;
  String _userRole = 'user';
  Future<DocumentSnapshot>? _authorFuture;
  int? servings;
  int? initialServings;
  double userRating = 0.0;
  bool _hasRatingChanged = false;
  final TextEditingController _commentController = TextEditingController();
  ValueNotifier<Set<String>> shoppingListItemsNotifier =
      ValueNotifier<Set<String>>({});
  late ValueNotifier<int> servingsNotifier;
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _opacityNotifier = ValueNotifier<double>(0.0);
  bool _isMarquee = false;
  bool _didFetchSimilar = false;
  String? _lastFetchedRecipeId;
  bool _isLoadingMacros = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    servingsNotifier = ValueNotifier<int>(initialServings ?? 2);
    shoppingListItemsNotifier.value = Set<String>();
    _fetchUserRating();
    _fetchShoppingListItems();
    _checkIfRecipeIsSaved();
    _fetchUserRole();
    _logRecipeView();
  }

  @override
  void dispose() {
    if (_hasRatingChanged) {
      _submitRating(userRating);
    }
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _commentController.dispose();
    servingsNotifier.dispose();
    shoppingListItemsNotifier.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!mounted) return;
    double offset = _scrollController.offset;
    double newOpacity = offset / (250.0 - kToolbarHeight); // Adjust as needed
    newOpacity = newOpacity.clamp(0.0, 1.0);
    _opacityNotifier.value = newOpacity;
  }

  void _logRecipeView() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    // Create or update the interaction document
    await userRef.collection('interactionHistory').doc(widget.recipeId).set({
      'recipeId': widget.recipeId,
      'viewedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Optionally, you can also log this under the recipe document
    final recipeRef =
        FirebaseFirestore.instance.collection('recipes').doc(widget.recipeId);

    await recipeRef.collection('views').doc(user.uid).set({
      'userId': user.uid,
      'viewedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<DocumentSnapshot> _fetchRecipeStream() {
    return FirebaseFirestore.instance
        .collection('recipes')
        .doc(widget.recipeId)
        .snapshots();
  }

  void _fetchUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (userDoc.exists) {
      setState(() {
        _userRole = userDoc['role'] ?? 'user';
      });
    }
  }

  void _handleMenuOption(String value) {
    switch (value) {
      case 'save':
        _showSaveDialog();
        break;
      case 'edit':
        _editRecipe();
        break;
      case 'delete':
        _confirmDeleteRecipe();
        break;
    }
  }

  void _confirmDeleteRecipe() async {
    bool confirm = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Delete Recipe?'),
              content: const Text(
                  'Are you sure you want to delete this recipe? \nThis action cannot be undone.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
                ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text(
                      'Delete',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[500],
                    )),
              ],
            );
          },
        ) ??
        false;

    if (confirm) {
      await _deleteRecipe();
    }
  }

  Future<void> _deleteRecipe() async {
    try {
      // Delete the recipe document
      await FirebaseFirestore.instance
          .collection('recipes')
          .doc(widget.recipeId)
          .delete();

      // Decrease the recipe count for the author
      if (_currentRecipe != null) {
        print('Decreasing recipe count for author');
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentRecipe!.authorId)
            .update({'recipeCount': FieldValue.increment(-1)});
      }

      // Navigate back after deletion
      Navigator.pop(context);

      // Show a success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recipe deleted successfully.')),
      );
    } catch (e) {
      // Handle any errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting recipe: $e')),
      );
    }
  }

  void _editRecipe() async {
    if (_currentRecipe != null) {
      bool confirm = await _showEditConfirmationDialog();
      if (confirm) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddRecipeForm(initialRecipe: _currentRecipe),
          ),
        ).then((result) {
          if (result == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Recipe updated successfully!')),
            );
          }
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recipe data is not available yet.')),
      );
    }
  }

  Future<bool> _showEditConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Edit Recipe'),
              content: const Text('Are you sure you want to edit this recipe?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Confirm',
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
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

    if (!mounted) return;
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

  Future<void> _fetchUserRating() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final recipeRef =
        FirebaseFirestore.instance.collection('recipes').doc(widget.recipeId);
    final ratingsCollection = recipeRef.collection('ratings');
    final userRatingDoc = await ratingsCollection.doc(user.uid).get();

    if (userRatingDoc.exists) {
      final data = userRatingDoc.data();
      if (data != null && data['rating'] != null) {
        setState(() {
          userRating = data['rating'].toDouble();
        });
      }
    }
  }

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

      await ratingsCollection.doc(user.uid).set({
        'rating': rating,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // Ensure merging

      if (!mounted) return;
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
    if (!mounted) return;
    setState(() {
      userRating = rating;
      _hasRatingChanged = true;
    });

    // Submit rating in the background
    Future.microtask(() => _submitRating(rating));
  }

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
      await _submitRating(userRating);
      _hasRatingChanged = false;
    }
  }

  void _addIngredientToShoppingList(
      String ingredientName, double amount, String unit) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
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
      double existingAmount = snapshot.docs.first['amount']?.toDouble() ?? 0.0;
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
            const Icon(Icons.add_shopping_cart_rounded, color: Colors.green),
            const SizedBox(width: 8),
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
      double existingAmount = snapshot.docs.first['amount']?.toDouble() ?? 0.0;
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
                const Icon(Icons.remove_shopping_cart_outlined,
                    color: Colors.red),
                const SizedBox(width: 8),
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
                                  Text(
                                    collection['icon'] ?? '🍽',
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(collection['name'] ?? 'Unnamed'),
                                ],
                              ),
                              onChanged: (bool? value) {
                                if (!mounted) return;
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
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Done',
                    style: TextStyle(color: Colors.white),
                  ),
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
      body: StreamBuilder<DocumentSnapshot>(
        stream: _fetchRecipeStream(),
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
            _currentRecipe = Recipe.fromJson(recipeData);

            // Determine if current user is the author or an admin
            final userId = FirebaseAuth.instance.currentUser?.uid;
            bool canEditOrDelete = userId != null &&
                (recipeData['authorId'] == userId || _userRole == 'admin');

            // Initialize author data if not already done
            if (_authorFuture == null && recipeData['authorId'] != null) {
              _authorFuture = FirebaseFirestore.instance
                  .collection('users')
                  .doc(recipeData['authorId'])
                  .get()
                  .then((doc) {
                _authorName = doc.exists
                    ? doc['display_name'] ?? 'Unknown author'
                    : 'Unknown author';
                return doc;
              });
            }

            // Initialize servings if not already set
            if (initialServings == null) {
              initialServings = recipeData['initialServings'] ?? 1;
              servings = initialServings;
              servingsNotifier.value = initialServings!;
            }

            return NestedScrollView(
              controller: _scrollController,
              headerSliverBuilder:
                  (BuildContext context, bool innerBoxIsScrolled) {
                return <Widget>[
                  SliverAppBar(
                    expandedHeight: 250.0,
                    floating: false,
                    pinned: true,
                    automaticallyImplyLeading: false,
                    flexibleSpace: LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                        double appBarHeight = constraints.biggest.height;
                        double opacity = (_scrollController.offset) /
                            (250.0 - kToolbarHeight);
                        opacity = opacity.clamp(0.0, 1.0);

                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            // Image Section
                            _buildImageSection(recipeData),
                            // Overlay Back and Options button over the image
                            Positioned(
                              top: MediaQuery.of(context).padding.top,
                              left: 4.0,
                              right: 4.0,
                              child: Container(
                                height: kToolbarHeight,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Back button
                                    CircleAvatar(
                                      backgroundColor: Colors.white70,
                                      child: IconButton(
                                        icon: const Icon(Icons.arrow_back),
                                        color: Colors.black
                                            .withOpacity(1.0 - opacity),
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                    ),
                                    // Options Menu or Save Button
                                    if (canEditOrDelete)
                                      PopupMenuButton<String>(
                                        icon: Icon(Icons.more_vert,
                                            color: Colors.white
                                                .withOpacity(1.0 - opacity)),
                                        onSelected: _handleMenuOption,
                                        itemBuilder: (BuildContext context) {
                                          return [
                                            PopupMenuItem<String>(
                                              value: 'save',
                                              child: ListTile(
                                                leading: Icon(
                                                  isRecipeSaved
                                                      ? Icons.bookmark
                                                      : Icons.bookmark_border,
                                                  color: isRecipeSaved
                                                      ? Colors.green
                                                      : Colors.black,
                                                ),
                                                title: Text(isRecipeSaved
                                                    ? 'Unsave Recipe'
                                                    : 'Save Recipe'),
                                              ),
                                            ),
                                            PopupMenuItem<String>(
                                              value: 'edit',
                                              child: ListTile(
                                                leading: const Icon(Icons.edit),
                                                title:
                                                    const Text('Edit Recipe'),
                                              ),
                                            ),
                                            const PopupMenuItem<String>(
                                              value: 'delete',
                                              child: ListTile(
                                                leading: Icon(
                                                  Icons.delete,
                                                  color: Colors.red,
                                                ),
                                                title: Text('Delete Recipe'),
                                              ),
                                            ),
                                          ];
                                        },
                                      )
                                    else
                                      // Save Button for regular users
                                      CircleAvatar(
                                        backgroundColor: Colors.white70,
                                        child: IconButton(
                                          icon: Icon(
                                            isRecipeSaved
                                                ? Icons.bookmark
                                                : Icons.bookmark_border,
                                          ),
                                          color: isRecipeSaved
                                              ? Colors.green
                                                  .withOpacity(1.0 - opacity)
                                              : Colors.white
                                                  .withOpacity(1.0 - opacity),
                                          onPressed: _showSaveDialog,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            // AppBar Title and Buttons when scrolled
                            // Inside the AppBar Title and Buttons when scrolled
                            Positioned(
                              top: 0.0,
                              left: 0.0,
                              right: 0.0,
                              child: ValueListenableBuilder<double>(
                                valueListenable: _opacityNotifier,
                                builder: (context, opacity, child) {
                                  return AnimatedOpacity(
                                    duration: const Duration(milliseconds: 0),
                                    opacity: opacity,
                                    child: Container(
                                      color: Theme.of(context)
                                          .scaffoldBackgroundColor,
                                      height:
                                          MediaQuery.of(context).padding.top +
                                              kToolbarHeight,
                                      child: Column(
                                        children: [
                                          SizedBox(
                                              height: MediaQuery.of(context)
                                                  .padding
                                                  .top),
                                          Container(
                                            height: kToolbarHeight,
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                // Back button
                                                IconButton(
                                                  icon: const Icon(
                                                      Icons.arrow_back),
                                                  color: Theme.of(context)
                                                              .brightness ==
                                                          Brightness.dark
                                                      ? Colors.white
                                                      : Colors.black,
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                ),
                                                // Title
                                                Expanded(
                                                  child: GestureDetector(
                                                    onLongPress: () {
                                                      setState(() {
                                                        _isMarquee = true;
                                                      });
                                                    },
                                                    onLongPressUp: () {
                                                      setState(() {
                                                        _isMarquee = false;
                                                      });
                                                    },
                                                    child: _isMarquee
                                                        ? Marquee(
                                                            text:
                                                                _currentRecipe!
                                                                    .title,
                                                            style: TextStyle(
                                                              color: Theme.of(context)
                                                                          .brightness ==
                                                                      Brightness
                                                                          .dark
                                                                  ? Colors.white
                                                                  : Colors
                                                                      .black,
                                                              fontSize: 20.0,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                            blankSpace: 20.0,
                                                            velocity: 40.0,
                                                          )
                                                        : Text(
                                                            _currentRecipe!
                                                                .title,
                                                            style: TextStyle(
                                                              color: Theme.of(context)
                                                                          .brightness ==
                                                                      Brightness
                                                                          .dark
                                                                  ? Colors.white
                                                                  : Colors
                                                                      .black,
                                                              fontSize: 20.0,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            textAlign: TextAlign
                                                                .center,
                                                          ),
                                                  ),
                                                ),
                                                // Options Menu or Save Button
                                                if (canEditOrDelete)
                                                  PopupMenuButton<String>(
                                                    icon: Icon(
                                                      Icons.more_vert,
                                                      color: Theme.of(context)
                                                                  .brightness ==
                                                              Brightness.dark
                                                          ? Colors.white
                                                          : Colors.black,
                                                    ),
                                                    onSelected:
                                                        _handleMenuOption,
                                                    itemBuilder:
                                                        (BuildContext context) {
                                                      return [
                                                        PopupMenuItem<String>(
                                                          value: 'save',
                                                          child: ListTile(
                                                            leading: Icon(
                                                              isRecipeSaved
                                                                  ? Icons
                                                                      .bookmark
                                                                  : Icons
                                                                      .bookmark_border,
                                                              color: isRecipeSaved
                                                                  ? Colors.green
                                                                  : Theme.of(context).brightness == Brightness.dark
                                                                      ? Colors.white
                                                                      : Colors.black,
                                                            ),
                                                            title: Text(isRecipeSaved
                                                                ? 'Unsave Recipe'
                                                                : 'Save Recipe'),
                                                          ),
                                                        ),
                                                        PopupMenuItem<String>(
                                                          value: 'edit',
                                                          child: ListTile(
                                                            leading: const Icon(
                                                                Icons.edit),
                                                            title: const Text(
                                                                'Edit Recipe'),
                                                          ),
                                                        ),
                                                        PopupMenuItem<String>(
                                                          value: 'delete',
                                                          child: ListTile(
                                                            leading: const Icon(
                                                              Icons.delete,
                                                              color: Colors.red,
                                                            ),
                                                            title: const Text(
                                                                'Delete Recipe'),
                                                          ),
                                                        ),
                                                      ];
                                                    },
                                                  )
                                                else
                                                  // Save Button for regular users
                                                  IconButton(
                                                    icon: Icon(
                                                      isRecipeSaved
                                                          ? Icons.bookmark
                                                          : Icons
                                                              .bookmark_border,
                                                    ),
                                                    color: isRecipeSaved
                                                        ? Colors.green
                                                        : Colors.black,
                                                    onPressed: _showSaveDialog,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ];
              },
              body: ListView(
                key: PageStorageKey('recipe-detail-${widget.recipeId}'),
                shrinkWrap: false,
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.zero,
                children: _buildRecipeDetail(recipeData),
              ),
            );
          }
        },
      ),
    );
  }

  List<Widget> _buildRecipeDetail(Map<String, dynamic> recipeData) {
    String recipeId = recipeData['id'] ?? '';
    String description = recipeData['description'] ?? '';
    List<dynamic> ingredientsData = recipeData['ingredients'] ?? [];
    List<dynamic> cookingSteps = recipeData['cookingSteps'] ?? [];
    List<dynamic> tags = recipeData['tags'] ?? [];
    bool createdByAI = recipeData['createdByAI'] ?? false;
    final averageRating = recipeData['averageRating']?.toDouble() ?? 0.0;
    final ratingsCount = recipeData['ratingsCount'] ?? 0;
    final Map<int, int> ratingCounts =
        (recipeData['ratingCounts'] as Map<String, dynamic>?)
                ?.map((key, value) => MapEntry(int.parse(key), value as int)) ??
            {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

    return [
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
      // Macros Section
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: _currentRecipe != null
            ? MacrosSection(recipe: _currentRecipe!)
            : Container(),
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
        child: _buildRatingBreakdown(averageRating, ratingsCount, ratingCounts),
      ),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: _buildCommentsList(),
      ),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: SimilarRecipesSection(recipeId: recipeId),
      ),
      const SizedBox(height: 32),
    ];
  }

  Widget _buildImageSection(Map<String, dynamic> recipeData) {
    String imageUrl = recipeData['imageUrl'] ?? '';
    String title = recipeData['title'] ?? '';
    String authorId = recipeData['authorId'] ?? '';
    String authorName = _authorName ?? 'Loading author...';
    int ingredientsCount = recipeData['ingredients']?.length ?? 0;
    int stepsCount = recipeData['cookingSteps']?.length ?? 0;
    int cookingTime = recipeData['totalTime'] ?? 0;

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
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  progressIndicatorBuilder: (context, url, downloadProgress) =>
                      CircularProgressIndicator(
                          value: downloadProgress.progress),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                  width: double.infinity,
                  height: 350,
                  fit: BoxFit.cover,
                )
              : Image.asset(
                  imageUrl,
                  width: double.infinity,
                  height: 350,
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
                  child: Text(
                    'by $authorName',
                    style: const TextStyle(
                      color: Colors.white,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white,
                    ),
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

  Widget _buildRatingSection(double averageRating, int ratingsCount) {
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
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[900]
              : Colors.grey[200],
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
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: ingredients.length,
              itemBuilder: (context, index) {
                final ingredient = ingredients[index];
                final ingredientName =
                    ingredient['ingredient']['ingredientName'] ?? 'Unknown';
                final baseAmount = ingredient['baseAmount'] is num
                    ? (ingredient['baseAmount'] as num).toDouble()
                    : 1.0;
                final unit = ingredient['unit'] ?? '';
                final initialIngredientServings =
                    ingredient['servings']?.toDouble() ??
                        initialServings!.toDouble();

                // Calculate the total amount based on the current servings
                final totalAmount =
                    (baseAmount * currentServings) / initialIngredientServings;

                return _buildIngredientItem(totalAmount, unit, ingredientName);
              },
            );
          },
        ),
      ],
    );
  }

  Padding _buildIngredientItem(
      double totalAmount, String unit, String ingredientName) {
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
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                    return ScaleTransition(scale: animation, child: child);
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
  }

  Widget _buildInstructionsSection(List<dynamic> cookingSteps) {
    List<String> steps = cookingSteps.cast<String>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Instructions',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        ListView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: steps.length,
          itemBuilder: (context, index) {
            return ListTile(
              leading: CircleAvatar(
                child: Text('${index + 1}'),
                radius: 16,
              ),
              title: Text(steps[index]),
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

  Widget _buildRatingBreakdown(
      double averageRating, int totalRatings, Map<int, int> ratingCounts) {
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
            RatingBarIndicator(
              rating: averageRating,
              itemBuilder: (context, index) => const Icon(
                Icons.star,
                color: Colors.amber,
              ),
              itemCount: 5,
              itemSize: 14.0,
            ),
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
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: const Text('Error loading comments'),
          );
        } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: const Text('No comments yet. Be the first to comment!'),
          );
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
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final commentData = snapshot.data!.docs[index].data()
                        as Map<String, dynamic>;
                    double rating = commentData['rating']?.toDouble() ?? 0.0;
                    return BuildComment(
                        commentData: commentData, rating: rating);
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
