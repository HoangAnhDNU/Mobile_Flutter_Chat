import 'package:flutter/services.dart';

class KeepAliveService {
  static const _channel = MethodChannel('com.example.mobile_flutter_chat/keep_alive');

  static Future<void> start() async {
    try {
      await _channel.invokeMethod('startKeepAlive');
    } on PlatformException catch (e) {
      print('Failed to start keep alive: ${e.message}');
    }
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopKeepAlive');
    } on PlatformException catch (e) {
      print('Failed to stop keep alive: ${e.message}');
    }
  }
}
