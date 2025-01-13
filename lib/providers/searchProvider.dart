import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:food_fellas/src/typesense/typesenseClient.dart';

// Possible toggle states
enum SearchMode {
  users,
  recipes,
  both,
}

class SearchProvider with ChangeNotifier {
  List<Map<String, dynamic>> _recipes = [];
  List<Map<String, dynamic>> _users = [];
  SearchMode _searchMode = SearchMode.both;
  bool _isLoading = false;
  String _query = '';
  Map<String, dynamic> _filters = {};
  String _sortBy = 'averageRating:desc';
  List<Map<String, dynamic>> _similarRecipes = [];
  bool _isLoadingSimilarRecipes = false;

  List<Map<String, dynamic>> get recipes => _recipes;
  List<Map<String, dynamic>> get users => _users;
  SearchMode get searchMode => _searchMode;
  bool get isLoading => _isLoading;
  Map<String, dynamic> get filters => _filters;
  String get sortBy => _sortBy;
  List<Map<String, dynamic>> get similarRecipes => _similarRecipes;
  bool get isLoadingSimilarRecipes => _isLoadingSimilarRecipes;

  void updateQuery(String query) {
    _query = query;
    fetchRecipes();
  }

  void updateFilters(Map<String, dynamic> filters) {
    _filters = filters;
    fetchRecipes();
  }

  void setSearchMode(SearchMode mode) {
    _searchMode = mode;
    notifyListeners();
  }

  void setSortOrder(String newSort) {
    _sortBy = newSort;
    // If you want to refetch immediately:
    fetchRecipes(offset: 0, limit: 10);
    notifyListeners();
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
      //print('searchParams => $queryParams');
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
      print('Error during fetchRecipes: $e');
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
      print('Error during multiSearch: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchUsers(String query) async {
    _isLoading = true;
    _users = [];
    notifyListeners();

    try {
      final Map<String, String> queryParams = {
        'q': query.isNotEmpty ? query : '*',
        'query_by': 'display_name',
        'page': '1',
        'per_page': '5',
      };

      final response = await TypesenseHttpClient.get(
        '/collections/users/documents/search',
        queryParams,
      );
      final hits = response['hits'] as List<dynamic>;
      _users =
          hits.map((hit) => hit['document'] as Map<String, dynamic>).toList();
    } catch (e) {
      print('Error fetching users: $e');
      _users = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Map<String, List<Map<String, dynamic>>> _rowRecipes = {
    'recommended': [],
    'newRecipes': [],
    'popular': [],
    'topRated': [],
  };

  Map<String, List<Map<String, dynamic>>> get rowRecipes => _rowRecipes;

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
      print('Error during fetchRowRecipes($rowKey): $e');
      _rowRecipes[rowKey] = [];
    }

    _isLoading = false;
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
      //print('Fuzzy Search Query: $query');

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
      print('Error fetching fuzzy recipes: $e');
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
      // For array filters, you can use ':=', ':[...], etc. depending on your indexing.
      // This means at least one of the specified tags must be present.
      // If you want all tags, you might need a different approach.
      // Example: tagNames:=[tag1,tag2]
      String tags = _filters['tagNames'].map((t) => t.toString()).join(',');
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

    print('fetchSimilarRecipes');
    try {
      _similarRecipes = await TypesenseHttpClient.fetchSimilarRecipes(
          embedding, 3); // Fetch top 3 similar recipes
    } catch (e) {
      print('Error fetching similar recipes: $e');
      _similarRecipes = [];
    }

    _isLoadingSimilarRecipes = false;
    notifyListeners();
  }

  Future<void> fetchSimilarRecipesById(String recipeId) async {
    _isLoadingSimilarRecipes = true;
    notifyListeners();
    print('fetchSimilarRecipesById with recipeId: $recipeId');
    try {
      _similarRecipes = await TypesenseHttpClient.fetchSimilarRecipesById(
          recipeId); // Fetch top 4 similar recipes
    } catch (e) {
      print('Error fetching similar recipes: $e');
      _similarRecipes = [];
    }

    _isLoadingSimilarRecipes = false;
    notifyListeners();
  }
}
