import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:food_fellas/providers/searchProvider.dart';
import 'package:food_fellas/providers/userProvider.dart';
import 'package:food_fellas/src/utils/dialog_utils.dart';
import 'package:food_fellas/src/widgets/recipeCard.dart';
import 'package:food_fellas/src/widgets/filterModal.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class RecipesListScreen extends StatefulWidget {
  /// This query points to a subcollection like "recommendations" or "interactionHistory"
  final Query? baseQuery;
  final String? title;

  /// Indicates whether we are showing a user-defined collection (array of recipe IDs)
  final bool isCollection;

  /// If isCollection = true, we need these:
  final String? collectionUserId; // The user who owns the collection
  final String? collectionId;
  final String? collectionName;
  final String? collectionEmoji;
  final bool? collectionVisibility;
  final List<String>? collectionContributors;

  RecipesListScreen({
    Key? key,
    this.baseQuery,
    this.title,
    this.isCollection = false,
    this.collectionUserId,
    this.collectionId,
    this.collectionName,
    this.collectionEmoji,
    this.collectionVisibility,
    this.collectionContributors,
  }) : super(key: key);

  @override
  _RecipesListScreenState createState() => _RecipesListScreenState();
}

class _RecipesListScreenState extends State<RecipesListScreen> {
  // Common filter variables
  Map<String, dynamic> selectedFilters = {};

  // For subcollection-based approach (Flow A)
  int pageSize = 10;
  DocumentSnapshot? lastDocument;
  bool isLoadingMore = false;
  bool hasMore = true;

  // For collection-based approach (Flow B)
  bool isLoadingCollection =
      false; // indicates we’re loading the user’s collection array
  List<String> allCollectionRecipeIds = [];
  List<String> existingContributors = [];
  int collectionIndex = 0; // so we can chunk in sets of 10 or so
  bool isFollowingCollection = false;
  int selectedStarCount = 0;

  // Merged or final data that we filter
  List<Map<String, dynamic>> allMergedData = [];
  List<Map<String, dynamic>> visibleData = [];

