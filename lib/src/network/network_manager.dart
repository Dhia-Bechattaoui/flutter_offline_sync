import 'dart:async';

import 'package:dio/dio.dart';
import 'platform_connectivity.dart';
import '../utils/logger.dart';

/// Manages network connectivity and HTTP operations.
class NetworkManager {
  final PlatformConnectivity _connectivity = PlatformConnectivity();
  final Dio _dio = Dio();
  final Logger _logger = Logger('NetworkManager');
  String? _baseUrl;
  Map<String, String> _defaultHeaders = {};
  Duration _timeout = const Duration(seconds: 30);

  /// Initializes the network manager.
  Future<void> initialize({
    String? baseUrl,
    Map<String, String>? defaultHeaders,
    Duration? timeout,
  }) async {
    _baseUrl = baseUrl;
    _defaultHeaders = defaultHeaders ?? {};
    _timeout = timeout ?? const Duration(seconds: 30);

    // Configure Dio
    _dio.options.baseUrl = _baseUrl ?? '';
    _dio.options.connectTimeout = _timeout;
    _dio.options.receiveTimeout = _timeout;
    _dio.options.sendTimeout = _timeout;
    _dio.options.headers.addAll(_defaultHeaders);

    // Add interceptors
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (object) => _logger.debug(object.toString()),
      ),
    );

    // Initialize connectivity monitoring
    await _connectivity.initialize();

    _logger.info('Network manager initialized');
  }

  /// Performs a GET request.
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    Options? options,
  }) async {
    try {
      _logger.debug('GET request to: $path');

      final response = await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: _mergeOptions(options, headers),
      );

      _logger.debug('GET response: ${response.statusCode}');
      return response;
    } catch (e) {
      _logger.error('GET request failed: $path', e);
      rethrow;
    }
  }

  /// Performs a POST request.
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    Options? options,
  }) async {
    try {
      _logger.debug('POST request to: $path');

      final response = await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: _mergeOptions(options, headers),
      );

      _logger.debug('POST response: ${response.statusCode}');
      return response;
    } catch (e) {
      _logger.error('POST request failed: $path', e);
      rethrow;
    }
  }

  /// Performs a PUT request.
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    Options? options,
  }) async {
    try {
      _logger.debug('PUT request to: $path');

      final response = await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: _mergeOptions(options, headers),
      );

      _logger.debug('PUT response: ${response.statusCode}');
      return response;
    } catch (e) {
      _logger.error('PUT request failed: $path', e);
      rethrow;
    }
  }

  /// Performs a PATCH request.
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    Options? options,
  }) async {
    try {
      _logger.debug('PATCH request to: $path');

      final response = await _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: _mergeOptions(options, headers),
      );

      _logger.debug('PATCH response: ${response.statusCode}');
      return response;
    } catch (e) {
      _logger.error('PATCH request failed: $path', e);
      rethrow;
    }
  }

  /// Performs a DELETE request.
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    Options? options,
  }) async {
    try {
      _logger.debug('DELETE request to: $path');

      final response = await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: _mergeOptions(options, headers),
      );

      _logger.debug('DELETE response: ${response.statusCode}');
      return response;
    } catch (e) {
      _logger.error('DELETE request failed: $path', e);
      rethrow;
    }
  }

  /// Merges options with headers.
  Options _mergeOptions(Options? options, Map<String, String>? headers) {
    final mergedHeaders = <String, String>{};
    mergedHeaders.addAll(_defaultHeaders);

    if (options?.headers != null) {
      mergedHeaders.addAll(Map<String, String>.from(options!.headers!));
    }

    if (headers != null) {
      mergedHeaders.addAll(headers);
    }

    return (options ?? Options()).copyWith(headers: mergedHeaders);
  }

  /// Checks if the device is currently online.
  bool get isOnline => _connectivity.isOnline;

  /// Stream of connectivity status changes.
  Stream<bool> get connectivityStream => _connectivity.connectivityStream;

  /// Gets the current connectivity status.
  Future<bool> getConnectivityStatus() async {
    return await _connectivity.getConnectivityStatus();
  }

  /// Tests the network connection by making a simple request.
  Future<bool> testConnection({String? testUrl}) async {
    try {
      final url = testUrl ?? 'https://www.google.com';
      final response = await _dio.get(
        url,
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );

      return response.statusCode == 200;
    } catch (e) {
      _logger.debug('Connection test failed: $e');
      return false;
    }
  }

  /// Sets the base URL for API requests.
  void setBaseUrl(String baseUrl) {
    _baseUrl = baseUrl;
    _dio.options.baseUrl = baseUrl;
    _logger.info('Base URL set to: $baseUrl');
  }

  /// Sets default headers for all requests.
  void setDefaultHeaders(Map<String, String> headers) {
    _defaultHeaders = headers;
    _dio.options.headers.clear();
    _dio.options.headers.addAll(_defaultHeaders);
    _logger.info('Default headers updated');
  }

  /// Sets the timeout for requests.
  void setTimeout(Duration timeout) {
    _timeout = timeout;
    _dio.options.connectTimeout = timeout;
    _dio.options.receiveTimeout = timeout;
    _dio.options.sendTimeout = timeout;
    _logger.info('Timeout set to: ${timeout.inSeconds}s');
  }

  /// Adds an interceptor to the Dio instance.
  void addInterceptor(Interceptor interceptor) {
    _dio.interceptors.add(interceptor);
    _logger.info('Interceptor added');
  }

  /// Removes an interceptor from the Dio instance.
  void removeInterceptor(Interceptor interceptor) {
    _dio.interceptors.remove(interceptor);
    _logger.info('Interceptor removed');
  }

  /// Gets the Dio instance for advanced usage.
  Dio get dio => _dio;

  /// Disposes of the network manager.
  Future<void> dispose() async {
    await _connectivity.dispose();
    _dio.close();
    _logger.info('Network manager disposed');
  }
}
