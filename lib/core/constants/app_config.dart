import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// AppConfig - Cấu hình runtime cho client Flutter.
///
/// Ưu tiên đọc các giá trị từ file `.env` ở thư mục gốc (đã được đăng ký
/// làm asset trong pubspec.yaml). Nếu thiếu khoá nào sẽ rơi về giá trị
/// mặc định phù hợp với từng nền tảng (web/Android/iOS).
///
/// Các biến môi trường hỗ trợ:
///   - SERVER_SCHEME  : http | https  (mặc định http)
///   - SERVER_HOST    : domain hoặc IP của backend, ví dụ 192.168.1.20
///   - SERVER_PORT    : cổng backend (mặc định 3000)
///   - SERVER_HOST_WEB / SERVER_HOST_ANDROID / SERVER_HOST_IOS :
///       override theo từng nền tảng (tuỳ chọn).
class AppConfig {
  AppConfig._();

  // ----- Giá trị mặc định (fallback) -----
  static const int _defaultPort = 3000;
  static const String _defaultScheme = 'http';
  static const String _defaultLanHost = '192.168.0.100';
  static const String _defaultWebHost = 'localhost';

  // ----- Cache lazy để tránh gọi dotenv.env nhiều lần -----
  static String? _cachedScheme;
  static int? _cachedPort;
  static String? _cachedHostOverride;

  static String get _scheme {
    _cachedScheme ??= _readEnv(
      'SERVER_SCHEME',
      fallback: _defaultScheme,
    ).toLowerCase();
    return _cachedScheme!;
  }

  static int get _port {
    _cachedPort ??= int.tryParse(
          _readEnv('SERVER_PORT', fallback: _defaultPort.toString()),
        ) ??
        _defaultPort;
    return _cachedPort!;
  }

  /// Host theo từng nền tảng:
  ///   - Đọc SERVER_HOST_OVERRIDE nếu muốn ép cứng 1 host cho mọi nền tảng
  ///   - Nếu không, đọc SERVER_HOST_{WEB,ANDROID,IOS} theo platform
  ///   - Nếu vẫn không có, dùng default phù hợp từng nền tảng
  static String get serverHost {
    _cachedHostOverride ??= _readEnv('SERVER_HOST_OVERRIDE', fallback: '');
    final override = _cachedHostOverride!.trim();
    if (override.isNotEmpty) return override;

    if (kIsWeb) {
      final webHost = _readEnv('SERVER_HOST_WEB', fallback: _defaultWebHost);
      if (webHost.trim().isNotEmpty) return webHost.trim();
      return _defaultWebHost;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final androidHost =
            _readEnv('SERVER_HOST_ANDROID', fallback: _defaultLanHost);
        return androidHost.trim().isEmpty ? _defaultLanHost : androidHost.trim();
      case TargetPlatform.iOS:
        final iosHost =
            _readEnv('SERVER_HOST_IOS', fallback: _defaultLanHost);
        return iosHost.trim().isEmpty ? _defaultLanHost : iosHost.trim();
      default:
        return _defaultLanHost;
    }
  }

  // ----- URL helpers -----
  static String get baseOrigin => '$_scheme://$serverHost:$_port';
  static String get baseUrl => '$baseOrigin/api';
  static String get wsUrl => baseOrigin;

  /// API public để các module khác đọc env (ví dụ các khoá khác trong tương lai).
  static String getEnv(String key, {String fallback = ''}) =>
      _readEnv(key, fallback: fallback);

  // ----- Helpers -----
  static String _readEnv(String key, {required String fallback}) {
    try {
      final value = dotenv.env[key];
      if (value == null) return fallback;
      return value;
    } catch (_) {
      // dotenv chưa được load (ví dụ trong test) -> trả về fallback.
      return fallback;
    }
  }

  static String resolveMediaUrl(String url) {
    if (url.isEmpty) return url;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('data:')) return url; // Base64 data URI
    if (url.startsWith('/')) return '$baseOrigin$url';
    return url;
  }

  /// In cấu hình hiện tại ra log - tiện cho việc debug khi build.
  static void debugPrintConfig() {
    debugPrint('[AppConfig] scheme=$_scheme host=$serverHost port=$_port');
    debugPrint('[AppConfig] baseUrl=$baseUrl  wsUrl=$wsUrl');
  }
}