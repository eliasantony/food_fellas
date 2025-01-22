import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TypesenseHttpClient {
  static const String _baseUrl = 'https://typesense.foodfellas.app';
  static final String _apiKey = dotenv.env['TYPESENSE_API_KEY']!;

  // Generic GET
  static Future<Map<String, dynamic>> get(
      String endpoint, Map<String, String> queryParams) async {
    final uri =
        Uri.parse('$_baseUrl$endpoint').replace(queryParameters: queryParams);
    final response = await http.get(
      uri,
      headers: {
        'X-TYPESENSE-API-KEY': _apiKey,
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(
          'HTTP GET Error ${response.statusCode}: ${response.body}');
    }
  }

  // Generic POST
  static Future<http.Response> post(String endpoint, dynamic body) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    final response = await http.post(
      url,
      headers: {
        'X-TYPESENSE-API-KEY': _apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    return response;
  }

  // Vector Search for Similar Recipes
  static Future<List<Map<String, dynamic>>> fetchSimilarRecipes(
      List<double> embeddings, int numNeighbors) async {
    final url = Uri.parse('$_baseUrl/collections/recipes/documents/search');
    final response = await http.post(
      url,
      headers: {
        'X-TYPESENSE-API-KEY': _apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "q": "*", // Matches all recipes
        "vector_query": "embeddings:(${embeddings.join(",")}, k:$numNeighbors)",
        "exclude_fields":
            "embeddings", // Optional, excludes embedding in response
      }),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> result = jsonDecode(response.body);
      final hits = result['hits'] as List;
      return hits
          .map((hit) => hit['document'] as Map<String, dynamic>)
          .toList();
    } else {
      throw Exception(
          'HTTP POST Error ${response.statusCode}: ${response.body}');
    }
  }

  // Vector Search for Similar Recipes by Id
  static Future<List<Map<String, dynamic>>> fetchSimilarRecipesById(
      String recipeId) async {
    final url = Uri.parse('$_baseUrl/multi_search');
    final response = await http.post(
      url,
      headers: {
        'X-TYPESENSE-API-KEY': _apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "searches": [
          {
            "collection": "recipes",
            "q": "*",
            "per_page": 4,
            "vector_query": "embeddings:([], id: $recipeId, k: 4)",
            "exclude_fields": "embeddings",
          }
        ]
      }),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> result = jsonDecode(response.body);
      final results = result['results'];
      if (results is List) {
        final first = results.first;
        print(first);
        final hits = first['hits'];
        if (hits is List) {
          return hits
              .map((hit) => hit['document'] as Map<String, dynamic>)
              .toList();
        } else {
          throw Exception('Expected hits to be a List');
        }
      } else {
        throw Exception('Expected results to be a List');
      }
    } else {
      throw Exception(
          'HTTP POST Error ${response.statusCode}: ${response.body}');
    }
  }
}
