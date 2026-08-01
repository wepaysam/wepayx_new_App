import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';

import '../config/api_config.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  Dio? _dio;
  CookieJar? _cookieJar;

  Future<void> init() async {
    if (_dio != null) return;

    final dir = await getApplicationDocumentsDirectory();
    _cookieJar = PersistCookieJar(
      storage: FileStorage('${dir.path}/.cookies/'),
    );

    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 45),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 45),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    _dio!.interceptors.add(CookieManager(_cookieJar!));
    _dio!.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.baseUrl = ApiConfig.baseUrl;
          final apiKey = ApiConfig.apiKey;
          if (apiKey != null && apiKey.isNotEmpty) {
            options.headers['X-FUTRE-API-Key'] = apiKey;
          }
          handler.next(options);
        },
      ),
    );
  }

  Future<void> updateBaseUrl(String url) async {
    ApiConfig.setBaseUrl(url);
    await _cookieJar?.deleteAll();
    _dio?.options.baseUrl = ApiConfig.baseUrl;
  }

  /// Clears persisted session cookies (stale / invalid login tokens).
  Future<void> clearCookies() async {
    await init();
    await _cookieJar?.deleteAll();
  }

  /// True when the API rejected the request because there is no valid session.
  static bool isSessionExpiredError(Object error) {
    if (error is ApiException) {
      final message = error.message.toLowerCase();
      if (error.statusCode == 401 &&
          (message.contains('login required') ||
              message.contains('session') ||
              message.contains('unauthorized') ||
              message.contains('not authenticated'))) {
        return true;
      }
      if (message.contains('login required')) return true;
    }
    final text = error.toString().toLowerCase();
    return text.contains('login required');
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    await init();
    try {
      final response = await _dio!.get<Map<String, dynamic>>(
        path,
        queryParameters: queryParameters,
      );
      return response.data ?? {};
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    Duration? receiveTimeout,
    Duration? sendTimeout,
  }) async {
    await init();
    try {
      final response = await _dio!.post<Map<String, dynamic>>(
        path,
        data: body,
        options: Options(
          receiveTimeout: receiveTimeout,
          sendTimeout: sendTimeout,
        ),
      );
      return response.data ?? {};
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  ApiException _mapError(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['error'] != null) {
      final message = data['error'].toString();
      final status = error.response?.statusCode;
      // Prefer backend session errors over a generic API-key message.
      if (status == 401 ||
          message.toLowerCase().contains('login required') ||
          message.toLowerCase().contains('unauthorized')) {
        return ApiException(message, statusCode: status, code: data['code']?.toString());
      }
      return ApiException(
        message,
        statusCode: status,
        code: data['code']?.toString(),
      );
    }
    if (data is String && data.isNotEmpty) {
      return ApiException(data, statusCode: error.response?.statusCode);
    }

    if (error.response?.statusCode == 401) {
      return ApiException(
        'Login required',
        statusCode: 401,
      );
    }

    if (error.response?.statusCode == 403) {
      return ApiException(
        'API key missing or invalid. Add your Futre API key in Profile.',
        statusCode: error.response?.statusCode,
      );
    }

    if (error.type == DioExceptionType.connectionError ||
        error.error is SocketException) {
      return ApiException(
        'Cannot reach API at ${ApiConfig.baseUrl}. Check the base URL and server.',
        statusCode: error.response?.statusCode,
      );
    }

    if (error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionTimeout) {
      return ApiException(
        'Server timed out. Check your connection or API URL (${ApiConfig.baseUrl}).',
        statusCode: error.response?.statusCode,
      );
    }

    return ApiException(
      error.message ?? 'Request failed',
      statusCode: error.response?.statusCode,
    );
  }
}
