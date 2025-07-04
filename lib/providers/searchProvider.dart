import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:food_fellas/src/typesense/typesenseClient.dart';

// Possible toggle states
enum SearchMode {
  users,
  recipes,
  both,
}

class SearchProvider with ChangeNotifier {
  String _query = '';
  String get query => _query;

  List<Map<String, dynamic>> _recipes = [];
  List<Map<String, dynamic>> get recipes => _recipes;

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> get users => _users;

  SearchMode _searchMode = SearchMode.both;
  SearchMode get searchMode => _searchMode;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Map<String, dynamic> _filters = {};
  Map<String, dynamic> get filters => _filters;

  String _sortBy = 'averageRating:desc';
  String get sortBy => _sortBy;

  List<Map<String, dynamic>> _similarRecipes = [];
  List<Map<String, dynamic>> get similarRecipes => _similarRecipes;

  bool _isLoadingSimilarRecipes = false;
  bool get isLoadingSimilarRecipes => _isLoadingSimilarRecipes;

  final Map<String, List<Map<String, dynamic>>> _rowRecipes = {
    'recommended': [],
    'newRecipes': [],
    'popular': [],
    'topRated': [],
  };
  Map<String, List<Map<String, dynamic>>> get rowRecipes => _rowRecipes;

  final Map<String, List<Map<String, dynamic>>> _rowUsers = {
    'topChefs': [],
  };
  Map<String, List<Map<String, dynamic>>> get rowUsers => _rowUsers;

  // Store "recently viewed" and "recommended" for the home screen
  List<Map<String, dynamic>> _recentlyViewedCached = [];
  List<Map<String, dynamic>> get recentlyViewedCached => _recentlyViewedCached;

  List<Map<String, dynamic>> _recommendedCached = [];
  List<Map<String, dynamic>> get recommendedCached => _recommendedCached;

  final Map<String, Map<String, dynamic>> _userCache = {};
  Map<String, Map<String, dynamic>> get userCache => _userCache;

  bool _homeRowsFetched = false;

  void updateQuery(String query) {
    _query = query;
    _recipes = [];
    _users = [];

    if (_searchMode == SearchMode.recipes) {
      fetchRecipes();
    } else if (_searchMode == SearchMode.users) {
      fetchUsers(query);
    } else if (_searchMode == SearchMode.both) {
      fetchMultiSearch(query);
    }

    notifyListeners();
  }

  void updateFilters(Map<String, dynamic> filters) {
    _filters = filters;
    _recipes = []; // Clear previous results
    notifyListeners();
    fetchRecipes();
  }

  void setSearchMode(SearchMode mode) {
    _searchMode = mode;

    // Perform search based on the new mode
    if (_searchMode == SearchMode.recipes) {
      fetchRecipes();
    } else if (_searchMode == SearchMode.users) {
      fetchUsers(_query);
    } else if (_searchMode == SearchMode.both) {
      fetchMultiSearch(_query);
    }

    notifyListeners();
  }

  void setSortOrder(String newSort) {
    _sortBy = newSort;
    // If you want to refetch immediately:
    fetchRecipes(offset: 0, limit: 10);
    notifyListeners();
  }

  void updateRecipe(String recipeId, Map<String, dynamic> updatedData) {
    bool found = false;

    // Iterate through all home rows to update the recipe if it exists
    _rowRecipes.forEach((key, recipesList) {
      for (int i = 0; i < recipesList.length; i++) {
        if (recipesList[i]['id'] == recipeId) {
          _rowRecipes[key]?[i] = {...recipesList[i], ...updatedData};
          found = true;
        }
      }
    });

    // Update the recipe inside 'recently viewed' and 'recommended'
    for (int i = 0; i < _recentlyViewedCached.length; i++) {
      if (_recentlyViewedCached[i]['id'] == recipeId) {
        _recentlyViewedCached[i] = {
          ..._recentlyViewedCached[i],
          ...updatedData
        };
        found = true;
      }
    }

    for (int i = 0; i < _recommendedCached.length; i++) {
      if (_recommendedCached[i]['id'] == recipeId) {
        _recommendedCached[i] = {..._recommendedCached[i], ...updatedData};
        found = true;
      }
    }

    if (found) {
      notifyListeners();
    }
  }

