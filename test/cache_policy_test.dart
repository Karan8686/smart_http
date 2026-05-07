import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smart_http_client/smart_http_client.dart';

void main() {
  group('CachePolicy', () {
    test('default policy has 1-hour maxAge', () {
      const policy = CachePolicy();
      expect(policy.maxAge, const Duration(hours: 1));
    });

    test('copyWith creates new instance', () {
      const policy = CachePolicy();
      final newPolicy = policy.copyWith(
        maxAge: const Duration(minutes: 30),
      );
      expect(newPolicy.maxAge, const Duration(minutes: 30));
      expect(policy.maxAge, const Duration(hours: 1)); // Original unchanged
    });

    test('respects maxSize and maxEntries', () {
      const policy = CachePolicy(
        maxSize: 5 * 1024 * 1024,
        maxEntries: 100,
      );
      expect(policy.maxSize, 5 * 1024 * 1024);
      expect(policy.maxEntries, 100);
    });

    test('getExpiryDuration uses Cache-Control header', () {
      final response = http.Response(
        '{}',
        200,
        headers: {'cache-control': 'max-age=3600'},
      );

      const policy = CachePolicy(
        maxAge: Duration(hours: 1),
        respectCacheControl: true,
      );

      final duration = policy.getExpiryDuration(response);
      expect(duration, const Duration(seconds: 3600));
    });

    test('falls back to maxAge when no Cache-Control header', () {
      final response = http.Response('{}', 200);
      const policy = CachePolicy(maxAge: Duration(hours: 2));

      final duration = policy.getExpiryDuration(response);
      expect(duration, const Duration(hours: 2));
    });

    test('shouldUseStale returns true within window', () {
      const policy = CachePolicy(
        staleIfError: Duration(days: 7),
      );

      final cachedAt = DateTime.now().subtract(const Duration(days: 3));
      expect(
        policy.shouldUseStale(cachedAt, DateTime.now()),
        true,
      );
    });

    test('shouldUseStale returns false outside window', () {
      const policy = CachePolicy(
        staleIfError: Duration(days: 7),
      );

      final cachedAt = DateTime.now().subtract(const Duration(days: 10));
      expect(
        policy.shouldUseStale(cachedAt, DateTime.now()),
        false,
      );
    });
  });
}
