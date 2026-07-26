/// Futre / NEX wallet API configuration.
class ApiConfig {
  static const String defaultBaseUrl =
      'https://backend.nexwallet.com';

  /// Standalone APK update server (Python `apk/server.py` on EC2).
  static const String defaultApkBaseUrl =
      'https://apk.nexwallet.risingesports.com';

  /// Override at build time: --dart-define=API_BASE_URL=https://...
  static String baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: defaultBaseUrl,
  );

  /// Override at build time: --dart-define=APK_BASE_URL=https://...
  static String apkBaseUrl = const String.fromEnvironment(
    'APK_BASE_URL',
    defaultValue: defaultApkBaseUrl,
  );

  /// Routes on the APK server (`apk/server.py`).
  static const String appUpdatePath = '/api/app/update';
  static const String apkDownloadPath = '/downloads/nexwallet-release.apk';

  static String get appUpdateUrl => _join(apkBaseUrl, appUpdatePath);

  static String get defaultApkDownloadUrl => _join(apkBaseUrl, apkDownloadPath);

  /// Futre server API key sent as `X-FUTRE-API-Key` on every request.
  /// Override at build time: --dart-define=FUTRE_API_KEY=futre_live_...
  /// For production, prefer your own backend proxy instead of embedding this key.
  static String? apiKey = _envApiKey();

  static String? _envApiKey() {
    const value = String.fromEnvironment('FUTRE_API_KEY');
    return value.isEmpty ? null : value;
  }

  static void setBaseUrl(String url) {
    baseUrl = _trimTrailingSlash(url);
  }

  static void setApkBaseUrl(String url) {
    apkBaseUrl = _trimTrailingSlash(url);
  }

  static void setApiKey(String? key) {
    apiKey = key == null || key.isEmpty ? null : key;
  }

  static bool get isConfigured => apiKey != null && apiKey!.isNotEmpty;

  static String resolveApkUrl(String? url) {
    final raw = (url ?? '').trim();
    // Keep empty empty — never invent an Android APK URL for iOS / no-update
    // responses from the update server.
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('/')) return _join(apkBaseUrl, raw);
    return _join(apkBaseUrl, '/$raw');
  }

  static String _join(String base, String path) {
    final b = _trimTrailingSlash(base);
    final p = path.startsWith('/') ? path : '/$path';
    return '$b$p';
  }

  static String _trimTrailingSlash(String url) {
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }
}
