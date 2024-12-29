import 'package:flutter/material.dart';
import 'package:food_fellas/src/typesense/typesenseClient.dart';

class SearchProvider with ChangeNotifier {
  List<Map<String, dynamic>> _recipes = [];
  bool _isLoading = false;
  String _query = '';
  Map<String, dynamic> _filters = {};

  List<Map<String, dynamic>> get recipes => _recipes;
  bool get isLoading => _isLoading;
  Map<String, dynamic> get filters => _filters;

  void updateQuery(String query) {
    _query = query;
    fetchRecipes();
  }

  void updateFilters(Map<String, dynamic> filters) {
    _filters = filters;
    fetchRecipes();
  }

  Future<void> fetchRecipes(
      {int offset = 0, int limit = 10, String? sortBy}) async {
    _isLoading = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });

    try {
      final searchParameters = {
        'q': _query,
        'query_by': 'title,tagNames,ingredientNames',
        'filter_by': _buildFilterQuery(),
        'sort_by': sortBy ?? 'averageRating:desc',
        //'per_page': limit,
        //'page': (limit > 0) ? (offset ~/ limit) + 1 : 1,
      };

      print('Search parameters: $searchParameters');

      final response = await TypesenseClient.client
          .collection('recipes')
          .documents
          .search(searchParameters);

      print('Response: $response');
      print('Hits: ${response['hits']}');
      if (offset == 0) {
        // Neue Suche: Vorherige Ergebnisse überschreiben
        _recipes = (response['hits'] as List).map<Map<String, dynamic>>((hit) {
          final document = hit['document'];
          return document is Map<String, dynamic> ? document : {};
        }).toList();
      } else {
        // Pagination: Ergebnisse anhängen
        _recipes
            .addAll((response['hits'] as List).map<Map<String, dynamic>>((hit) {
          final document = hit['document'];
          return document is Map<String, dynamic> ? document : {};
        }).toList());
      }
    } catch (e) {
      print('Error during fetch: $e');
      if (offset == 0) _recipes = [];
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

  Future<void> fetchRowRecipes(String rowKey,
      {String? sortBy, int limit = 5}) async {
    _isLoading = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });

    try {
      final searchParameters = {
        'q': _query,
        'query_by': 'title,tagNames,ingredientNames',
        'filter_by': _buildFilterQuery(),
        'sort_by': sortBy ?? 'averageRating:desc',
      };

      print('Search parameters for $rowKey: $searchParameters');

      final response = await TypesenseClient.client
          .collection('recipes')
          .documents
          .search(searchParameters);

      print('Full response: $response');
      print('Hits: ${response['hits']}');

      if (response['hits'] is int) {
        print('No matches found for $rowKey');
        _rowRecipes[rowKey] = [];
      }

      // Ensure 'hits' is a List before accessing it
      if (response['hits'] is List) {
        _rowRecipes[rowKey] =
            (response['hits'] as List).map<Map<String, dynamic>>((hit) {
          final document = hit['document'];
          return document is Map<String, dynamic> ? document : {};
        }).toList();
      } else {
        // Handle unexpected response format
        print('Unexpected response format for $rowKey: ${response['hits']}');
        _rowRecipes[rowKey] = [];
      }
    } catch (e) {
      print('Error during fetch for $rowKey: $e');
      _rowRecipes[rowKey] = [];
    }

    _isLoading = false;
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
}
