import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => message;

  static const _labels = <String, String>{
    'invalid_or_expired_otp':
        'That code is invalid or expired. Request a new one.',
    'invalid_api_key':
        'API key missing or invalid. Open Profile and save the live API key.',
    'otp_sent_if_account_exists':
        'If this email is registered, a reset code was sent.',
    'password_too_weak': 'Choose a stronger password (at least 8 characters).',
    'weak_password': 'Choose a stronger password (at least 8 characters).',
    'user_restricted_or_blocked': 'This account is restricted or blocked.',
    'not_found': 'This action is not available on the server.',
    'user_not_found': 'No NEX account exists for this email. Sign up first.',
    'invalid_email_or_password': 'Wrong email or password.',
    'invalid_credentials': 'Wrong email or password.',
    'delete_pending':
        'This account is scheduled for deletion and cannot log in.',
    'account_pending_deletion':
        'This account is scheduled for deletion and cannot log in.',
    'login_otp_sent': 'We sent a login code to your email.',
    'request_failed': 'Request failed. Try again.',
  };

  static String describe({
    String? error,
    String? message,
    String fallback = 'Request failed',
  }) {
    final code = (error ?? '').trim();
    final detail = (message ?? '').trim();
    if (_labels.containsKey(code)) return _labels[code]!;
    if (_labels.containsKey(detail)) return _labels[detail]!;
    if (detail.isNotEmpty &&
        detail != 'request_failed' &&
        !detail.contains('_')) {
      return detail;
    }
    if (code.isNotEmpty) {
      if (!code.contains('_')) return code;
      return code.replaceAll('_', ' ');
    }
    return fallback;
  }

  bool get isCredentialError {
    final text = '${code ?? ''} $message'.toLowerCase();
    return text.contains('invalid_email_or_password') ||
        text.contains('invalid_credentials') ||
        text.contains('wrong email') ||
        text.contains('user_not_found');
  }

  bool get isInvalidApiKey {
    final text = '${code ?? ''} $message'.toLowerCase();
    return text.contains('invalid_api_key') ||
        (message.toLowerCase().contains('api key') &&
            (statusCode == 401 || statusCode == 403));
  }
}

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  Dio? _dio;
  CookieJar? _cookieJar;
  String? _sessionToken;

  static const _tokenPrefsKey = 'nex_bearer_token';

  String? get sessionToken => _sessionToken;

  Future<void> init() async {
    if (_dio != null) return;

    final prefs = await SharedPreferences.getInstance();
    _sessionToken = prefs.getString(_tokenPrefsKey);

    final dir = await getApplicationDocumentsDirectory();
    _cookieJar = PersistCookieJar(
      storage: FileStorage('${dir.path}/.cookies/'),
      // On Android the WorkManager poll isolate opens this same directory, so a
      // read can land on a half-written file. The default behaviour deletes the
      // host cookies on such a failure, which silently signs the user out — a
      // failed read must stay recoverable instead.
      deleteHostCookiesWhenLoadFailed: false,
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
            options.headers['X-API-Key'] = apiKey;
          }
          final token = _sessionToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  Future<void> updateBaseUrl(String url) async {
    ApiConfig.setBaseUrl(url);
    await _cookieJar?.deleteAll();
    await setSessionToken(null);
    _dio?.options.baseUrl = ApiConfig.baseUrl;
  }

  Future<void> setSessionToken(String? token) async {
    _sessionToken = token == null || token.isEmpty ? null : token;
    final prefs = await SharedPreferences.getInstance();
    if (_sessionToken == null) {
      await prefs.remove(_tokenPrefsKey);
    } else {
      await prefs.setString(_tokenPrefsKey, _sessionToken!);
    }
    await _syncSessionCookies();
  }

  Future<void> _syncSessionCookies() async {
    final jar = _cookieJar;
    final token = _sessionToken;
    if (jar == null || token == null || token.isEmpty) return;
    try {
      final uri = Uri.parse(ApiConfig.baseUrl);
      await jar.saveFromResponse(uri, [
        Cookie('futre_session', token),
        Cookie('nex_session', token),
      ]);
    } catch (_) {}
  }

  /// Clears persisted session cookies and bearer token.
  Future<void> clearCookies() async {
    await init();
    await _cookieJar?.deleteAll();
    await setSessionToken(null);
  }

  /// True when the API rejected the request because there is no valid session.
  ///
  /// This must stay limited to real rejections from the server: transport
  /// failures are retried, never treated as a logout.
  static bool isSessionExpiredError(Object error) {
    if (error is ApiException) {
      if (error.isInvalidApiKey || error.isCredentialError) return false;
      if (error.statusCode == 401) {
        final message = error.message.toLowerCase();
        if (message.contains('wrong email') ||
            message.contains('password') ||
            message.contains('no nex account')) {
          return false;
        }
        return true;
      }
      final message = error.message.toLowerCase();
      if (message.contains('login required')) return true;
      if (message.contains('unauthorized')) return true;
      if (message.contains('invalid_token') ||
          message.contains('session_expired')) {
        return true;
      }
    }
    final text = error.toString().toLowerCase();
    if (text.contains('invalid_api_key')) return false;
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
    if (data is Map &&
        (data['error'] != null || data['message'] != null)) {
      final code = data['error']?.toString();
      final detail = data['message']?.toString();
      final message = ApiException.describe(
        error: code,
        message: detail,
      );
      final status = error.response?.statusCode;
      // Prefer backend session errors over a generic API-key message.
      if (code == 'invalid_api_key' ||
          code == 'invalid_email_or_password' ||
          code == 'invalid_credentials' ||
          code == 'user_not_found' ||
          code == 'user_restricted_or_blocked') {
        return ApiException(message, statusCode: status, code: code);
      }
      if (status == 401 ||
          message.toLowerCase().contains('login required') ||
          message.toLowerCase().contains('unauthorized')) {
        return ApiException(message, statusCode: status, code: code ?? data['code']?.toString());
      }
      return ApiException(
        message,
        statusCode: status,
        code: code ?? data['code']?.toString(),
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
        ApiException.describe(
          error: 'invalid_api_key',
          message: null,
        ),
        statusCode: error.response?.statusCode,
        code: 'invalid_api_key',
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
