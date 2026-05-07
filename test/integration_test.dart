import 'package:smart_http_client/smart_http_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Integration Tests (Real HTTP)', () {
    late SmartHttpClient client;

    setUp(() {
      client = SmartHttpClient.inMemory(
        cachePolicy: const CachePolicy(maxAge: Duration(minutes: 5)),
      );
    });

    test('can fetch from JSONPlaceholder API', () async {
      final response = await client.get(
        Uri.parse('https://jsonplaceholder.typicode.com/users/1'),
      );

      expect(response.statusCode, 200);
      expect(response.body, contains('Leanne'));
    });

    test('caches successful GET requests', () async {
      final url = Uri.parse('https://jsonplaceholder.typicode.com/posts/1');

      // First request
      final response1 = await client.get(url);
      expect(response1.statusCode, 200);

      // Second request should be cached
      final response2 = await client.get(url);
      expect(response2.statusCode, 200);
      expect(response2.body, response1.body); // Same content
      expect(response2.headers['X-From-Cache'], 'true');
    });

    test('respects HTTP cache headers', () async {
      // JSONPlaceholder respects cache headers
      final response = await client.get(
        Uri.parse('https://jsonplaceholder.typicode.com/posts/1'),
      );

      expect(response.statusCode, 200);
      expect(response.headers.containsKey('cache-control'), true);
    });
  });
}
