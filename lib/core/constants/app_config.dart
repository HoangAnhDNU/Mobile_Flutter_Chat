import 'package:flutter/foundation.dart';

class AppConfig {
  static const int serverPort = 3000;

  static String get serverHost {
    if (kIsWeb) {
      return 'localhost';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return '10.0.2.2';
    }

    return 'localhost';
  }

  static String get baseOrigin => 'http://$serverHost:$serverPort';
  static String get baseUrl => '$baseOrigin/api';
  static String get wsUrl => 'ws://$serverHost:$serverPort';

  static String resolveMediaUrl(String url) {
    if (url.isEmpty) return url;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('/')) return '$baseOrigin$url';
    return url;
  }
}
