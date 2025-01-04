import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class TextEmbeddingModel {
  final String _apiEndpoint =
      "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent";
  final String _apiKey; // Store your API key securely

  TextEmbeddingModel() : _apiKey = dotenv.env['GEMINI_API_KEY']!;

  Future<List<double>> generateEmbedding(String text) async {
    final url = Uri.parse("$_apiEndpoint?key=$_apiKey");
    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "model": "models/text-embedding-004",
        "content": {
          "parts": [
            {"text": text}
          ]
        }
      }),
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);

      // Extract the embedding values from the response
      final List<double> embeddingValues =
          List<double>.from(jsonResponse['embedding']['values']);
      return embeddingValues;
    } else {
      throw Exception("Failed to generate embedding: ${response.body}");
    }
  }
}
