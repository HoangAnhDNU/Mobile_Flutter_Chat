import 'package:flutter/foundation.dart';

class AppConfig {
  static const int serverPort = 3000;

  // Cấu hình IP máy chủ cho real device (thay IP LAN của bạn)
  static const String lanHost = '192.168.61.219';

  static String get serverHost {
    if (kIsWeb) {
      return 'localhost';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      // Dùng IP LAN cho real device, 10.0.2.2 cho emulator
      return lanHost;
    }

    return 'localhost';
  }

  static String get baseOrigin => 'http://$serverHost:$serverPort';
  static String get baseUrl => '$baseOrigin/api';
  static String get wsUrl => 'ws://$serverHost:$serverPort';

  static String resolveMediaUrl(String url) {
    if (url.isEmpty) return url;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('data:')) return url; // Base64 data URI
    if (url.startsWith('/')) return '$baseOrigin$url';
    return url;
  }
}
