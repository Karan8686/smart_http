import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'cache_policy.dart';

/// A data class that wraps an [http.Response] plus cache metadata.
class CachedResponse {
  CachedResponse({
    required this.url,
    required this.statusCode,
    required this.headers,
    required this.body,
    required this.cachedAt,
    required this.expiresAt,
  });

  /// Factory constructor to create a [CachedResponse] from an [http.Response].
  factory CachedResponse.fromResponse(
    http.Response response,
    CachePolicy policy,
    String url,
  ) {
    final now = DateTime.now();
    final expiryDuration = policy.getExpiryDuration(response);

    return CachedResponse(
      url: url,
      statusCode: response.statusCode,
      headers: response.headers,
      body: response.bodyBytes,
      cachedAt: now,
      expiresAt: now.add(expiryDuration),
    );
  }

  /// Deserializes a [CachedResponse] from JSON.
  factory CachedResponse.fromJson(Map<String, dynamic> json) => CachedResponse(
        url: json['url'] as String,
        statusCode: json['statusCode'] as int,
        headers: Map<String, String>.from(json['headers'] as Map),
        body: base64Decode(json['body'] as String),
        cachedAt: DateTime.parse(json['cachedAt'] as String),
        expiresAt: DateTime.parse(json['expiresAt'] as String),
      );
  final String url;
  final int statusCode;
  final Map<String, String> headers;
  final Uint8List body;
  final DateTime cachedAt;
  final DateTime expiresAt;

  /// Converts this [CachedResponse] back to an [http.Response].
  http.Response toResponse() {
    final responseHeaders = Map<String, String>.from(headers);
    responseHeaders['X-From-Cache'] = 'true';

    return http.Response.bytes(
      body,
      statusCode,
      headers: responseHeaders,
      // We can't easily restore the original request object here,
      // but http.Response allows it to be null.
    );
  }

  /// Whether this response is currently expired.
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Approximate size of this entry in bytes.
  int get sizeInBytes => body.length + url.length + headers.toString().length;

  /// Serializes this [CachedResponse] to JSON.
  Map<String, dynamic> toJson() => {
        'url': url,
        'statusCode': statusCode,
        'headers': headers,
        'body': base64Encode(body),
        'cachedAt': cachedAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
      };
}

/// Abstract interface for cache storage implementations.
abstract class CacheStore {
  /// Initializes the cache store.
  Future<void> init([String? path]);

  /// Retrieves a response from the cache by its key.
  /// Returns null if not found or expired.
  Future<CachedResponse?> get(String key);

  /// Retrieves a response from the cache even if it is expired.
  /// Returns null only if the entry is missing entirely.
  Future<CachedResponse?> getStale(String key);

  /// Stores a response in the cache.
  /// Implementations should handle eviction logic (LRU/FIFO) based on policy.
  Future<void> set(String key, CachedResponse response);

  /// Invalidates entries matching the pattern, or all entries if null.
  Future<void> invalidate(String? keyPattern);

  /// Returns metadata about the current cache state.
  Future<CacheStats> stats();

  /// Clears the entire cache.
  Future<void> clear();
}

/// Statistics about the cache state.
class CacheStats {
  const CacheStats({
    required this.hits,
    required this.misses,
    required this.size,
    required this.entries,
    this.avgAge = Duration.zero,
  });
  final int hits;
  final int misses;
  final int size;
  final int entries;
  final Duration avgAge;
}
