import 'package:http/http.dart' as http;
import 'dart:io';

/// Policy for cache management, including expiration and stale behavior.
class CachePolicy {
  /// How long a cached response is "fresh".
  final Duration maxAge;

  /// How long to serve stale data if the network fails.
  final Duration staleIfError;

  /// Maximum total cache size in bytes.
  final int maxSize;

  /// Maximum number of cached URLs.
  final int maxEntries;

  /// If true, honor `Cache-Control: max-age=X` headers.
  final bool respectCacheControl;

  /// If true, honor `Expires` header.
  final bool respectExpires;

  const CachePolicy({
    this.maxAge = const Duration(hours: 1),
    this.staleIfError = const Duration(days: 7),
    this.maxSize = 10 * 1024 * 1024, // 10 MB
    this.maxEntries = 500,
    this.respectCacheControl = true,
    this.respectExpires = true,
  });

  /// Calculates the expiry duration for a given [response].
  Duration getExpiryDuration(http.Response response) {
    if (respectCacheControl) {
      final cacheControl = response.headers[HttpHeaders.cacheControlHeader];
      final maxAgeFromHeader = _parseCacheControlMaxAge(cacheControl);
      if (maxAgeFromHeader != null) return maxAgeFromHeader;
    }

    if (respectExpires) {
      final expires = response.headers[HttpHeaders.expiresHeader];
      final expiryFromHeader = _parseExpiresHeader(expires);
      if (expiryFromHeader != null) return expiryFromHeader;
    }

    return maxAge;
  }

  /// Determines if stale data should be used based on [cachedAt] and [now].
  bool shouldUseStale(DateTime cachedAt, DateTime now) {
    return now.difference(cachedAt) <= staleIfError;
  }

  /// Creates a copy of this [CachePolicy] with the given fields replaced.
  CachePolicy copyWith({
    Duration? maxAge,
    Duration? staleIfError,
    int? maxSize,
    int? maxEntries,
    bool? respectCacheControl,
    bool? respectExpires,
  }) {
    return CachePolicy(
      maxAge: maxAge ?? this.maxAge,
      staleIfError: staleIfError ?? this.staleIfError,
      maxSize: maxSize ?? this.maxSize,
      maxEntries: maxEntries ?? this.maxEntries,
      respectCacheControl: respectCacheControl ?? this.respectCacheControl,
      respectExpires: respectExpires ?? this.respectExpires,
    );
  }

  static Duration? _parseCacheControlMaxAge(String? cacheControl) {
    if (cacheControl == null || cacheControl.isEmpty) return null;

    final parts = cacheControl.split(',').map((e) => e.trim().toLowerCase());
    for (final part in parts) {
      if (part.startsWith('max-age=')) {
        final value = part.substring('max-age='.length);
        final seconds = int.tryParse(value);
        if (seconds != null && seconds >= 0) {
          return Duration(seconds: seconds);
        }
      }
    }
    return null;
  }

  static Duration? _parseExpiresHeader(String? expires) {
    if (expires == null || expires.isEmpty) return null;

    try {
      // HttpDate parses RFC 2822 dates used in HTTP
      final expiresDate = HttpDate.parse(expires);
      final now = DateTime.now();
      if (expiresDate.isAfter(now)) {
        return expiresDate.difference(now);
      }
    } catch (_) {
      // Ignore malformed dates
    }
    return null;
  }
}
