import 'package:flutter_test/flutter_test.dart';
import 'package:smart_http_client/smart_http_client.dart';

void main() {
  group('Public API', () {
    test('all public classes are exported', () {
      // This test mainly verifies compilation of these types being available
      expect(SmartHttpClient, isNotNull);
      expect(CachePolicy, isNotNull);
      expect(CacheStore, isNotNull);
      expect(CachedResponse, isNotNull);
      expect(CacheStats, isNotNull);
      expect(InMemoryCacheStore, isNotNull);
      expect(HiveCacheStore, isNotNull);
    });

    test('SmartHttpClient.inMemory factory works', () async {
      final client = SmartHttpClient.inMemory();
      await client.init(); // No-op

      final stats = await client.cacheStats();
      expect(stats.entries, 0);
    });

    test('SmartHttpClient.withHive factory works', () async {
      final client = SmartHttpClient.withHive(boxName: 'public_api_test');
      // We don't call init here to avoid disk I/O in this specific check,
      // just verifying the instance is created correctly.
      expect(client, isA<SmartHttpClient>());
    });

    test('SmartHttpClient.cached factory works', () {
      final client = SmartHttpClient.cached();
      expect(client, isA<SmartHttpClient>());
    });
  });
}
