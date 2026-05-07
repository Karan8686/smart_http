import 'package:smart_http_client/smart_http_client.dart';

/// Example 1: Basic in-memory caching
Future<void> example1_basicCaching() async {
  final client = SmartHttpClient.inMemory();

  // First request: network
  print('Example 1: Basic Caching');
  var response = await client.get(
    Uri.parse('https://jsonplaceholder.typicode.com/users/1'),
  );
  print('First request (network): ${response.statusCode}');
  print('X-From-Cache: ${response.headers['X-From-Cache']}');

  // Second request: cache
  response = await client.get(
    Uri.parse('https://jsonplaceholder.typicode.com/users/1'),
  );
  print('Second request (cache): ${response.statusCode}');
  print('X-From-Cache: ${response.headers['X-From-Cache']}');
  print('');
}

/// Example 2: Custom cache policy
Future<void> example2_customPolicy() async {
  final client = SmartHttpClient.inMemory(
    cachePolicy: const CachePolicy(
      maxAge: Duration(seconds: 2),
      staleIfError: Duration(hours: 1),
    ),
  );

  print('Example 2: Custom Cache Policy');
  print('Cache expires in 2 seconds');

  final url = Uri.parse('https://jsonplaceholder.typicode.com/posts/1');

  await client.get(url);
  print('Request 1: Fresh');

  print('Waiting 3 seconds for expiry...');
  await Future.delayed(const Duration(seconds: 3));

  final response = await client.get(url);
  print('Request 2 (after delay): ${response.statusCode}');
  print(
      'X-From-Cache: ${response.headers['X-From-Cache']} (Should be null or false)');
  print('');
}

/// Example 3: Offline fallback (stale-if-error)
Future<void> example3_offlineFallback() async {
  final client = SmartHttpClient.inMemory();

  print('Example 3: Offline Fallback');

  final url = 'https://jsonplaceholder.typicode.com/posts/1';

  // Prime the cache
  await client.get(Uri.parse(url));
  print('Data cached.');

  // Manually retrieve stale data (simulating offline check)
  final stale = await client.getStale(url);
  print('Stale data available: ${stale != null}');
  if (stale != null) {
    print('Stale status: ${stale.statusCode}');
  }
  print('');
}

/// Example 4: Cache stats
Future<void> example4_cacheStats() async {
  final client = SmartHttpClient.inMemory();

  print('Example 4: Cache Stats');

  final url1 = Uri.parse('https://jsonplaceholder.typicode.com/users/1');
  final url2 = Uri.parse('https://jsonplaceholder.typicode.com/users/2');

  // Make some requests
  await client.get(url1); // Miss
  await client.get(url1); // Hit
  await client.get(url2); // Miss

  // Check stats
  final stats = await client.cacheStats();
  print('Cache hits: ${stats.hits}');
  print('Cache misses: ${stats.misses}');
  print('Cached entries: ${stats.entries}');
  print('');
}

/// Example 5: Clear cache
Future<void> example5_clearCache() async {
  final client = SmartHttpClient.inMemory();

  print('Example 5: Clear Cache');

  final url = Uri.parse('https://jsonplaceholder.typicode.com/users/1');

  // Cache a response
  await client.get(url);
  print('Response cached.');

  // Clear cache
  await client.clearCache();
  print('Cache cleared.');

  // Verify
  final stats = await client.cacheStats();
  print('Cached entries after clear: ${stats.entries}');
  print('');
}

Future<void> main() async {
  try {
    await example1_basicCaching();
    await example2_customPolicy();
    await example3_offlineFallback();
    await example4_cacheStats();
    await example5_clearCache();

    print('✅ All examples completed!');
  } catch (e) {
    print('❌ Error during examples: $e');
  }
}
