import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:food_fellas/providers/searchProvider.dart';
import 'package:food_fellas/src/models/recipe.dart';
import 'package:food_fellas/src/services/in_app_review_service.dart';
import 'package:food_fellas/src/views/addRecipeForm/addRecipe_form.dart';
import 'package:food_fellas/src/widgets/multi_photoview_screen.dart';
import 'package:food_fellas/src/widgets/photoview_screen.dart';
import 'package:food_fellas/src/views/profile_screen.dart';
import 'package:food_fellas/src/views/shoppingList_screen.dart';
import 'package:food_fellas/src/widgets/build_comment.dart';
import 'package:food_fellas/src/widgets/macros_section.dart';
import 'package:food_fellas/src/widgets/similarRecipes_section.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';
import 'package:food_fellas/providers/recipeProvider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:food_fellas/src/utils/dialog_utils.dart';
import 'package:share_plus/share_plus.dart';

class RecipeDetailScreen extends StatefulWidget {
  final String recipeId;
  final bool fromNewRecipe;

  const RecipeDetailScreen(
      {required this.recipeId, this.fromNewRecipe = false});

  @override
  _RecipeDetailScreenState createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  Map<String, dynamic>? _recipeData; // We'll store the raw data here
  bool _isLoading = true;
  Recipe? _currentRecipe;
  String? _authorName;
  String _userRole = 'user';
  int? servings;
  int? initialServings;
  double userRating = 0.0;
  bool _hasRatingChanged = false;
  final TextEditingController _commentController = TextEditingController();
  final List<File> _attachedImages = [];
  ValueNotifier<Set<String>> shoppingListItemsNotifier =
      ValueNotifier<Set<String>>({});
  late ValueNotifier<int> servingsNotifier;
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _opacityNotifier = ValueNotifier<double>(0.0);
  bool _isMarquee = false;

  @override
  void initState() {
    super.initState();
    _fetchRecipeDoc();
    _scrollController.addListener(_handleScroll);
    servingsNotifier = ValueNotifier<int>(initialServings ?? 2);
    shoppingListItemsNotifier.value = Set<String>();
    _fetchUserRating();
    _fetchShoppingListItems();
    _fetchUserRole();
    _logRecipeView();

    if (widget.fromNewRecipe) {
      Future.delayed(Duration(seconds: 2), () {
        InAppReviewService.requestReview();
      });
    }
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
    if (user.isAnonymous) return;

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    final recipeRef =
        FirebaseFirestore.instance.collection('recipes').doc(widget.recipeId);

    // Batch for atomic updates
    WriteBatch batch = FirebaseFirestore.instance.batch();

    // Log interaction for the user
    batch.set(
      userRef.collection('interactionHistory').doc(widget.recipeId),
      {
        'recipeId': widget.recipeId,
        'viewedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // Log view for the recipe
    batch.set(
      recipeRef.collection('views').doc(user.uid),
      {
        'userId': user.uid,
        'viewedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // Update view count incrementally
    batch.update(
      recipeRef,
      {
        'viewsCount': FieldValue.increment(1),
      },
    );

    // Commit batch
    await batch.commit();

    // Limit interaction history to 20 entries
    QuerySnapshot interactionHistorySnapshot = await userRef
        .collection('interactionHistory')
        .orderBy('viewedAt', descending: true)
        .get();

    if (interactionHistorySnapshot.docs.length > 20) {
      for (int i = 20; i < interactionHistorySnapshot.docs.length; i++) {
        await interactionHistorySnapshot.docs[i].reference.delete();
      }
    }
  }

  Future<void> _fetchRecipeDoc() async {
    setState(() => _isLoading = true);
    final docSnap = await FirebaseFirestore.instance
        .collection('recipes')
        .doc(widget.recipeId)
        .get();

    if (!docSnap.exists) {
      setState(() {
        _recipeData = null;
        _isLoading = false;
      });
      return;
    }

    final data = docSnap.data() as Map<String, dynamic>;
    setState(() {
      _recipeData = data;
      _currentRecipe = Recipe.fromJson(data);
      _isLoading = false;
    });

    // If you want to do initial servings stuff once:
    if (initialServings == null && data['initialServings'] != null) {
      initialServings = data['initialServings'];
      servings = initialServings;
      servingsNotifier.value = initialServings!;
    }
  }

  void _fetchUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (user.isAnonymous) return;

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
        showSaveRecipeDialog(context, recipeId: widget.recipeId);
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
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface),
                  ),
                ),
                ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(
                      'Delete',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onError),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
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

      final searchProvider =
          Provider.of<SearchProvider>(context, listen: false);
      searchProvider.removeRecipe(widget.recipeId);

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
    if (user == null || user.isAnonymous) {
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

  void updateRating(double rating) {
    if (!mounted) return;
    setState(() {
      userRating = rating;
      _hasRatingChanged = true;
    });

    // Submit rating in the background
    Future.microtask(() => _submitRating(rating));

    // Show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Rated this recipe with $rating stars ⭐️.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _attachPhotosToComment() async {
    // 1) Ensure the user typed some text first
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Please enter a comment first before attaching photos.')),
      );
      return;
    }

    // 2) Let user pick up to 3 photos
    //    If you only want them to pick 1 at a time, just pick 1.
    //    Or use a multi-image picker plugin. For simplicity:
    while (_attachedImages.length < 3) {
      File? file = await _pickAndCropSingleImage();
      if (file == null) {
        // user canceled picking an image
        break;
      }
      setState(() {
        _attachedImages.add(file);
      });
      // If you want to ask "Pick another one?" in a dialog, you can do so.
      // Otherwise, this example automatically loops.
      if (_attachedImages.length >= 3) break;
    }
  }

