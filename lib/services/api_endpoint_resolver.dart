import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

/// Picks a reachable Futre API base URL (saved URL, tunnel, then local dev).
class ApiEndpointResolver {
  static const localPort = 19120;

  static List<String> candidates({String? savedUrl}) {
    final urls = <String>{
      if (savedUrl != null && savedUrl.trim().isNotEmpty) savedUrl.trim(),
      ApiConfig.baseUrl,
      if (Platform.isAndroid) 'http://10.0.2.2:$localPort',
      if (Platform.isIOS) 'http://127.0.0.1:$localPort',
      'http://127.0.0.1:$localPort',
      'http://localhost:$localPort',
    };
    return urls.toList();
  }

  static Future<String?> probe(String url) async {
    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: url.endsWith('/') ? url.substring(0, url.length - 1) : url,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'Accept': 'application/json',
            if (ApiConfig.apiKey != null && ApiConfig.apiKey!.isNotEmpty)
              'X-FUTRE-API-Key': ApiConfig.apiKey!,
          },
        ),
      );
      final response = await dio.get<Map<String, dynamic>>('/api/health');
      if (response.data?['ok'] == true) return dio.options.baseUrl;
    } catch (e) {
      debugPrint('ApiEndpointResolver: $url unreachable ($e)');
    }
    return null;
  }

  static bool _isEphemeralDevUrl(String url) {
    return url.contains('10.0.2.2') ||
        url.contains('127.0.0.1') ||
        url.contains('localhost');
  }

  static Future<String?> resolveAndPersist(SharedPreferences prefs) async {
    final saved = prefs.getString('api_base_url');
    for (final url in candidates(savedUrl: saved)) {
      final working = await probe(url);
      if (working != null) {
        ApiConfig.setBaseUrl(working);
        // Only persist remote URLs — never save local dev hosts to prefs.
        if (!_isEphemeralDevUrl(working)) {
          if (saved != working) {
            await prefs.setString('api_base_url', working);
          }
        } else if (saved != null && _isEphemeralDevUrl(saved)) {
          await prefs.remove('api_base_url');
        }
        debugPrint('ApiEndpointResolver: using $working');
        return working;
      }
    }
    debugPrint('ApiEndpointResolver: no API reachable');
    return null;
  }
}

bool isApiUnreachableError(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('cannot reach api') ||
      text.contains('connection timeout') ||
      text.contains('connection error') ||
      text.contains('socketexception') ||
      text.contains('timed out') ||
      text.contains('receive timeout') ||
      text.contains('send timeout');
}
