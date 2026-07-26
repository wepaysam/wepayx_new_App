import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/api_models.dart';
import 'apk_update_api.dart';

class AppUpdateStatus {
  const AppUpdateStatus({
    required this.package,
    this.remote,
    this.error,
  });

  final PackageInfo package;
  final AppUpdateInfo? remote;
  final String? error;

  int get localBuild => int.tryParse(package.buildNumber) ?? 0;

  /// APK updates are Android-only. iOS must never be gated by the APK server.
  bool get isAndroidUpdateTarget => Platform.isAndroid;

  bool get hasUpdate {
    if (!isAndroidUpdateTarget) return false;
    final info = remote;
    if (info == null || info.apkUrl.isEmpty) return false;
    if (info.platform.isNotEmpty && info.platform.toLowerCase() != 'android') {
      return false;
    }
    return info.latestBuild > localBuild;
  }

  bool get requiresUpdate {
    if (!isAndroidUpdateTarget) return false;
    final info = remote;
    if (info == null || info.apkUrl.isEmpty) return false;
    if (info.platform.isNotEmpty && info.platform.toLowerCase() != 'android') {
      return false;
    }
    if (info.minBuild > localBuild) return true;
    if (info.forceUpdate && info.latestBuild > localBuild) return true;
    return false;
  }

  bool get mustBlockApp => requiresUpdate && error == null;

  String get localLabel => 'v${package.version} (${package.buildNumber})';

  String get remoteLabel {
    final info = remote;
    if (info == null) return '—';
    return 'v${info.latestVersion} (${info.latestBuild})';
  }
}

class AppUpdateService {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();

  Future<AppUpdateStatus> checkForUpdate() async {
    final package = await PackageInfo.fromPlatform();

    // Never consult the Android APK update server on iOS / desktop.
    if (!Platform.isAndroid) {
      return AppUpdateStatus(package: package);
    }

    try {
      final remote = await ApkUpdateApi.instance.fetchUpdate();
      return AppUpdateStatus(package: package, remote: remote);
    } catch (e) {
      return AppUpdateStatus(package: package, error: e.toString());
    }
  }

  Future<String> downloadApk(
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    if (!Platform.isAndroid) {
      throw Exception('APK download is only supported on Android.');
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/nexwallet-update.apk');
    if (file.existsSync()) await file.delete();

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 45),
        receiveTimeout: const Duration(minutes: 10),
      ),
    );

    await dio.download(
      url,
      file.path,
      onReceiveProgress: (received, total) {
        if (total <= 0) return;
        onProgress?.call(received / total);
      },
    );

    return file.path;
  }

  Future<void> installApk(String filePath) async {
    if (!Platform.isAndroid) {
      throw Exception('In-app install is only supported on Android.');
    }
    final result = await OpenFilex.open(
      filePath,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      throw Exception(result.message);
    }
  }

  Future<void> openDownloadInBrowser(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) throw Exception('Invalid download URL');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not open download link');
    }
  }
}
