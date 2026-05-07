import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smart_http_client/smart_http_client.dart';

void main() {
  group('CachedResponse', () {
    test('serialization roundtrip works', () {
      final original = CachedResponse(
        url: 'https://example.com',
        statusCode: 200,
        headers: {'content-type': 'text/plain'},
        body: utf8.encode('Hello World'),
        cachedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      final json = original.toJson();
      final recovered = CachedResponse.fromJson(json);

      expect(recovered.url, original.url);
      expect(recovered.statusCode, original.statusCode);
      expect(recovered.headers, original.headers);
      expect(recovered.body, original.body);
      // ISO8601 parsing might lose microsecond precision depending on platform,
      // so we check if they are very close.
      expect(recovered.cachedAt.difference(original.cachedAt).inSeconds, 0);
      expect(recovered.expiresAt.difference(original.expiresAt).inSeconds, 0);
    });

    test('fromResponse extracts expiry from policy', () {
      const policy = CachePolicy(maxAge: Duration(minutes: 5));
      final response = http.Response('OK', 200, headers: {
        HttpHeaders.cacheControlHeader: 'max-age=3600',
      });

      final cached =
          CachedResponse.fromResponse(response, policy, 'https://test.com');

      expect(cached.expiresAt.difference(cached.cachedAt).inSeconds, 3600);
    });

    test('toResponse adds X-From-Cache header', () {
      final cached = CachedResponse(
        url: 'https://example.com',
        statusCode: 200,
        headers: {'Content-Type': 'application/json'},
        body: utf8.encode('{}'),
        cachedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      final response = cached.toResponse();
      expect(response.headers['X-From-Cache'], 'true');
      expect(response.headers['Content-Type'], 'application/json');
      expect(response.body, '{}');
    });

    test('isExpired works correctly', () {
      final expired = CachedResponse(
        url: '',
        statusCode: 200,
        headers: {},
        body: Uint8List(0),
        cachedAt: DateTime.now().subtract(const Duration(hours: 2)),
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );

      final fresh = CachedResponse(
        url: '',
        statusCode: 200,
        headers: {},
        body: Uint8List(0),
        cachedAt: DateTime.now().subtract(const Duration(minutes: 1)),
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      expect(expired.isExpired, true);
      expect(fresh.isExpired, false);
    });
  });
}
