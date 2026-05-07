# Smart HTTP

A lightweight, drop-in HTTP client for Dart/Flutter with **transparent caching**, 
**offline support**, and **extensible storage backends**.

> Stop writing cache boilerplate. Smart HTTP handles it automatically.

[![Pub Version](https://img.shields.io/pub/v/smart_http.svg)](https://pub.dev/packages/smart_http)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Features

- ✅ **Transparent caching** — GET requests cached automatically
- ✅ **Offline-first** — Serves stale data if network fails
- ✅ **HTTP header respect** — Honors Cache-Control & Expires headers
- ✅ **Zero external deps** — Core package is tiny (~50KB)
- ✅ **Persistent & in-memory** — Hive or RAM-based backends
- ✅ **Drop-in replacement** — Works anywhere `http.Client` works
- ✅ **Extensible** — Implement your own cache backend

## Quick Start

### 1. In-memory cache (dev/testing)

```dart
import 'package:smart_http/smart_http.dart';

final client = SmartHttpClient.inMemory();

// First request: hits network
var response = await client.get(Uri.parse('https://api.example.com/users'));
print(response.statusCode); // 200

// Second request: returns cached response instantly
response = await client.get(Uri.parse('https://api.example.com/users'));
print(response.statusCode); // 200 (from cache)
```

### 2. Persistent cache (production)

Add dependencies to your `pubspec.yaml`:
```yaml
dependencies:
  smart_http: ^1.0.0
  hive: ^2.2.0
  path_provider: ^2.0.0
```

Then in your app:
```dart
import 'package:smart_http/smart_http.dart';

void main() async {
  // Initialize once on app startup
  final client = SmartHttpClient.withHive(
    boxName: 'api_cache',
  );
  await client.init(); // Opens Hive database
  
  // Use throughout your app
  final response = await client.get(Uri.parse('https://api.example.com/data'));
  print(response.statusCode); // 200 (or from cache if network fails)
}
```

### 3. Custom configuration

```dart
final client = SmartHttpClient(
  cacheStore: InMemoryCacheStore(cachePolicy: CachePolicy()),
  cachePolicy: CachePolicy(
    maxAge: Duration(hours: 2),      // Fresh for 2 hours
    staleIfError: Duration(days: 30), // Serve stale for 30 days on error
    maxSize: 50 * 1024 * 1024,        // 50 MB cache limit
    maxEntries: 1000,                 // Store up to 1000 URLs
    respectCacheControl: true,        // Honor Cache-Control headers
  ),
);

await client.get(Uri.parse('https://api.example.com/data'));
```

## How It Works

### Request Flow

```
GET /api/users
    ↓
[Check cache] → Found & fresh? → Return cached response (instant)
    ↓
   Miss/Expired
    ↓
[Send request] → Network OK? → Cache response & return it
    ↓
   Network fails
    ↓
[Check stale] → Have old data? → Return stale response (offline support)
    ↓
   No cache
    ↓
[Throw error] → User handles error
```

**Non-GET requests** (POST, PUT, DELETE) are never cached—they hit the network every time.

### Cache Expiry

Smart HTTP respects HTTP caching headers in this order:

1. **Cache-Control header** (if `respectCacheControl=true`)
   - `Cache-Control: max-age=3600` → Cache for 1 hour
2. **Expires header** (if `respectExpires=true`)
   - `Expires: Wed, 21 Oct 2025 07:28:00 GMT` → Cache until that time
3. **Fallback to policy** (if neither header present)
   - Use `CachePolicy.maxAge` (default: 1 hour)

### Offline Support (Stale-if-Error)

When the network fails:

1. Check if stale data exists
2. If stale data is within `staleIfError` window, return it
3. If no stale data, throw the original error

Example:
```dart
// Response cached 5 days ago
// staleIfError is 7 days
// Network fails today

final response = await client.get(...);
// Returns 5-day-old cached response → app works offline ✅
```

## API Reference

### SmartHttpClient

Drop-in replacement for `http.Client`.

#### Constructors

- **`SmartHttpClient.inMemory()`** — RAM-only cache (dev/testing)
- **`SmartHttpClient.withHive()`** — Persistent cache using Hive (production)
- **`SmartHttpClient.cached()`** — Auto-detect backend
- **`SmartHttpClient()`** — Custom (advanced)

#### Methods

```dart
// Standard HTTP methods (inherited from http.Client)
Future<http.Response> get(Uri url, {Map<String, String>? headers})
Future<http.Response> post(Uri url, ...)
Future<http.Response> put(Uri url, ...)
Future<http.Response> delete(Uri url, ...)

// Smart HTTP extensions
Future<void> init()  // Required for Hive backend
Future<http.Response?> getStale(String url)  // Get cached data even if expired
Future<void> clearCache([String? url])  // Clear cache
Future<CacheStats> cacheStats()  // Get cache hit/miss stats
```

### CachePolicy

Configuration for cache behavior.

```dart
CachePolicy(
  maxAge: Duration(hours: 1),           // Fresh for 1 hour
  staleIfError: Duration(days: 7),      // Serve stale for 7 days
  maxSize: 10 * 1024 * 1024,            // 10 MB total cache
  maxEntries: 500,                      // Cache max 500 URLs
  respectCacheControl: true,            // Respect HTTP headers
  respectExpires: true,
)
```

### CacheStats

Debugging info about cache performance.

```dart
final stats = await client.cacheStats();
print('Hits: ${stats.hits}');
print('Misses: ${stats.misses}');
print('Size: ${stats.size} bytes');
print('Entries: ${stats.entries}');
```

## Examples

### Example 1: GitHub API

Fetch GitHub user data with caching:

```dart
final client = SmartHttpClient.inMemory();

Future<void> fetchGithubUser(String username) async {
  final url = Uri.parse('https://api.github.com/users/$username');
  final response = await client.get(url);
  
  if (response.statusCode == 200) {
    print('User data: ${response.body}');
    // Second call returns cached data instantly
  }
}
```

### Example 2: JSON Placeholder API

Fetch posts with custom cache policy:

```dart
final client = SmartHttpClient(
  cacheStore: InMemoryCacheStore(cachePolicy: CachePolicy()),
  cachePolicy: CachePolicy(
    maxAge: Duration(minutes: 5),  // Fresh for 5 minutes
    staleIfError: Duration(hours: 24),
  ),
);

Future<void> fetchPosts() async {
  final url = Uri.parse('https://jsonplaceholder.typicode.com/posts');
  final response = await client.get(url);
  
  print(response.statusCode); // 200
  // Cached for 5 minutes
}
```

### Example 3: Offline App

Build an app that works offline:

```dart
final client = SmartHttpClient.withHive();
await client.init();

Future<void> loadData() async {
  try {
    // Try network
    final response = await client.get(Uri.parse('https://api.example.com/data'));
    print('Fresh data: ${response.body}');
  } catch (e) {
    // Network fails, check stale data
    final staleResponse = await client.getStale(
      'https://api.example.com/data',
    );
    if (staleResponse != null) {
      print('Offline, using old data: ${staleResponse.body}');
    } else {
      print('No data available');
    }
  }
}
```

## Comparison

### vs. http package

| Feature | http | smart_http |
|---------|------|-----------|
| GET caching | ❌ Manual | ✅ Automatic |
| Offline support | ❌ No | ✅ Stale-if-error |
| Cache headers | ❌ Manual | ✅ Automatic |
| Dependencies | 0 | 1 (http) |

### vs. dio package

| Feature | dio | smart_http |
|---------|-----|-----------|
| Caching | ⚠️ Interceptor (boilerplate) | ✅ Built-in |
| Size | 200KB+ | 50KB |
| Learning curve | 1 hour | 5 minutes |
| Offline | ⚠️ Limited | ✅ Full |
| Dependencies | 8+ | 1 |

## Troubleshooting

### Cache not working?

Check that:
1. Request is GET (POST/PUT/DELETE never cached)
2. Response status is 200 (only success cached)
3. Cache hasn't expired (check CachePolicy.maxAge)
4. No custom headers override caching

### "init() not called" error?

If using `SmartHttpClient.withHive()`, you **must** call `await client.init()` before any requests.

```dart
final client = SmartHttpClient.withHive();
await client.init();  // ← Required!
await client.get(...);
```

### How do I clear cache?

```dart
// Clear all
await client.clearCache();

// Clear specific URL
await client.clearCache('https://api.example.com/users');
```

## License

MIT — see [LICENSE](LICENSE)
