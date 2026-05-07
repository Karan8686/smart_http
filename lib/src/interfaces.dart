import 'package:http/http.dart' as http;

export 'cache/cache_policy.dart';
export 'cache/cache_store.dart';
export 'cache/hive_cache_store.dart';
export 'cache/in_memory_cache_store.dart';

/// Interceptor for outgoing requests.
typedef RequestInterceptor = Future<http.BaseRequest> Function(
  http.BaseRequest request,
);

/// Interceptor for incoming responses.
typedef ResponseInterceptor = Future<http.StreamedResponse> Function(
  http.StreamedResponse response,
);