  String? _currentUserRole;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.isCollection && widget.collectionId != null) {
      _checkIfFollowingCollection();
    }
    if (widget.isCollection) {
      _fetchCurrentUserRole();
      _fetchCollectionInitial(); // Flow B
      // Also listen for scroll to load more chunks if needed
      _scrollController.addListener(() {
        if (_scrollController.position.pixels >=
                _scrollController.position.maxScrollExtent - 100 &&
            !isLoadingCollection &&
            hasMore) {
          _fetchCollectionPage(); // fetch the next chunk
        }
      });
    } else {
      _fetchSubcollectionDocs(); // Flow A
      // Also listen for subcollection pagination
      _scrollController.addListener(() {
        if (_scrollController.position.pixels >=
                _scrollController.position.maxScrollExtent - 100 &&
            !isLoadingMore &&
            hasMore) {
          _fetchSubcollectionDocs(); // fetch next page
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentUserRole() async {
    final userProvider = Provider.of<UserDataProvider>(context, listen: false);
    setState(() {
      _currentUserRole = userProvider.userData?['role'];
    });
  }

  // =========================
  // Flow A: Subcollection approach
  // =========================
  Future<void> _fetchSubcollectionDocs() async {
    if (widget.baseQuery == null) return;
    if (isLoadingMore || !hasMore) return;

    setState(() => isLoadingMore = true);

    Query subcollectionQuery = widget.baseQuery!;
    QuerySnapshot subcollectionSnapshot;
    if (lastDocument == null) {
      subcollectionSnapshot = await subcollectionQuery.limit(pageSize).get();
    } else {
      subcollectionSnapshot = await subcollectionQuery
          .startAfterDocument(lastDocument!)
          .limit(pageSize)
          .get();
    }

    if (subcollectionSnapshot.docs.isEmpty) {
      setState(() {
        isLoadingMore = false;
        hasMore = false;
      });
      return;
    }

    lastDocument = subcollectionSnapshot.docs.last;

    // subcollection docs -> each has a recipeId
    final subDocs = subcollectionSnapshot.docs;
    final recipeIds = <String>[];
    final subDataList = <Map<String, dynamic>>[];

    for (var doc in subDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final rid = doc.id;
      recipeIds.add(rid);
      // keep the subDoc data for merging
      subDataList.add({
        'recipeId': doc.id,
        ...data,
      });
    }

    if (recipeIds.isEmpty) {
      final filtered = _applyFiltersToAll(allMergedData, selectedFilters);
      setState(() {
        visibleData = filtered;
        isLoadingMore = false;
      });
      return;
    }

    // fetch the actual recipe docs
    final newMerged = await _fetchRecipesByIds(recipeIds, subDataList);

    // add to allMergedData
    allMergedData.addAll(newMerged);

    // apply filters
    final filtered = _applyFiltersToAll(allMergedData, selectedFilters);

    setState(() {
      visibleData = filtered;
      isLoadingMore = false;
      if (subDocs.length < pageSize) {
        hasMore = false;
      }
    });
  }

  // =========================
  // Flow B: Collection approach
  // =========================
  Future<void> _fetchCollectionInitial() async {
    log('Fetching collection initial data...');
    if (widget.collectionUserId == null || widget.collectionId == null) return;

    setState(() => isLoadingCollection = true);

    try {
      final collectionSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.collectionUserId)
          .collection('collections')
          .doc(widget.collectionId)
          .get();

      if (!collectionSnapshot.exists) {
        // Collection not found or no recipes
        setState(() {
          allCollectionRecipeIds = [];
          hasMore = false;
          isLoadingCollection = false;
          visibleData = [];
        });
        return;
      }

      final data = collectionSnapshot.data() as Map<String, dynamic>;
      List<dynamic> recipeIds = data['recipes'] ?? [];
      allCollectionRecipeIds = recipeIds.cast<String>();

      await _cleanupStaleRecipeIds(allCollectionRecipeIds);

      collectionIndex = 0; // reset
      hasMore = true;

      await _fetchCollectionPage(); // fetch first chunk of recipes
    } catch (e) {
      // handle error
      setState(() {
        existingContributors = [];
        allCollectionRecipeIds = [];
        hasMore = false;
        isLoadingCollection = false;
      });
    }
  }

  Future<void> _fetchCollectionPage() async {
    if (collectionIndex >= allCollectionRecipeIds.length) {
      setState(() {
        isLoadingCollection = false;
        hasMore = false;
      });
      return;
    }

    setState(() => isLoadingCollection = true);

    // chunk of up to 10 IDs
    final chunkSize = 10;
    final endIndex =
        (collectionIndex + chunkSize < allCollectionRecipeIds.length)
            ? collectionIndex + chunkSize
            : allCollectionRecipeIds.length;
    final chunkIds = allCollectionRecipeIds.sublist(collectionIndex, endIndex);

    // increment collectionIndex
    collectionIndex = endIndex;
    if (collectionIndex >= allCollectionRecipeIds.length) {
      hasMore = false;
    }

    // fetch the actual recipe docs
    // no subDoc data here except maybe we store the array order, but typically not
    final subDataList = List.generate(chunkIds.length, (i) {
      return <String, dynamic>{
        'arrayIndex': collectionIndex + i,
        'recipeId': chunkIds[i],
      };
    });

    final newMerged = await _fetchRecipesByIds(chunkIds, subDataList);

    // add to allMergedData
    allMergedData.addAll(newMerged);

    // apply filters
    final filtered = _applyFiltersToAll(allMergedData, selectedFilters);

    setState(() {
      visibleData = filtered;
      isLoadingCollection = false;
    });
  }

  void _checkIfFollowingCollection() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // see if there's a doc in user’s followedCollections
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('followedCollections')
        .doc(widget.collectionId)
        .get();

    setState(() {
      isFollowingCollection = doc.exists; // if doc exists => user is following
    });
  }

  Future<List<Map<String, dynamic>>> _fetchRecipesByIds(
    List<String> recipeIds,
    List<Map<String, dynamic>> subDataList,
  ) async {
    if (recipeIds.isEmpty) {
      return [];
    }

    List<Map<String, dynamic>> results = [];
    const batchLimit = 10;
    int i = 0;

    while (i < recipeIds.length) {
      final endIndex = (i + batchLimit < recipeIds.length)
          ? i + batchLimit
          : recipeIds.length;
      final batchIds = recipeIds.sublist(i, endIndex);
      i = endIndex;

      try {
        final recipesSnapshot = await FirebaseFirestore.instance
            .collection('recipes')
            .where(FieldPath.documentId, whereIn: batchIds)
            .get();

        final recipeMapById = <String, Map<String, dynamic>>{};
        for (var rDoc in recipesSnapshot.docs) {
          recipeMapById[rDoc.id] = rDoc.data() as Map<String, dynamic>;
        }

        for (var subData in subDataList) {
          final rid = subData['recipeId'];
          if (batchIds.contains(rid)) {
            final recipeDoc = recipeMapById[rid];
            if (recipeDoc != null) {
              results.add({
                'id': rid, // Add the document ID
                ...recipeDoc,
                ...subData, // Merge any additional subcollection data
              });
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error fetching recipes for batch $batchIds: $e');
        }
      }
    }

    return results;
  }

  Future<void> _cleanupStaleRecipeIds(List<String> recipeIds) async {
    // Fetch recipes by IDs in a batch.
    final snapshot = await FirebaseFirestore.instance
        .collection('recipes')
        .where(FieldPath.documentId, whereIn: recipeIds)
        .get();

    // Build a set of valid recipe IDs.
    final validIds = snapshot.docs.map((doc) => doc.id).toSet();

    // Determine stale IDs.
    final staleIds = recipeIds.where((id) => !validIds.contains(id)).toList();

    if (staleIds.isNotEmpty) {
      // Update the collection document to remove the stale IDs.
      // (Assuming your collection is stored as an array field "recipes")
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.collectionUserId)
          .collection('collections')
          .doc(widget.collectionId)
          .update({'recipes': FieldValue.arrayRemove(staleIds)});
    }
  }

  /// Filter allMergedData based on the selected filters (e.g. averageRating, tagNames, etc.)
  /// Return only the items that pass.
  List<Map<String, dynamic>> _applyFiltersToAll(
      List<Map<String, dynamic>> data, Map<String, dynamic> filters) {
    return data.where((item) {
      // averageRating >= minRating
      if (filters.containsKey('averageRating')) {
        double minRating = filters['averageRating'];
        double itemRating = (item['averageRating'] ?? 0).toDouble();
        if (itemRating < minRating) return false;
      }

      // totalTime <= cookingTimeInMinutes
      if (filters.containsKey('cookingTimeInMinutes')) {
        double maxTime = filters['cookingTimeInMinutes'];
        double recipeTime = (item['totalTime'] ?? 99999).toDouble();
        if (recipeTime > maxTime) return false;
      }

      // tagNames
      if (filters.containsKey('tagNames') &&
          (filters['tagNames'] as List).isNotEmpty) {
        List<String> requiredTags =
            (filters['tagNames'] as List).cast<String>();
        List<dynamic> docTags = item['tagNames'] ?? [];
        List<String> docTagStrings = docTags.map((e) => e.toString()).toList();
        bool hasAllTags =
            requiredTags.every((tag) => docTagStrings.contains(tag));
        if (!hasAllTags) return false;
      }

      // createdByAI
      if (filters.containsKey('createdByAI')) {
        bool neededAI = filters['createdByAI'];
        bool docIsAI = item['createdByAI'] == true;
        if (docIsAI != neededAI) return false;
      }

      if (filters.containsKey('ingredientNames') &&
          (filters['ingredientNames'] as List).isNotEmpty) {
        List<String> neededIngs =
            (filters['ingredientNames'] as List).cast<String>();

        // Correctly access the list of ingredients
        List<dynamic> docIngredients = item['ingredients'] ?? [];

        // Extract ingredient names from each ingredient map
        final docIngNames = docIngredients.map((recipeIngMap) {
          if (recipeIngMap is Map<String, dynamic>) {
            final ingredient = recipeIngMap['ingredient'];
            if (ingredient is Map<String, dynamic>) {
              return ingredient['ingredientName']?.toString() ?? '';
            }
          }
          return '';
        }).toList();

        // Check if all needed ingredients are present
        bool containsAll = neededIngs.every((ing) => docIngNames.contains(ing));
        if (!containsAll) return false;
      }
      return true; // passes all filters
    }).toList();
  }

  void _applyFilters(Map<String, dynamic> filters) {
    setState(() {
      selectedFilters = filters;
    });
    final filtered = _applyFiltersToAll(allMergedData, filters);
    setState(() {
      visibleData = filtered;
    });
  }

  void _removeFilter(String key, dynamic value) {
    setState(() {
      if (key == 'tagNames') {
        final tagList = selectedFilters['tagNames'] as List<String>?;
        tagList?.remove(value);
        if (tagList == null || tagList.isEmpty) {
          selectedFilters.remove('tagNames');
        }
      } else {
        selectedFilters.remove(key);
      }
    });

    final filtered = _applyFiltersToAll(allMergedData, selectedFilters);
    setState(() {
      visibleData = filtered;
    });
  }

  void _openFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.8,
          child: FilterModal(
            initialFilters: selectedFilters,
            onApply: (filters) {
              Navigator.pop(context);
              _applyFilters(filters);
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final actualTitle = widget.isCollection
        ? '${widget.collectionEmoji ?? ''} ${widget.collectionName ?? 'Collection'}'
        : (widget.title ?? 'Recipes');

    final User? currentUser = FirebaseAuth.instance.currentUser;
    bool isGuestUser = currentUser == null || currentUser.isAnonymous;

    if (widget.collectionVisibility == false &&
        widget.collectionUserId != FirebaseAuth.instance.currentUser?.uid) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            actualTitle,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 50, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'This collection is private.',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(actualTitle),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: _openFilterModal,
          ),
          // Show "follow" button only if it's a public collection and user isn't the owner
          if (widget.isCollection == true &&
              widget.collectionId != null &&
              widget.collectionVisibility == true &&
              widget.collectionUserId !=
                  FirebaseAuth.instance.currentUser?.uid &&
              !isGuestUser)
            IconButton(
                icon: Icon(
                  isFollowingCollection
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: isFollowingCollection ? Colors.red : null,
                ),
                onPressed: () async {
                  // Store the current state BEFORE toggling.
                  final wasFollowing = isFollowingCollection;

                  // Call the toggle function with the current state.
                  await toggleFollowCollection(
                    collectionOwnerUid: widget.collectionUserId!,
                    collectionId: widget.collectionId!,
                    currentlyFollowing: wasFollowing, // use the old state!
                  );

                  // Now update the UI to reflect the change.
                  setState(() {
                    isFollowingCollection = !wasFollowing;
                  });

                  // Show the appropriate message.
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(wasFollowing
                          ? 'Collection unfollowed'
                          : 'Collection followed'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }),
          // Show a popup menu with "Edit" and "Manage Contributors" options
          if ((widget.isCollection &&
                  _currentUserRole != null &&
                  _currentUserRole == 'admin') ||
              (widget.isCollection &&
                  widget.collectionUserId ==
                      FirebaseAuth.instance.currentUser?.uid))
            Builder(
              builder: (context) {
                final currentUser = FirebaseAuth.instance.currentUser;
                if (currentUser != null) {
                  bool isOwner = (currentUser.uid == widget.collectionUserId);
                  bool isAdmin = _currentUserRole == 'admin';

                  if (isOwner || isAdmin) {
                    return PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          showCreateCollectionDialog(
                            context,
                            initialName: widget.collectionName,
                            initialIcon: widget.collectionEmoji,
                            initialVisibility: widget.collectionVisibility,
                            collectionId: widget.collectionId,
                          );
                        } else if (value == 'manage') {
                          showManageContributorsDialog(
                            context: context,
                            ownerUid: widget.collectionUserId!,
                            collectionId: widget.collectionId!,
                            existingContributors:
                                widget.collectionContributors ?? [],
                          );
                        } else if (value == 'delete') {
                          // Show the confirmation dialog
                          if (widget.collectionId != null &&
                              widget.collectionUserId != null) {
                            showDeleteCollectionConfirmationDialog(
                              context: context,
                              ownerUid: widget.collectionUserId!,
                              collectionId: widget.collectionId!,
                            );
                          }
                        }
                      },
                      icon: Icon(Icons.more_vert),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                            leading: Icon(Icons.edit),
                            title: Text('Edit'),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'manage',
                          child: ListTile(
                            leading: Icon(Icons.group),
                            title: Text('Manage Contributors'),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(Icons.delete),
                            title: Text('Delete Collection'),
                          ),
                        ),
                      ],
                    );
                  }
                }
                return SizedBox.shrink();
              },
            ),
        ],
      ),
      floatingActionButton:
          (widget.isCollection == true && widget.collectionVisibility == true)
              ? FloatingActionButton(
                  onPressed: () {
                    final shareUrl =
                        'https://foodfellas.app/share/collection/${widget.collectionId}'
                        '?userId=${widget.collectionUserId}';
                    Share.share(
                        'Check out this collection "${widget.collectionName} ${widget.collectionEmoji}": $shareUrl');
                  },
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  child: Icon(Icons.share),
                )
              : null,
      body: Column(
        children: [
          if (selectedFilters.isNotEmpty) _buildActiveFilters(),
          Expanded(child: _buildRecipeList()),
        ],
      ),
    );
  }

  Widget _buildRecipeList() {
    // 1) Determine if we are currently loading and have zero data
    final bool isInitialLoading = widget.isCollection
        ? (isLoadingCollection && allMergedData.isEmpty)
        : (isLoadingMore && allMergedData.isEmpty);

    if (isInitialLoading) {
      // Show a center spinner ONLY for the initial load (no data yet).
      return Center(child: CircularProgressIndicator());
    }

    // 2) If we're NOT currently loading and still have zero visible recipes,
    //    show an empty message.
    final bool hasNoData = visibleData.isEmpty;
    final bool isCurrentlyLoading =
        widget.isCollection ? isLoadingCollection : isLoadingMore;
    if (!isCurrentlyLoading && hasNoData) {
      // We loaded, but there's no data to show
      return Center(
        child: Text(
          widget.isCollection
              ? 'No recipes in this collection.'
              : 'No recipes found.',
        ),
      );
    }

    // 3) Otherwise, we have some data or we are still fetching more.
    //    Show the ListView. We’ll append an extra “spinner” item at the bottom
    //    if isLoadingCollection/isLoadingMore == true and hasMore == true.
    //
    //    We also add one more item for the rating section IF it's a collection.
    //    So total items = visibleData + (loadingItem?) + (ratingSectionItem?)

    // If we’re still loading more data and `hasMore == true`,
    // we need 1 extra slot for the spinner.
    final bool showLoadingFooter =
        (isLoadingCollection || isLoadingMore) && hasMore;

    // If it’s a collection, we want 1 extra slot for rating at the very end.
    final bool isCollection = widget.isCollection;
    final bool showRatingSection =
        isCollection && allCollectionRecipeIds.isNotEmpty;

    final totalItemCount = visibleData.length +
        (showLoadingFooter ? 1 : 0) +
        (showRatingSection ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      itemCount: totalItemCount,
      itemBuilder: (context, index) {
        // A) If within visibleData range, return a recipe card
        if (index < visibleData.length) {
          final recipeMap = visibleData[index];
          final recipeId = recipeMap['id'] as String;
          return RecipeCard(
            key: ValueKey(recipeId),
            big: true,
            recipeData: recipeMap,
          );
        }

        // B) If we still have the rating section to place,
        //    check if this index is the rating section slot
        final ratingSectionIndex = visibleData.length;
        if (showRatingSection && index == ratingSectionIndex) {
          return _buildRatingSection();
        }

        // C) Otherwise, it must be the loading footer item
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }

  Widget _buildActiveFilters() {
    final chips = <Widget>[];

    if (selectedFilters.containsKey('averageRating')) {
      final rating = selectedFilters['averageRating'];
      chips.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Chip(
            label: Text('Rating ≥ $rating ⭐'),
            onDeleted: () => _removeFilter('averageRating', rating),
          ),
        ),
      );
    }

    if (selectedFilters.containsKey('cookingTimeInMinutes')) {
      final timeVal = selectedFilters['cookingTimeInMinutes'];
      chips.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Chip(
            label: Text('Time ≤ $timeVal mins ⏱️'),
            onDeleted: () => _removeFilter('cookingTimeInMinutes', timeVal),
          ),
        ),
      );
    }

    if (selectedFilters.containsKey('tagNames')) {
      final List<String> tags =
          (selectedFilters['tagNames'] as List).cast<String>();
      for (var tag in tags) {
        chips.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Chip(
              label: Text(tag),
              onDeleted: () => _removeFilter('tagNames', tag),
            ),
          ),
        );
      }
    }

    if (selectedFilters.containsKey('ingredientNames')) {
      final List<String> ings =
          (selectedFilters['ingredientNames'] as List).cast<String>();
      for (var ing in ings) {
        chips.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Chip(
              label: Text(ing),
              onDeleted: () => _removeFilter('ingredientNames', ing),
            ),
          ),
        );
      }
    }

    if (selectedFilters.containsKey('createdByAI')) {
      final bool createdAI = selectedFilters['createdByAI'];
      if (createdAI) {
        chips.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Chip(
              label: Text('AI-assisted 🤖'),
              onDeleted: () => _removeFilter('createdByAI', createdAI),
            ),
          ),
        );
      }
    }
    return Container(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: chips,
      ),
    );
  }

  Widget _buildRatingSection() {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isGuestUser = currentUser == null || currentUser.isAnonymous;
    final isOwner = widget.collectionUserId == currentUser?.uid;
    final isContributor =
        widget.collectionContributors?.contains(currentUser?.uid) ?? false;

    if (isOwner ||
        isContributor ||
        allCollectionRecipeIds.isEmpty ||
        isGuestUser) {
      return SizedBox.shrink(); // Hide rating section for owners/contributors
    }

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
              'Rate this Collection!',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.collectionUserId)
                  .collection('collections')
                  .doc(widget.collectionId)
                  .collection('ratings')
                  .doc(currentUser?.uid)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                double initialRating = 0;
                if (snapshot.data != null && snapshot.data!.exists) {
                  initialRating = (snapshot.data!['rating'] ?? 0).toDouble();
                }

                return Center(
                  child: RatingBar.builder(
                    initialRating: initialRating,
                    minRating: 1,
                    direction: Axis.horizontal,
                    allowHalfRating: false,
                    itemCount: 5,
                    itemSize: 40.0,
                    itemBuilder: (context, _) => const Icon(
                      Icons.star,
                      color: Colors.amber,
                    ),
                    onRatingUpdate: (rating) async {
                      await rateCollection(
                        collectionOwnerUid: widget.collectionUserId!,
                        collectionId: widget.collectionId!,
                        rating: rating,
                      );
                      setState(() {}); // Rebuild to reflect the updated rating
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