  void removeRecipe(String recipeId) {
    bool found = false;

    // Remove from home rows
    _rowRecipes.forEach((key, recipesList) {
      _rowRecipes[key]?.removeWhere((recipe) => recipe['id'] == recipeId);
      found = true;
    });

    // Remove from recently viewed and recommended
    _recentlyViewedCached.removeWhere((recipe) => recipe['id'] == recipeId);
    _recommendedCached.removeWhere((recipe) => recipe['id'] == recipeId);

    if (found) {
      notifyListeners();
    }
  }

  Future<void> fetchRecipes({
    int offset = 0,
    int limit = 10,
    String? sortBy,
  }) async {
    _isLoading = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());

    try {
      // Convert offset/limit to page/per_page
      final page = (limit > 0) ? (offset ~/ limit) + 1 : 1;

      // Build up the query params
      final Map<String, String> queryParams = {
        'q': _query.isNotEmpty ? _query : '*',
        'query_by': 'title,tagNames,ingredientNames',
        'filter_by': _buildFilterQuery(),
        'sort_by': _sortBy,
        'page': page.toString(),
        'per_page': limit.toString(),
      };

      // Make the GET request
      final response = await TypesenseHttpClient.get(
        '/collections/recipes/documents/search',
        queryParams,
      );

      // Now parse hits
      final hits = response['hits'];
      if (hits is List) {
        if (offset == 0) {
          // Fresh search
          _recipes = hits.map<Map<String, dynamic>>((hit) {
            final doc = hit['document'] as Map<String, dynamic>;
            return doc;
          }).toList();
        } else {
          // Append for pagination
          _recipes.addAll(hits.map<Map<String, dynamic>>((hit) {
            final doc = hit['document'] as Map<String, dynamic>;
            return doc;
          }));
        }
      } else {
        if (offset == 0) {
          _recipes = [];
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during fetchRecipes: $e');
      }
      if (offset == 0) {
        _recipes = [];
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchMultiSearch(String query) async {
    _isLoading = true;
    _users = [];
    _recipes = [];
    notifyListeners();

    try {
      // Prepare multi_search body
      final requestBody = {
        "searches": [
          {
            "collection": "users",
            "q": query.isNotEmpty ? query : "*",
            "query_by": "display_name,email",
            "sort_by": "averageRating:desc",
            "per_page": 3
          },
          {
            "collection": "recipes",
            "q": query.isNotEmpty ? query : "*",
            "query_by": "title,tagNames,ingredientNames",
            "sort_by": _sortBy,
            "per_page": 10 // Or however many recipes you want
          }
        ]
      };

      final response = await TypesenseHttpClient.post(
        '/multi_search',
        requestBody,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);

        // results[0] => user search results
        // results[1] => recipe search results
        final searches = result['results'] as List<dynamic>;
        final usersResult = searches[0] as Map<String, dynamic>;
        final recipesResult = searches[1] as Map<String, dynamic>;

        final userHits = usersResult['hits'] as List<dynamic>;
        final recipeHits = recipesResult['hits'] as List<dynamic>;

        // Populate _users
        _users = userHits.map((hit) {
          return hit['document'] as Map<String, dynamic>;
        }).toList();

        // Populate _recipes
        _recipes = recipeHits.map((hit) {
          return hit['document'] as Map<String, dynamic>;
        }).toList();
      } else {
        throw Exception(
            'HTTP POST Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during multiSearch: $e');
      }
    }

    _isLoading = false;
    notifyListeners();
  }

// Inside the SearchProvider class

  Future<void> fetchUsers(String query,
      {int perPage = 20, List<String> excludeUids = const []}) async {
    _isLoading = true;
    _users = [];
    notifyListeners();

    try {
      final Map<String, String> queryParams = {
        'q': query.isNotEmpty ? query : '*',
        'query_by': 'display_name',
        'page': '1',
        'per_page': perPage.toString(),
      };

      if (excludeUids.isNotEmpty) {
        // Build the filter_by string to exclude the UIDs
        final filterBy = excludeUids.map((uid) => 'id:!=$uid').join(' && ');
        queryParams['filter_by'] = filterBy;
      }

      final response = await TypesenseHttpClient.get(
        '/collections/users/documents/search',
        queryParams,
      );

      final hits = response['hits'] as List<dynamic>;
      _users = hits.map((hit) {
        final userData = hit['document'] as Map<String, dynamic>;
        userData['uid'] = userData['id']; // Map 'id' to 'uid'
        return userData;
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching users: $e');
      }
      _users = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> fetchUserByUid(String uid) async {
    if (_userCache.containsKey(uid)) {
      return _userCache[uid];
    }

    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        data['uid'] = userDoc.id; // Add this line to include uid
        _userCache[uid] = data;
        return data;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching user by UID: $e');
      }
    }
    return null;
  }

  Map<String, dynamic>? getCachedUserByUid(String uid) {
    return _userCache[uid];
  }

  Future<void> fetchTopChefs({
    String sortBy = 'averageRating:desc,recipeCount:desc',
    int limit = 5,
  }) async {
    try {
      final Map<String, String> queryParams = {
        'q': '*',
        'query_by': 'display_name,email',
        'sort_by': sortBy,
        'page': '1',
        'per_page': limit.toString(),
      };

      final response = await TypesenseHttpClient.get(
        '/collections/users/documents/search',
        queryParams,
      );

      final hits = response['hits'];
      if (hits is List) {
        _rowUsers['topChefs'] = hits.map<Map<String, dynamic>>((hit) {
          return hit['document'] as Map<String, dynamic>;
        }).toList();
      } else {
        _rowUsers['topChefs'] = [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching top chefs: $e');
      }
      _rowUsers['topChefs'] = [];
    }

    notifyListeners();
  }

  Future<void> fetchRowRecipes(
    String rowKey, {
    String? sortBy,
    int limit = 5,
  }) async {
    _isLoading = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());

    try {
      final Map<String, String> queryParams = {
        'q': '*',
        'query_by': 'title,tagNames,ingredientNames',
        'filter_by': '',
        'sort_by': sortBy ?? 'averageRating:desc',
        'page': '1',
        'per_page': limit.toString(),
      };

      final response = await TypesenseHttpClient.get(
        '/collections/recipes/documents/search',
        queryParams,
      );

      final hits = response['hits'];
      if (hits is List) {
        _rowRecipes[rowKey] = hits.map<Map<String, dynamic>>((hit) {
          return hit['document'] as Map<String, dynamic>;
        }).toList();
      } else {
        _rowRecipes[rowKey] = [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during fetchRowRecipes($rowKey): $e');
      }
      _rowRecipes[rowKey] = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchHomeRowsOnce(String userId) async {
    if (_homeRowsFetched) return;
    // 1) Fetch row recipes that are public (available to everyone)
    await fetchRowRecipes('newRecipes', sortBy: 'createdAt:desc');
    await fetchRowRecipes('topRated',
        sortBy: 'averageRating:desc,ratingsCount:desc');
    await fetchRowRecipes('popular',
        sortBy: 'viewsCount:desc,averageRating:desc');
    await fetchRowRecipes('mostRated',
        sortBy: 'ratingsCount:desc,averageRating:desc');
    await fetchTopChefs(sortBy: 'recipeCount:desc,averageRating:desc');

    // 2) For user‑specific sections, check if the user is not anonymous
    User? currentUser = FirebaseAuth.instance.currentUser;
    final userId = currentUser?.uid ?? '';
    if (currentUser != null && !currentUser.isAnonymous) {
      _recentlyViewedCached =
          await fetchRecentlyViewedRecipes(userId, limit: 10);
      _recommendedCached = await fetchFirebaseRecommendations(userId, limit: 5);
    } else {
      // If the user is a guest, simply clear these caches.
      _recentlyViewedCached = [];
      _recommendedCached = [];
    }

    _homeRowsFetched = true;
    notifyListeners();
  }

  void invalidateHomeRows() {
    _homeRowsFetched = false;
    fetchHomeRowsOnce(FirebaseAuth.instance.currentUser?.uid ?? '');
    notifyListeners();
  }

  Future<void> fetchFuzzyRecipes({
    required String title,
    required String description,
    required List<String> ingredients,
  }) async {
    _isLoadingSimilarRecipes = true;
    notifyListeners();

    try {
      final query = "$title $description ${ingredients.join(' ')}";

      final response = await TypesenseHttpClient.get(
        '/collections/recipes/documents/search',
        {
          'q': query,
          'query_by': 'title,description,ingredientNames',
          'num_typos': '4',
          'per_page': '3',
        },
      );

      final hits = response['hits'] as List<dynamic>;
      _similarRecipes = hits.map((hit) {
        return hit['document'] as Map<String, dynamic>;
      }).toList();

      //print("Fuzzy Search Results: $_similarRecipes");
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching fuzzy recipes: $e');
      }
      _similarRecipes = [];
    }

    _isLoadingSimilarRecipes = false;
    notifyListeners();
  }

  String _buildFilterQuery() {
    List<String> filterParts = [];

    // averageRating: >= value
    if (_filters.containsKey('averageRating') &&
        _filters['averageRating'] > 0) {
      filterParts.add('averageRating:>=${_filters['averageRating']}');
    }

    // cookingTimeInMinutes <= value
    if (_filters.containsKey('cookingTimeInMinutes')) {
      filterParts.add(
          'cookingTimeInMinutes:<=${_filters['cookingTimeInMinutes'].toInt()}');
    }

    // tagNames (array query)
    if (_filters.containsKey('tagNames') && _filters['tagNames'].isNotEmpty) {
      String tags =
          _filters['tagNames'].map((t) => '"${t.toString()}"').join(',');
      filterParts.add('tagNames:=[${tags}]');
    }

    // ingredientNames (array query)
    if (_filters.containsKey('ingredientNames') &&
        _filters['ingredientNames'].isNotEmpty) {
      String ingredients =
          _filters['ingredientNames'].map((i) => i.toString()).join(',');
      filterParts.add('ingredientNames:=[${ingredients}]');
    }

    // createdByAI
    if (_filters.containsKey('createdByAI')) {
      bool value = _filters['createdByAI'];
      filterParts.add('createdByAI:=${value.toString()}');
    }

    return filterParts.join(' && ');
  }

  Future<void> fetchSimilarRecipes(List<double> embedding) async {
    _isLoadingSimilarRecipes = true;
    notifyListeners();

    try {
      _similarRecipes = await TypesenseHttpClient.fetchSimilarRecipes(
          embedding, 3); // Fetch top 3 similar recipes
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching similar recipes: $e');
      }
      _similarRecipes = [];
    }

    _isLoadingSimilarRecipes = false;
    notifyListeners();
  }

  Future<void> fetchSimilarRecipesById(String recipeId) async {
    _isLoadingSimilarRecipes = true;
    notifyListeners();
    try {
      _similarRecipes = await TypesenseHttpClient.fetchSimilarRecipesById(
          recipeId); // Fetch top 4 similar recipes
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching similar recipes by id: $e');
      }
      _similarRecipes = [];
    }

    _isLoadingSimilarRecipes = false;
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> fetchRecentlyViewedRecipes(
    String userId, {
    int limit = 5,
  }) async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.isAnonymous) return [];

    final viewedRecipes = <Map<String, dynamic>>[];
    try {
      final viewsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('interactionHistory')
          .orderBy('viewedAt', descending: true)
          .limit(limit)
          .get();

      if (viewsSnapshot.docs.isEmpty) return [];

      // For each doc, fetch the actual recipe
      for (var doc in viewsSnapshot.docs) {
        final recipeId = doc['recipeId'] as String;
        final recipeSnapshot = await FirebaseFirestore.instance
            .collection('recipes')
            .doc(recipeId)
            .get();
        if (recipeSnapshot.exists) {
          final recipeData = recipeSnapshot.data() as Map<String, dynamic>;
          recipeData['id'] = recipeSnapshot.id;
          viewedRecipes.add(recipeData);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching recently viewed recipes: $e');
      }
    }
    return viewedRecipes;
  }

  Future<List<Map<String, dynamic>>> fetchFirebaseRecommendations(
    String userId, {
    int limit = 5,
  }) async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.isAnonymous) return [];
    try {
      // 1) Get the recommended recipe IDs
      final recsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('recommendations')
          .orderBy('score', descending: true) // or createdAt
          .limit(limit)
          .get();

      if (recsSnapshot.docs.isEmpty) return [];

      // 2) For each recommendation doc, get the actual recipe doc
      final recommendedRecipes = <Map<String, dynamic>>[];
      for (var doc in recsSnapshot.docs) {
        final recipeId = doc['recipeId'];
        final recipeSnapshot = await FirebaseFirestore.instance
            .collection('recipes')
            .doc(recipeId)
            .get();
        if (recipeSnapshot.exists) {
          final recipeData = recipeSnapshot.data() as Map<String, dynamic>;
          recipeData['id'] = recipeSnapshot.id;
          recommendedRecipes.add(recipeData);
        }
      }
      return recommendedRecipes;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching user-specific recommendations: $e');
      }
      return [];
    }
  }
}
