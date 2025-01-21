import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:food_fellas/providers/userProvider.dart';
import 'package:food_fellas/src/utils/dialog_utils.dart';
import 'package:food_fellas/src/widgets/recipeCard.dart';
import 'package:food_fellas/src/widgets/filterModal.dart';
import 'package:provider/provider.dart';

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
  int collectionIndex = 0; // so we can chunk in sets of 10 or so

  // Merged or final data that we filter
  List<Map<String, dynamic>> allMergedData = [];
  List<Map<String, dynamic>> visibleData = [];

  String? _currentUserRole;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

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
      final rid = data['recipeId'] as String?;
      if (rid != null) {
        recipeIds.add(rid);
        // keep the subDoc data for merging
        subDataList.add({
          'subDocId': doc.id,
          ...data,
        });
      }
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

      collectionIndex = 0; // reset
      hasMore = true;

      await _fetchCollectionPage(); // fetch first chunk of recipes
    } catch (e) {
      // handle error
      setState(() {
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

  /// Helper to fetch recipes by IDs, returning a list of merged maps
  Future<List<Map<String, dynamic>>> _fetchRecipesByIds(
    List<String> recipeIds,
    List<Map<String, dynamic>> subDataList,
  ) async {
    // Because Firestore .whereIn(...) has a limit of 10, do multiple calls if needed:
    List<Map<String, dynamic>> results = [];

    // chunk recipeIds in sets of 10
    const batchLimit = 10;
    int i = 0;
    while (i < recipeIds.length) {
      final endIndex = (i + batchLimit < recipeIds.length)
          ? i + batchLimit
          : recipeIds.length;
      final batchIds = recipeIds.sublist(i, endIndex);
      i = endIndex;

      final recipesSnapshot = await FirebaseFirestore.instance
          .collection('recipes')
          .where(FieldPath.documentId, whereIn: batchIds)
          .get();

      final recipeMapById = <String, Map<String, dynamic>>{};
      for (var rDoc in recipesSnapshot.docs) {
        recipeMapById[rDoc.id] = rDoc.data() as Map<String, dynamic>;
      }

      // merge with subData
      // for each subData item, see if we have a matching recipe doc
      for (var subData in subDataList) {
        final rid = subData['recipeId'];
        if (batchIds.contains(rid)) {
          final recipeDoc = recipeMapById[rid];
          if (recipeDoc != null) {
            results.add({
              'id': rid, // main recipe doc ID
              ...recipeDoc,
              ...subData, // e.g. score, viewedAt, arrayIndex, etc.
            });
          }
        }
      }
    }

    return results;
  }

  /// Filter allMergedData based on the selected filters (e.g. averageRating, tagNames, etc.)
  /// Return only the items that pass.
  List<Map<String, dynamic>> _applyFiltersToAll(
      List<Map<String, dynamic>> data, Map<String, dynamic> filters) {
    return data.where((item) {
      // item might have fields like: { id, title, averageRating, totalTime, tagNames, createdByAI, ingredients, score, viewedAt, ... }

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
        print('Needed ings: $neededIngs');

        // Correctly access the list of ingredients
        List<dynamic> docIngredients = item['ingredients'] ?? [];
        print('Doc ings: $docIngredients');

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
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: _openFilterModal,
          ),

          // Show the "edit" collection button only if:
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
                  bool isAdmin = false;
                  if (isOwner || isAdmin) {
                    return IconButton(
                      icon: Icon(Icons.edit),
                      onPressed: () {
                        showCreateCollectionDialog(
                          context,
                          initialName: widget.collectionName,
                          initialIcon: widget.collectionEmoji,
                          initialVisibility: widget.collectionVisibility,
                          collectionId: widget.collectionId,
                        );
                      },
                    );
                  }
                }
                return SizedBox.shrink();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if (selectedFilters.isNotEmpty) _buildActiveFilters(),
          Expanded(
            child: _buildRecipeList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeList() {
    if (widget.isCollection) {
      // show collection loading or empty state
      if (isLoadingCollection && allMergedData.isEmpty) {
        return Center(child: CircularProgressIndicator());
      }
      if (!isLoadingCollection && visibleData.isEmpty) {
        return Center(child: Text('No recipes in this collection.'));
      }
    } else {
      // subcollection approach
      if (isLoadingMore && allMergedData.isEmpty) {
        return Center(child: CircularProgressIndicator());
      }
      if (!isLoadingMore && visibleData.isEmpty) {
        return Center(child: Text('No recipes found.'));
      }
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: visibleData.length +
          ((isLoadingMore || isLoadingCollection) && hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < visibleData.length) {
          final recipeMap = visibleData[index];
          final recipeId = recipeMap['id'] as String;
          return RecipeCard(
            big: true,
            recipeId: recipeId,
            // Possibly pass data along if needed
          );
        } else {
          // show loading indicator at bottom
          return Center(child: CircularProgressIndicator());
        }
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
      print('Tags: $tags');
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
      print('ingredientNames: $ings');
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
    print('chips: $chips');
    return Container(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: chips,
      ),
    );
  }
}
