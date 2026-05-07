import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:smart_http_client/smart_http_client.dart';

void main() {
  late Directory tempDir;
  late HiveCacheStore store;
  late CachePolicy policy;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('smart_http_test');
    policy = const CachePolicy(
      maxAge: Duration(hours: 1),
      maxEntries: 3,
      maxSize: 1000,
    );
    store = HiveCacheStore(boxName: 'test_box', cachePolicy: policy);
    await store.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('HiveCacheStore', () {
    test('persistence works across sessions', () async {
      final response = CachedResponse(
        url: 'https://test.com',
        statusCode: 200,
        headers: {},
        body: Uint8List.fromList([1, 2, 3]),
        cachedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      await store.set('key1', response);

      // Close and reopen
      await Hive.close();
      store = HiveCacheStore(boxName: 'test_box', cachePolicy: policy);
      await store.init(tempDir.path);

      final cached = await store.get('key1');
      expect(cached, isNotNull);
      expect(cached!.statusCode, 200);
      expect(cached.body, [1, 2, 3]);
    });

    test('LRU eviction by entry count', () async {
      final response = CachedResponse(
        url: 'url',
        statusCode: 200,
        headers: {},
        body: Uint8List(0),
        cachedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      await store.set('key1', response);
      await Future.delayed(const Duration(milliseconds: 10));
      await store.set('key2', response);
      await Future.delayed(const Duration(milliseconds: 10));
      await store.set('key3', response);
      await Future.delayed(const Duration(milliseconds: 10));

      // key1 is oldest. Set key4, should evict key1.
      await store.set('key4', response);

      expect(await store.get('key1'), isNull);
      expect(await store.get('key2'), isNotNull);
      expect(await store.get('key3'), isNotNull);
      expect(await store.get('key4'), isNotNull);
    });

    test('LRU eviction respects access time', () async {
      final response = CachedResponse(
        url: 'url',
        statusCode: 200,
        headers: {},
        body: Uint8List(0),
        cachedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      await store.set('key1', response);
      await store.set('key2', response);
      await store.set('key3', response);

      // Access key1 again, making it "recently used"
      await store.get('key1');

      // Now key2 is the oldest. Set key4, should evict key2.
      await store.set('key4', response);

      expect(await store.get('key1'), isNotNull);
      expect(await store.get('key2'), isNull);
      expect(await store.get('key3'), isNotNull);
    });

    test('stats calculation works', () async {
      final response = CachedResponse(
        url: 'test_url',
        statusCode: 200,
        headers: {'h': 'v'},
        body: Uint8List.fromList([1, 2, 3]),
        cachedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      await store.set('key1', response);
      await store.get('key1'); // Hit
      await store.get('key2'); // Miss

      final stats = await store.stats();
      expect(stats.entries, 1);
      expect(stats.hits, 1);
      expect(stats.misses, 1);
      expect(stats.size, greaterThan(0));
    });
  });
}
