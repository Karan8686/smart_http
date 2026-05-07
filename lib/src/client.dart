import 'dart:async';
import 'package:http/http.dart' as http;
import 'interfaces.dart';

/// A smart HTTP client with built-in caching and interception.
class SmartHttpClient extends http.BaseClient {
  final CacheStore _cacheStore;
  final CachePolicy _cachePolicy;
  final http.Client _innerClient;
  final List<RequestInterceptor> requestInterceptors;
  final List<ResponseInterceptor> responseInterceptors;

  SmartHttpClient({
    required CacheStore cacheStore,
    required CachePolicy cachePolicy,
    http.Client? innerClient,
    this.requestInterceptors = const [],
    this.responseInterceptors = const [],
  })  : _cacheStore = cacheStore,
        _cachePolicy = cachePolicy,
        _innerClient = innerClient ?? http.Client();

  /// Creates a client with an in-memory cache.
  factory SmartHttpClient.inMemory({
    CachePolicy cachePolicy = const CachePolicy(),
    http.Client? innerClient,
  }) {
    return SmartHttpClient(
      cacheStore: InMemoryCacheStore(cachePolicy: cachePolicy),
      cachePolicy: cachePolicy,
      innerClient: innerClient,
    );
  }

  /// Creates a client with a persistent Hive cache.
  factory SmartHttpClient.withHive({
    String boxName = 'smart_http_cache',
    CachePolicy cachePolicy = const CachePolicy(),
    http.Client? innerClient,
  }) {
    return SmartHttpClient(
      cacheStore: HiveCacheStore(
        boxName: boxName,
        cachePolicy: cachePolicy,
      ),
      cachePolicy: cachePolicy,
      innerClient: innerClient,
    );
  }

  /// Creates a client with the best available cache (Hive if possible, otherwise In-Memory).
  factory SmartHttpClient.cached({
    CachePolicy cachePolicy = const CachePolicy(),
    http.Client? innerClient,
  }) {
    CacheStore store;
    try {
      store = HiveCacheStore(cachePolicy: cachePolicy);
    } catch (_) {
      store = InMemoryCacheStore(cachePolicy: cachePolicy);
    }

    return SmartHttpClient(
      cacheStore: store,
      cachePolicy: cachePolicy,
      innerClient: innerClient,
    );
  }

  /// Initializes the client (required for Hive-backed stores).
  ///
  /// For Hive stores, this opens the database—must be called before use.
  /// For in-memory stores, this is a no-op.
  Future<void> init([String? path]) async {
    await _cacheStore.init(path);
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // 1. Intercept request (placeholder for future logic)
    var processedRequest = request;
    for (final interceptor in requestInterceptors) {
      processedRequest = await interceptor(processedRequest);
    }

    final cacheKey = _getCacheKey(processedRequest.url);

    // 2. Check cache for GET
    if (processedRequest.method == 'GET') {
      try {
        final cached = await _cacheStore.get(cacheKey);
        if (cached != null && !cached.isExpired) {
          return _toStreamedResponse(cached.toResponse());
        }
      } catch (e) {
        // Log warning and treat as cache miss
        print('SmartHttpClient: Cache get error: $e');
      }
    }

    try {
      // 3. Send request
      final streamedResponse = await _innerClient.send(processedRequest);

      // 4. Cache response if successful (GET only)
      if (processedRequest.method == 'GET' &&
          streamedResponse.statusCode == 200) {
        final response = await http.Response.fromStream(streamedResponse);
        try {
          final cachedResponse = CachedResponse.fromResponse(
            response,
            _cachePolicy,
            processedRequest.url.toString(),
          );
          await _cacheStore.set(cacheKey, cachedResponse);
        } catch (e) {
          print('SmartHttpClient: Cache set error: $e');
        }
        return _toStreamedResponse(response);
      }

      // 5. Intercept response
      var processedResponse = streamedResponse;
      for (final interceptor in responseInterceptors) {
        processedResponse = await interceptor(processedResponse);
      }

      return processedResponse;
    } catch (e) {
      // 6. Return stale on error if policy allows
      if (processedRequest.method == 'GET' &&
          _cachePolicy.staleIfError > Duration.zero) {
        try {
          final stale = await _cacheStore.getStale(cacheKey);
          if (stale != null) {
            return _toStreamedResponse(stale.toResponse());
          }
        } catch (staleError) {
          print('SmartHttpClient: Cache getStale error: $staleError');
        }
      }
      rethrow;
    }
  }

  /// Returns stale data if available for a given URL.
  Future<http.Response?> getStale(String url) async {
    final key = _getCacheKey(Uri.parse(url));
    final cached = await _cacheStore.getStale(key);
    return cached?.toResponse();
  }

  /// Clears cache for a specific URL or all entries.
  Future<void> clearCache([String? url]) async {
    if (url != null) {
      await _cacheStore.invalidate(_getCacheKey(Uri.parse(url)));
    } else {
      await _cacheStore.clear();
    }
  }

  /// Returns cache statistics.
  Future<CacheStats> cacheStats() {
    return _cacheStore.stats();
  }

  String _getCacheKey(Uri url) {
    // Normalize URL: sorting query parameters
    final sortedParams = Map.fromEntries(
      url.queryParametersAll.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key)),
    );
    final normalizedUrl = url.replace(
        queryParameters: sortedParams.isEmpty ? null : sortedParams);
    return normalizedUrl.toString();
  }

  http.StreamedResponse _toStreamedResponse(http.Response response) {
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() {
    _innerClient.close();
    super.close();
  }
}
