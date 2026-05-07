import 'dart:async';
import '../interfaces.dart';

/// A lightweight, zero-dependency in-memory implementation of [CacheStore].
/// Data is stored in RAM and is lost when the application restarts.
class InMemoryCacheStore implements CacheStore {
  final CachePolicy _policy;
  final Map<String, CachedResponse> _cache = {};
  final Map<String, DateTime> _accessTimes = {};

  int _hits = 0;
  int _misses = 0;

  InMemoryCacheStore({required CachePolicy cachePolicy})
      : _policy = cachePolicy;

  /// In-memory store is ready immediately. init() is a no-op for compatibility.
  @override
  Future<void> init([String? path]) async {}

  @override
  Future<CachedResponse?> get(String key) async {
    try {
      final cached = _cache[key];

      if (cached == null) {
        _misses++;
        return null;
      }

      if (cached.isExpired) {
        _misses++;
        return null;
      }

      // Cache hit
      _hits++;
      _accessTimes[key] = DateTime.now();
      return cached;
    } catch (e) {
      _logWarning('Failed to get cache for $key: $e');
      return null;
    }
  }

  @override
  Future<CachedResponse?> getStale(String key) async {
    try {
      final cached = _cache[key];

      if (cached == null) {
        _misses++;
        return null;
      }

      // Update access time
      _accessTimes[key] = DateTime.now();

      // Return regardless of expiry
      return cached;
    } catch (e) {
      _logWarning('Failed to get stale cache for $key: $e');
      return null;
    }
  }

  @override
  Future<void> set(String key, CachedResponse response) async {
    try {
      _cache[key] = response;
      _accessTimes[key] = DateTime.now();

      // Evict if needed
      await _evictIfNeeded();
    } catch (e) {
      _logWarning('Failed to set cache for $key: $e');
    }
  }

  @override
  Future<void> invalidate(String? keyPattern) async {
    try {
      if (keyPattern == null) {
        _cache.clear();
        _accessTimes.clear();
      } else {
        // MVP: Just clear all matching key or all as per prompt
        // TODO: In v2, implement pattern matching
        _cache.remove(keyPattern);
        _accessTimes.remove(keyPattern);
      }
    } catch (e) {
      _logWarning('Failed to invalidate cache: $e');
    }
  }

  @override
  Future<void> clear() async {
    await invalidate(null);
  }

  @override
  Future<CacheStats> stats() async {
    try {
      int totalSize = 0;
      DateTime? oldestTime;

      for (final cached in _cache.values) {
        totalSize += cached.sizeInBytes;

        if (oldestTime == null || cached.cachedAt.isBefore(oldestTime)) {
          oldestTime = cached.cachedAt;
        }
      }

      final avgAge = oldestTime != null && _cache.isNotEmpty
          ? DateTime.now().difference(oldestTime) ~/ _cache.length
          : Duration.zero;

      return CacheStats(
        hits: _hits,
        misses: _misses,
        size: totalSize,
        entries: _cache.length,
        avgAge: avgAge,
      );
    } catch (e) {
      _logWarning('Failed to compute cache stats: $e');
      return CacheStats(
        hits: _hits,
        misses: _misses,
        size: 0,
        entries: 0,
        avgAge: Duration.zero,
      );
    }
  }

  Future<void> _evictIfNeeded() async {
    // Check entries limit
    while (_cache.length > _policy.maxEntries) {
      _evictLRU();
    }

    // Check size limit
    if (_policy.maxSize > 0) {
      int currentSize = _calculateTotalSize();
      while (currentSize > _policy.maxSize && _cache.isNotEmpty) {
        _evictLRU();
        currentSize = _calculateTotalSize();
      }
    }
  }

  void _evictLRU() {
    if (_cache.isEmpty) return;

    // Find least recently used key
    String? lruKey;
    DateTime? oldestTime;

    for (final entry in _accessTimes.entries) {
      if (oldestTime == null || entry.value.isBefore(oldestTime)) {
        oldestTime = entry.value;
        lruKey = entry.key;
      }
    }

    if (lruKey != null) {
      _cache.remove(lruKey);
      _accessTimes.remove(lruKey);
    }
  }

  int _calculateTotalSize() {
    return _cache.values.fold<int>(
      0,
      (sum, cached) => sum + cached.sizeInBytes,
    );
  }

  void _logWarning(String message) {
    print('[SmartHttpCache] WARNING: $message');
  }
}
