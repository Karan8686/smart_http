import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';

/// Mock HTTP client for testing.
class MockHttpClient extends Mock implements http.Client {}

/// Helper to create a mock response.
http.Response createMockResponse({
  int statusCode = 200,
  String body = '{"message": "ok"}',
  Map<String, String>? headers,
}) =>
    http.Response(
      body,
      statusCode,
      headers: headers ?? {'content-type': 'application/json'},
    );
