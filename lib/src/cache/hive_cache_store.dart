import 'dart:async';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../interfaces.dart';

/// A persistent implementation of [CacheStore] using the Hive database.
class HiveCacheStore implements CacheStore {
  final String boxName;
  final CachePolicy _policy;
  late Box<Map<dynamic, dynamic>> _box;
  bool _initialized = false;

  final Map<String, DateTime> _accessTimes = {};
  int _hits = 0;
  int _misses = 0;

  HiveCacheStore({
    this.boxName = 'smart_http_cache',
    required CachePolicy cachePolicy,
  }) : _policy = cachePolicy;

  /// Initializes the Hive box and prepares the store for use.
  /// This must be called before any other operations.
  @override
  Future<void> init([String? path]) async {
    if (_initialized) return;

    try {
      if (!Hive.isBoxOpen(boxName)) {
        final dirPath = path ?? (await getApplicationDocumentsDirectory()).path;
        Hive.init(dirPath);
      }

      _box = await Hive.openBox<Map<dynamic, dynamic>>(boxName);
      _initialized = true;

      // Initialize access times from existing entries
      for (final key in _box.keys) {
        _accessTimes[key.toString()] = DateTime.now();
      }
    } catch (e) {
      throw StateError('HiveCacheStore failed to initialize: $e');
    }
  }

  @override
  Future<CachedResponse?> get(String key) async {
    _checkInitialized();

    try {
      final data = _box.get(key);
      if (data == null) {
        _misses++;
        return null;
      }

      final cached = CachedResponse.fromJson(Map<String, dynamic>.from(data));

      if (cached.isExpired) {
        _misses++;
        return null;
      }

      _hits++;
      await _updateAccessTime(key);
      return cached;
    } catch (e) {
      _logWarning('Failed to get cache for $key: $e');
      return null;
    }
  }

  @override
  Future<CachedResponse?> getStale(String key) async {
    _checkInitialized();

    try {
      final data = _box.get(key);
      if (data == null) return null;

      final cached = CachedResponse.fromJson(Map<String, dynamic>.from(data));
      await _updateAccessTime(key);
      return cached;
    } catch (e) {
      _logWarning('Failed to get stale cache for $key: $e');
      return null;
    }
  }

  @override
  Future<void> set(String key, CachedResponse response) async {
    _checkInitialized();

    try {
      await _box.put(key, response.toJson());
      await _updateAccessTime(key);
      await _evictIfNeeded();
    } catch (e) {
      _logWarning('Failed to set cache for $key: $e');
    }
  }

  @override
  Future<void> invalidate(String? keyPattern) async {
    _checkInitialized();

    try {
      if (keyPattern == null) {
        await _box.clear();
        _accessTimes.clear();
      } else {
        // MVP: Just clear all as per prompt
        await _box.clear();
        _accessTimes.clear();
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
    _checkInitialized();

    try {
      int totalSize = 0;
      DateTime? oldestTime;

      for (final data in _box.values) {
        final cached = CachedResponse.fromJson(Map<String, dynamic>.from(data));
        totalSize += cached.sizeInBytes;

        if (oldestTime == null || cached.cachedAt.isBefore(oldestTime)) {
          oldestTime = cached.cachedAt;
        }
      }

      final avgAge = oldestTime != null && _box.isNotEmpty
          ? DateTime.now().difference(oldestTime) ~/ _box.length
          : Duration.zero;

      return CacheStats(
        hits: _hits,
        misses: _misses,
        size: totalSize,
        entries: _box.length,
        avgAge: avgAge,
      );
    } catch (e) {
      _logWarning('Failed to compute cache stats: $e');
      return CacheStats(hits: _hits, misses: _misses, size: 0, entries: 0);
    }
  }

  void _checkInitialized() {
    if (!_initialized) {
      throw StateError('HiveCacheStore not initialized. Call init() first.');
    }
  }

  Future<void> _updateAccessTime(String key) async {
    _accessTimes[key] = DateTime.now();
  }

  Future<void> _evictIfNeeded() async {
    // Check entries limit
    while (_box.length > _policy.maxEntries) {
      await _evictLRU();
    }

    // Check size limit
    if (_policy.maxSize > 0) {
      int currentSize = await _calculateTotalSize();
      while (currentSize > _policy.maxSize && _box.isNotEmpty) {
        await _evictLRU();
        currentSize = await _calculateTotalSize();
      }
    }
  }

  Future<void> _evictLRU() async {
    if (_box.isEmpty) return;

    String? lruKey;
    DateTime? oldestAccess;

    for (final key in _box.keys) {
      final access = _accessTimes[key.toString()] ??
          DateTime.fromMillisecondsSinceEpoch(0);
      if (oldestAccess == null || access.isBefore(oldestAccess)) {
        oldestAccess = access;
        lruKey = key.toString();
      }
    }

    if (lruKey != null) {
      await _box.delete(lruKey);
      _accessTimes.remove(lruKey);
    }
  }

  Future<int> _calculateTotalSize() async {
    int size = 0;
    for (final data in _box.values) {
      size +=
          CachedResponse.fromJson(Map<String, dynamic>.from(data)).sizeInBytes;
    }
    return size;
  }

  void _logWarning(String message) {
    print('SmartHttpClient: HiveCacheStore Warning: $message');
  }
}
