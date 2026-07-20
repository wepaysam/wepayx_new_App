import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../models/api_models.dart';

/// Fetches app update metadata from the standalone APK server (not the wallet API).
class ApkUpdateApi {
  ApkUpdateApi._();

  static final ApkUpdateApi instance = ApkUpdateApi._();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
    ),
  );

  Future<AppUpdateInfo> fetchUpdate() async {
    final response = await _dio.get<Map<String, dynamic>>(ApiConfig.appUpdateUrl);
    final data = response.data ?? {};
    final raw = data['update'] as Map<String, dynamic>? ?? data;
    final info = AppUpdateInfo.fromJson(raw);
    return AppUpdateInfo(
      latestVersion: info.latestVersion,
      latestBuild: info.latestBuild,
      minBuild: info.minBuild,
      apkUrl: ApiConfig.resolveApkUrl(info.apkUrl),
      releaseNotes: info.releaseNotes,
      forceUpdate: info.forceUpdate,
      platform: info.platform,
    );
  }
}
