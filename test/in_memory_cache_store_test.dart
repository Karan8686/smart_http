import 'package:smart_http_client/smart_http_client.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InMemoryCacheStore', () {
    late InMemoryCacheStore store;
    late CachePolicy policy;

    setUp(() {
      policy = const CachePolicy(
        maxAge: Duration(hours: 1),
        staleIfError: Duration(days: 7),
      );
      store = InMemoryCacheStore(cachePolicy: policy);
    });

    test('set and get returns cached response', () async {
      final response = http.Response('{}', 200);
      final cached = CachedResponse.fromResponse(
        response,
        policy,
        'https://api.example.com/data',
      );

      await store.set('key1', cached);
      final retrieved = await store.get('key1');

      expect(retrieved, isNotNull);
      expect(retrieved!.statusCode, 200);
    });

    test('get returns null for non-existent key', () async {
      final result = await store.get('nonexistent');
      expect(result, isNull);
    });

    test('get returns null for expired entry', () async {
      final response = http.Response('{}', 200);
      const policy = CachePolicy(maxAge: Duration(seconds: -10)); // Expired
      final cached = CachedResponse.fromResponse(response, policy, 'url');

      await store.set('expired', cached);
      final result = await store.get('expired');

      expect(result, isNull);
    });

    test('getStale returns expired entries', () async {
      final response = http.Response('{}', 200);
      const policy = CachePolicy(maxAge: Duration(seconds: -10)); // Expired
      final cached = CachedResponse.fromResponse(response, policy, 'url');

      await store.set('stale', cached);
      final result = await store.getStale('stale');

      expect(result, isNotNull);
    });

    test('invalidate clears cache', () async {
      final response = http.Response('{}', 200);
      final cached = CachedResponse.fromResponse(response, policy, 'url');

      await store.set('key1', cached);
      await store.set('key2', cached);

      await store.invalidate(null);

      expect(await store.get('key1'), isNull);
      expect(await store.get('key2'), isNull);
    });

    test('stats returns cache metrics', () async {
      final response = http.Response('{}', 200);
      final cached = CachedResponse.fromResponse(response, policy, 'url');

      await store.set('key1', cached);
      await store.get('key1'); // Cache hit

      final stats = await store.stats();
      expect(stats.hits, greaterThan(0));
      expect(stats.entries, 1);
    });

    test('respects maxEntries limit', () async {
      const smallPolicy = CachePolicy(
        maxAge: Duration(hours: 1),
        maxEntries: 2,
      );
      final smallStore = InMemoryCacheStore(cachePolicy: smallPolicy);

      final response = http.Response('{}', 200);
      final cached1 =
          CachedResponse.fromResponse(response, smallPolicy, 'url1');
      final cached2 =
          CachedResponse.fromResponse(response, smallPolicy, 'url2');
      final cached3 =
          CachedResponse.fromResponse(response, smallPolicy, 'url3');

      await smallStore.set('key1', cached1);
      await smallStore.set('key2', cached2);
      await smallStore.set('key3', cached3); // Should evict oldest

      final stats = await smallStore.stats();
      expect(stats.entries, lessThanOrEqualTo(2));
    });
  });
}
