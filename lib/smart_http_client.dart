/// A smart HTTP client for Dart/Flutter with built-in caching, retry logic, and WebSocket support.
///
/// Provides a drop-in replacement for [http.Client] with automatic caching:
/// - Transparent HTTP caching (respects Cache-Control headers)
/// - Offline support (serves stale data if network fails)
/// - Extensible backends (Hive, in-memory, custom)
/// - Zero external dependencies for core client logic
///
/// ## Quick Start
///
/// ### Using in-memory cache (dev/testing):
/// ```dart
/// final client = SmartHttpClient.inMemory();
/// final response = await client.get(Uri.parse('https://api.example.com/users'));
/// print(response.body);
/// ```
///
/// ### Using persistent cache (production):
/// ```dart
/// final client = SmartHttpClient.withHive(
///   boxName: 'api_cache',
/// );
/// await client.init(); // Required for Hive-backed stores
/// final response = await client.get(Uri.parse('https://api.example.com/users'));
/// ```
///
/// ### Custom configuration:
/// ```dart
/// final client = SmartHttpClient(
///   cacheStore: MyCustomStore(),
///   cachePolicy: CachePolicy(
///     maxAge: Duration(hours: 2),
///     staleIfError: Duration(days: 30),
///   ),
/// );
/// ```
///
/// ## Features
/// - Transparent HTTP caching (drop-in replacement for `http.Client`)
/// - Offline-first architecture with stale-if-error support
/// - Automatic URL normalization (query parameters order doesn't affect cache)
/// - Respects standard HTTP headers like `Cache-Control` and `Expires`
/// - Pluggable storage backends (Hive for persistence, In-Memory for speed)
/// - Lightweight and extensible
library smart_http;

/// Drop-in replacement for `http.Client` with built-in caching.
export 'src/client.dart' show SmartHttpClient;

/// Configuration for cache expiry, size limits, and HTTP header respect.
export 'src/cache/cache_policy.dart' show CachePolicy;

/// Cache storage abstraction and metadata models.
export 'src/cache/cache_store.dart' show CacheStore, CachedResponse, CacheStats;

/// Lightweight, RAM-only cache implementation.
export 'src/cache/in_memory_cache_store.dart' show InMemoryCacheStore;

/// Persistent cache implementation using Hive database.
export 'src/cache/hive_cache_store.dart' show HiveCacheStore;
