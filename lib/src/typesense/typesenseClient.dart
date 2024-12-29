import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:typesense/typesense.dart';

class TypesenseClient {
  static final client = Client(
    Configuration(
      '${dotenv.env['TYPESENSE_API_KEY']}',
      nodes: {
        Node(
          Protocol.https,
          'typesense.foodfellas.app',
          port: 443,
        ),
      },
      numRetries: 3,
      connectionTimeout: const Duration(seconds: 5),
    ),
  );
}