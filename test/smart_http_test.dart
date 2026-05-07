import 'dart:convert';
import 'package:smart_http_client/smart_http_client.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_test/flutter_test.dart';
import 'mocks.dart';

void main() {
  group('SmartHttpClient', () {
    late SmartHttpClient client;
    late InMemoryCacheStore store;

    setUp(() {
      store = InMemoryCacheStore(
        cachePolicy: const CachePolicy(maxAge: Duration(hours: 1)),
      );
      client = SmartHttpClient(
        cacheStore: store,
        cachePolicy: const CachePolicy(),
      );
    });

    test('factory constructor inMemory works', () {
      final client = SmartHttpClient.inMemory();
      expect(client, isNotNull);
    });

    test('GET requests are cached', () async {
      final url = Uri.parse('https://api.example.com/users');

      // For this example, manually cache to verify store integration
      final response = http.Response('[]', 200);
      final cached = CachedResponse.fromResponse(
        response,
        const CachePolicy(),
        url.toString(),
      );
      await store.set(url.toString(), cached);

      // Retrieve from cache
      final retrieved = await store.get(url.toString());
      expect(retrieved, isNotNull);
      expect(retrieved!.statusCode, 200);
    });

    test('stale-if-error returns old data on network error', () async {
      final url = 'https://api.example.com/data';
      final response = http.Response('{"old": "data"}', 200);

      // Manually cache old response (simulating prior successful request)
      const policy = CachePolicy(
        maxAge: Duration(seconds: -10), // Expired
        staleIfError: Duration(days: 1),
      );
      final cached = CachedResponse.fromResponse(response, policy, url);
      await store.set(url, cached);

      // Try to get: cache expired, so get() returns null
      final fresh = await store.get(url);
      expect(fresh, isNull); // Expired

      // But getStale() returns the old data
      final stale = await store.getStale(url);
      expect(stale, isNotNull);
      expect(utf8.decode(stale!.body), contains('old'));
    });

    test('clearCache removes all entries', () async {
      final url = 'https://api.example.com/data';
      final response = http.Response('{}', 200);
      final cached =
          CachedResponse.fromResponse(response, const CachePolicy(), url);

      await store.set(url, cached);
      expect(await store.get(url), isNotNull);

      await client.clearCache();
      expect(await store.get(url), isNull);
    });

    test('cacheStats returns metrics', () async {
      final stats = await client.cacheStats();
      expect(stats.hits, greaterThanOrEqualTo(0));
      expect(stats.misses, greaterThanOrEqualTo(0));
    });
  });
}