  Future<void> _submitComment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to submit a comment or photo.'),
        ),
      );
      return;
    }

    final commentText = _commentController.text.trim();

    // 1) Disallow empty text + no images
    if (commentText.isEmpty && _attachedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Please type a comment or attach photos before sending.'),
        ),
      );
      return;
    }

    // 2) Upload any attached images
    List<String> photoUrls = [];
    for (File img in _attachedImages) {
      String url = await _uploadFileToStorage(
        recipeId: widget.recipeId,
        file: img,
      );
      photoUrls.add(url);
    }

    // 3) Retrieve user info
    final userData = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    String userName = userData.data()?['display_name'] ?? 'Anonymous';

    // 4) Prepare comment doc
    final commentDoc = {
      'userId': user.uid,
      'userName': userName,
      'comment': commentText,
      'timestamp': FieldValue.serverTimestamp(),
      'rating': userRating > 0 ? userRating : null,
      'photos': photoUrls,
      'recipeId': widget.recipeId,
    };

    // 5) Add comment doc
    await FirebaseFirestore.instance
        .collection('recipes')
        .doc(widget.recipeId)
        .collection('comments')
        .add(commentDoc);

    // If rating changed
    if (_hasRatingChanged) {
      await _submitRating(userRating);
      _hasRatingChanged = false;
    }

    // 6) Clear the text and the local attached images
    _commentController.clear();
    setState(() {
      _attachedImages.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Comment submitted successfully.')),
    );
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
        action: SnackBarAction(
          label: "View",
          onPressed: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => ShoppingListScreen()));
          },
        ),
        content: Row(
          children: [
            const Icon(Icons.add_shopping_cart_rounded, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$ingredientName added to your shopping list.',
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
                Expanded(
                  child: Text(
                    '$ingredientName removed from your shopping list.',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        await docRef.update({'amount': newAmount});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.remove_shopping_cart_outlined,
                    color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$ingredientName removed from your shopping list.',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
  }

  bool _canEditOrDelete(Map<String, dynamic> map) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    return userId != null &&
        (_recipeData?['authorId'] == userId || _userRole == 'admin');
  }

  // _buildPopupMenuItems
  List<PopupMenuEntry<String>> _buildPopupMenuItems(bool isSaved) {
    List<PopupMenuEntry<String>> items = [];

    if (_canEditOrDelete(_recipeData!)) {
      items.add(
        PopupMenuItem<String>(
          value: 'save',
          child: Consumer<RecipeProvider>(
            builder: (context, recipeProvider, child) {
              return ListTile(
                leading: Icon(
                  isSaved ? Icons.bookmark : Icons.bookmark_border,
                  color: isSaved
                      ? Colors.green
                      : Theme.of(context).colorScheme.onSurface,
                ),
                title: Text(isSaved ? 'Unsave Recipe' : 'Save Recipe'),
              );
            },
          ),
        ),
      );
      items.add(
        PopupMenuItem<String>(
          value: 'edit',
          child: ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit Recipe'),
          ),
        ),
      );
      items.add(
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
      );
    }

    return items;
  }

  // _buildOptionsMenuOrSave
  Widget _buildOptionsMenuOrSave({
    required Map<String, dynamic> recipeData,
    required bool isSaved,
    required double opacity,
    required bool canEditOrDelete,
  }) {
    if (canEditOrDelete) {
      return PopupMenuButton<String>(
        icon: Icon(
          Icons.more_vert,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black,
        ),
        onSelected: _handleMenuOption,
        itemBuilder: (BuildContext context) {
          return _buildPopupMenuItems(isSaved);
        },
      );
    } else {
      return IconButton(
        icon: Icon(
          isSaved ? Icons.bookmark : Icons.bookmark_border,
          color: isSaved
              ? Colors.green
              : Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
        ),
        onPressed: () => showSaveRecipeDialog(
          context,
          recipeId: widget.recipeId,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipeProvider = Provider.of<RecipeProvider>(context);
    bool isSaved = recipeProvider.isRecipeSaved(widget.recipeId);

    final currentUser = FirebaseAuth.instance.currentUser;
    bool isGuestUser = currentUser == null || currentUser.isAnonymous;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        onPressed: () {
          final recipeUrl =
              'https://foodfellas.app/share/recipe/${widget.recipeId}';
          Share.share(
            'Check out this recipe: ${_currentRecipe?.title ?? 'Untitled'}\n$recipeUrl',
          );
        },
        child: const Icon(Icons.share, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchRecipeDoc, // Pull-to-refresh calls _fetchRecipeDoc()
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _recipeData == null
                ? const Center(child: Text('Recipe not found'))
                : NestedScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    headerSliverBuilder:
                        (BuildContext context, bool innerBoxIsScrolled) {
                      return <Widget>[
                        SliverAppBar(
                          expandedHeight: 250.0,
                          floating: false,
                          pinned: true,
                          automaticallyImplyLeading: false,
                          flexibleSpace: LayoutBuilder(
                            builder: (BuildContext context,
                                BoxConstraints constraints) {
                              double appBarHeight = constraints.biggest.height;
                              double opacity = (_scrollController.offset) /
                                  (250.0 - kToolbarHeight);
                              opacity = opacity.clamp(0.0, 1.0);

                              return Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Image Section
                                  _buildImageSection(_recipeData!),
                                  // Overlay Back and Options button over the image
                                  Positioned(
                                    top: MediaQuery.of(context).padding.top,
                                    left: 4.0,
                                    right: 4.0,
                                    child: SizedBox(
                                      height: kToolbarHeight,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          // Back button
                                          CircleAvatar(
                                            backgroundColor: Colors.white70,
                                            child: IconButton(
                                              icon:
                                                  const Icon(Icons.arrow_back),
                                              color: Colors.black
                                                  .withOpacity(1.0 - opacity),
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                            ),
                                          ),
                                          // Options Menu or Save Button
                                          _buildOptionsMenuOrSave(
                                            recipeData: _recipeData!,
                                            isSaved: isSaved,
                                            opacity: opacity,
                                            canEditOrDelete:
                                                _canEditOrDelete(_recipeData!),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // AppBar Title and Buttons when scrolled
                                  Positioned(
                                    top: 0.0,
                                    left: 0.0,
                                    right: 0.0,
                                    child: ValueListenableBuilder<double>(
                                      valueListenable: _opacityNotifier,
                                      builder: (context, valueOpacity, child) {
                                        return AnimatedOpacity(
                                          duration:
                                              const Duration(milliseconds: 0),
                                          opacity: valueOpacity,
                                          child: Container(
                                            color: Theme.of(context)
                                                .scaffoldBackgroundColor,
                                            height: MediaQuery.of(context)
                                                    .padding
                                                    .top +
                                                kToolbarHeight,
                                            child: Column(
                                              children: [
                                                SizedBox(
                                                    height:
                                                        MediaQuery.of(context)
                                                            .padding
                                                            .top),
                                                SizedBox(
                                                  height: kToolbarHeight,
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      IconButton(
                                                        icon: const Icon(
                                                            Icons.arrow_back),
                                                        color: Theme.of(context)
                                                                    .brightness ==
                                                                Brightness.dark
                                                            ? Colors.white
                                                            : Colors.black,
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context),
                                                      ),
                                                      Expanded(
                                                        child: GestureDetector(
                                                          onLongPress: () =>
                                                              setState(() =>
                                                                  _isMarquee =
                                                                      true),
                                                          onLongPressUp: () =>
                                                              setState(() =>
                                                                  _isMarquee =
                                                                      false),
                                                          child: _isMarquee
                                                              ? Marquee(
                                                                  text:
                                                                      _currentRecipe!
                                                                          .title,
                                                                  style:
                                                                      TextStyle(
                                                                    color: Theme.of(context).brightness ==
                                                                            Brightness
                                                                                .dark
                                                                        ? Colors
                                                                            .white
                                                                        : Colors
                                                                            .black,
                                                                    fontSize:
                                                                        20.0,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                  ),
                                                                  blankSpace:
                                                                      20.0,
                                                                  velocity:
                                                                      40.0,
                                                                )
                                                              : Text(
                                                                  _currentRecipe!
                                                                      .title,
                                                                  style:
                                                                      TextStyle(
                                                                    color: Theme.of(context).brightness ==
                                                                            Brightness
                                                                                .dark
                                                                        ? Colors
                                                                            .white
                                                                        : Colors
                                                                            .black,
                                                                    fontSize:
                                                                        20.0,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                  ),
                                                                  maxLines: 1,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                  textAlign:
                                                                      TextAlign
                                                                          .center,
                                                                ),
                                                        ),
                                                      ),
                                                      if (_canEditOrDelete(
                                                              _recipeData!) &&
                                                          !isGuestUser)
                                                        PopupMenuButton<String>(
                                                          icon: Icon(
                                                            Icons.more_vert,
                                                            color: Theme.of(context)
                                                                        .brightness ==
                                                                    Brightness
                                                                        .dark
                                                                ? Colors.white
                                                                : Colors.black,
                                                          ),
                                                          onSelected:
                                                              _handleMenuOption,
                                                          itemBuilder:
                                                              (BuildContext
                                                                  context) {
                                                            return _buildPopupMenuItems(
                                                                isSaved);
                                                          },
                                                        )
                                                      else if (!isGuestUser)
                                                        IconButton(
                                                          icon: Icon(
                                                            isSaved
                                                                ? Icons.bookmark
                                                                : Icons
                                                                    .bookmark_border,
                                                          ),
                                                          color: isSaved
                                                              ? Colors.green
                                                              : Theme.of(
                                                                      context)
                                                                  .colorScheme
                                                                  .onSurface,
                                                          onPressed: () =>
                                                              showSaveRecipeDialog(
                                                            context,
                                                            recipeId:
                                                                widget.recipeId,
                                                          ),
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
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      children: [
                        ..._buildRecipeDetail(_recipeData!, isGuestUser),
                        // Then place the SimilarRecipesSection at the end:
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child:
                              SimilarRecipesSection(recipeId: widget.recipeId),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  List<Widget> _buildRecipeDetail(
      Map<String, dynamic> recipeData, bool isGuestUser) {
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
      // Views Section
      Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child: _buildViewsSection(recipeData['viewsCount'] ?? 0),
      ),
      // Rating Section
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildRatingSection(averageRating, ratingsCount),
            const SizedBox(height: 16),
            // Description
            Text(
              description,
              textAlign: TextAlign.center,
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
      if (!isGuestUser) ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: _buildRatingAndCommentsSection(),
        ),
        const SizedBox(height: 16),
      ],
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: _buildRatingBreakdown(),
      ),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: _buildCommentsAndPhotos(),
      ),
      const SizedBox(height: 16),
    ];
  }

  Widget _buildImageSection(Map<String, dynamic> recipeData) {
    String? imageUrl = recipeData['imageUrl']; // Allow null to validate later
    String title = recipeData['title'] ?? '';
    int ingredientsCount = recipeData['ingredients']?.length ?? 0;
    int stepsCount = recipeData['cookingSteps']?.length ?? 0;
    int cookingTime = recipeData['totalTime'] ?? 0;
    String authorName = recipeData['authorName'] ?? 'Unknown author';

    // Validate the imageUrl
    bool isValidImageUrl(String? url) {
      return url != null &&
          url.isNotEmpty &&
          (url.startsWith('http') || url.startsWith('https'));
    }

    return Stack(
      children: [
        // Recipe Image
        GestureDetector(
          onTap: isValidImageUrl(imageUrl)
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          PhotoViewScreen(imageUrl: imageUrl!),
                    ),
                  );
                }
              : null,
          child: isValidImageUrl(imageUrl)
              ? CachedNetworkImage(
                  imageUrl: imageUrl!,
                  progressIndicatorBuilder: (context, url, downloadProgress) =>
                      SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                        value: downloadProgress.progress),
                  ),
                  errorWidget: (context, url, error) => const Icon(
                    Icons.broken_image,
                    size: 80,
                    color: Colors.grey,
                  ),
                  width: double.infinity,
                  height: 350,
                  fit: BoxFit.cover,
                )
              : Image.asset(
                  'lib/assets/images/dinner-placeholder.png', // Your placeholder image asset
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Author Name
                Consumer<RecipeProvider>(
                  builder: (context, recipeProvider, child) {
                    final recipeData =
                        recipeProvider.recipesCache[widget.recipeId];
                    final authorName =
                        recipeData?['authorName'] ?? 'Loading author...';
                    return GestureDetector(
                      onTap: () {
                        // Navigate to the author's profile
                        final authorId = recipeData?['authorId'];
                        if (authorId != null &&
                            authorId.toString().isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProfileScreen(
                                userId: authorId,
                              ),
                            ),
                          );
                        }
                      },
                      child: Text(
                        'by $authorName',
                        style: const TextStyle(
                          decoration: TextDecoration.underline,
                          decorationStyle: TextDecorationStyle.solid,
                          decorationColor: Colors.white,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
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

  Widget _buildViewsSection(int viewsCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.remove_red_eye, color: Colors.grey, size: 16),
        const SizedBox(width: 4),
        Text('$viewsCount views',
            style: const TextStyle(
                color: Colors.grey, fontWeight: FontWeight.bold)),
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
        SizedBox(
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
    final currentUser = FirebaseAuth.instance.currentUser;
    bool isGuestUser = currentUser == null || currentUser.isAnonymous;
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
            child: isGuestUser
                ? SizedBox
                    .shrink() // or return a disabled icon/button if you prefer
                : ValueListenableBuilder<Set<String>>(
                    valueListenable: shoppingListItemsNotifier,
                    builder: (context, shoppingListItems, _) {
                      bool isInShoppingList =
                          shoppingListItems.contains(ingredientName);

                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
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
                radius: 16,
                child: Text('${index + 1}'),
              ),
              title: Text(steps[index]),
            );
          },
        ),
      ],
    );
  }

  Future<File?> _pickAndCropSingleImage() async {
    final picker = ImagePicker();
    final XFile? pickedFile =
        await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return null; // user canceled

    // Crop
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      compressFormat: ImageCompressFormat.png,
      compressQuality: 80,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: Colors.green,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: false,
        ),
        IOSUiSettings(title: 'Crop Image'),
      ],
    );

    if (croppedFile == null) return null; // user canceled cropping
    File compressedImage = File(croppedFile.path);
    return compressedImage;
  }

  Future<String> _uploadFileToStorage({
    required String recipeId,
    required File file,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("User not logged in");
    }
    final storageRef = FirebaseStorage.instance.ref(
        'recipeImages/$recipeId/${DateTime.now().millisecondsSinceEpoch}.png');

    final uploadTask = storageRef.putFile(file);
    final snapshot = await uploadTask.whenComplete(() => {});
    return snapshot.ref.getDownloadURL();
  }

  /// Returns how many photos the current user has in all comment docs for this recipe
  Future<int> _countUserPhotos(String recipeId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    // Get all comments for this recipe by the user
    final qs = await FirebaseFirestore.instance
        .collection('recipes')
        .doc(recipeId)
        .collection('comments')
        .where('userId', isEqualTo: user.uid)
        .get();

    int total = 0;
    for (var doc in qs.docs) {
      final data = doc.data();
      final photos = data['photos'] as List<dynamic>? ?? [];
      total += photos.length;
    }
    return total;
  }

  Widget _buildRatingAndCommentsSection() {
    final currentRating = userRating;
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
            Text(
              'How did you like this recipe?',
              style: Theme.of(context).textTheme.bodyMedium,
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
                onRatingUpdate: updateRating,
              ),
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Do you have a photo of this dish?',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            FutureBuilder<int>(
              future: _countUserPhotos(widget.recipeId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }
                final userPhotoCount = snapshot.data!;

                final isDisabled = userPhotoCount >= 3; // can't upload more

                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.add_photo_alternate,
                        color: Theme.of(context).colorScheme.onPrimary),
                    label: Text(
                      'Add Recooked Photo',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: isDisabled
                        ? null // button disabled
                        : () async {
                            // This triggers the same "pick up to 3 photos & post" flow,
                            // but we can do a simpler version that only picks 1 if you want.
                            // Then automatically post a comment doc with empty comment text.

                            // e.g.:
                            final user = FirebaseAuth.instance.currentUser;
                            if (user == null || user.isAnonymous) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'You must be logged in to upload a photo.'),
                                ),
                              );
                              return;
                            }

                            // Just pick 1 photo:
                            File? singlePhoto = await _pickAndCropSingleImage();
                            if (singlePhoto == null) return;

                            // Upload
                            String photoUrl = await _uploadFileToStorage(
                              recipeId: widget.recipeId,
                              file: singlePhoto,
                            );

                            // Build the "comment" doc with no text
                            final userData = await FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .get();
                            String userName =
                                userData.data()?['display_name'] ?? 'Anonymous';

                            await FirebaseFirestore.instance
                                .collection('recipes')
                                .doc(widget.recipeId)
                                .collection('comments')
                                .add({
                              'userId': user.uid,
                              'userName': userName,
                              'comment': '', // no text
                              'timestamp': FieldValue.serverTimestamp(),
                              'rating': null, // no rating
                              'photos': [photoUrl],
                              'photoOnly': true,
                              'recipeId': widget.recipeId,
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Photo uploaded successfully!')),
                            );
                          },
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Got something to say?',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _commentController,
              decoration: InputDecoration(
                labelText: 'Leave a comment',
                border: const OutlineInputBorder(),
                suffixIcon: Column(
                  children: [
                    IconButton(
                      icon: Icon(Icons.add_photo_alternate_outlined),
                      onPressed: _attachPhotosToComment,
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: () {
                        _submitComment();
                        FocusScope.of(context).unfocus();
                      },
                    ),
                  ],
                ),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Comment cannot be empty';
                }
                return null;
              },
              onFieldSubmitted: (value) {
                _submitComment();
                FocusScope.of(context).unfocus();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingBreakdown() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('recipes')
          .doc(widget.recipeId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        final doc = snapshot.data!;
        if (!doc.exists) return Text('Recipe not found');

        final recipeData = doc.data() as Map<String, dynamic>;
        final averageRating = (recipeData['averageRating'] ?? 0).toDouble();
        final totalRatings = recipeData['ratingsCount'] ?? 0;
        final ratingCountsMap = recipeData['ratingCounts'] ?? {};
        final Map<int, int> ratingCounts = {
          1: ratingCountsMap['1'] ?? 0,
          2: ratingCountsMap['2'] ?? 0,
          3: ratingCountsMap['3'] ?? 0,
          4: ratingCountsMap['4'] ?? 0,
          5: ratingCountsMap['5'] ?? 0,
        };

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Average Rating Section
            Column(
              children: [
                Text(
                  averageRating.toStringAsFixed(1),
                  style: const TextStyle(
                      fontSize: 48, fontWeight: FontWeight.w600),
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
      },
    );
  }

  Widget _buildCommentsAndPhotos() {
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
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Error loading comments & photos'),
          );
        } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'No comments or photos yet. Be the first to share!',
              textAlign: TextAlign.center,
            ),
          );
        } else {
          // 1) Convert all docs into a local List<Map<String,dynamic>>
          final allDocs = snapshot.data!.docs.map((doc) {
            final map = doc.data() as Map<String, dynamic>;
            map['id'] = doc.id;
            // If you want to store recipeId
            map['recipeId'] = widget.recipeId;
            return map;
          }).toList();

          // 2) Build a list of *all photos* from *all docs* (including photoOnly)
          final allPhotosList = <Map<String, dynamic>>[];
          for (final c in allDocs) {
            final photos = c['photos'] as List<dynamic>? ?? [];
            for (var url in photos) {
              allPhotosList.add({
                'imageUrl': url,
                'userName': c['userName'] ?? 'Anonymous',
                'timestamp': c['timestamp'],
                'rating': c['rating'] ?? null,
                'comment': c['comment'] ?? '',
                'commentId': c['id'],
                'userId': c['userId'],
                'recipeId': c['recipeId'],
              });
            }
          }

          // 3) Build a list of docs we want to show as text comments
          //    If we want to hide “photo-only” docs, we skip docs where
          //    comment is empty *or* photoOnly == true
          //    (some folks might rely simply on comment.isEmpty, but we’ll respect the flag)
          final commentDocs = allDocs.where((doc) {
            final text = (doc['comment'] ?? '').toString().trim();
            final isPhotoOnly = doc['photoOnly'] == true;
            return text.isNotEmpty && !isPhotoOnly;
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Heading
              Text(
                'Comments & Photos',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),

              // 4) Show the horizontal row of photos (allPhotosList)
              if (allPhotosList.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: allPhotosList.length,
                      itemBuilder: (ctx, index) {
                        final photoItem = allPhotosList[index];
                        return GestureDetector(
                          onTap: () {
                            // Open multi-photo viewer with overlay
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MultiPhotoViewScreen(
                                  photoItems: allPhotosList,
                                  initialIndex: index,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            width: 100,
                            margin: const EdgeInsets.only(right: 8.0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Theme.of(context).colorScheme.surface,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.3),
                                  spreadRadius: 1,
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: CachedNetworkImage(
                              imageUrl: photoItem['imageUrl'],
                              fit: BoxFit.cover,
                              placeholder: (ctx, _) => const Center(
                                  child: CircularProgressIndicator()),
                              errorWidget: (ctx, _, __) =>
                                  const Icon(Icons.error),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                )
              else
                const SizedBox.shrink(),

              const SizedBox(height: 16),
              // 5) Show the *text-based* comments
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Column(
                  children: [
                    ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: commentDocs.length,
                      itemBuilder: (context, index) {
                        final comment = commentDocs[index];
                        final double rating =
                            (comment['rating'] ?? userRating).toDouble();
                        debugPrint('Rating: $rating');
                        return BuildComment(
                          commentData: comment,
                          rating: rating,
                          isAdmin: _userRole == 'admin',
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        }
      },
    );
  }
}
