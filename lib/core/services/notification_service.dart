import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static NotificationService? _instance;
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // User's notification settings
  String _messageSound = 'default';
  String _callSound = 'default';
  bool _isMessageVibration = true;
  bool _isCallVibration = true;
  bool _isMessagePreview = true;

  static NotificationService get instance {
    _instance ??= NotificationService._();
    return _instance!;
  }

  NotificationService._();

  // Getter for sound settings
  String get messageSound => _messageSound;
  String get callSound => _callSound;
  bool get isMessageVibration => _isMessageVibration;
  bool get isCallVibration => _isCallVibration;
  bool get isMessagePreview => _isMessagePreview;

  // Update settings from server
  void updateSettings({
    String? messageSound,
    String? callSound,
    bool? isMessageVibration,
    bool? isCallVibration,
    bool? isMessagePreview,
  }) {
    if (messageSound != null) _messageSound = messageSound;
    if (callSound != null) _callSound = callSound;
    if (isMessageVibration != null) _isMessageVibration = isMessageVibration;
    if (isCallVibration != null) _isCallVibration = isCallVibration;
    if (isMessagePreview != null) _isMessagePreview = isMessagePreview;
  }

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create high-priority notification channel with sound
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'chat_messages',
          'Tin nhắn chat',
          description: 'Thông báo tin nhắn mới',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          enableLights: true,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'incoming_calls',
          'Cuộc gọi đến',
          description: 'Thông báo cuộc gọi đến',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
        ),
      );
    }

    _initialized = true;
  }

  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && kIsWeb == false) {
      try {
        final parts = payload.split('|');
        if (parts.length >= 2) {
          final chatId = int.tryParse(parts[0]);
          final chatName = parts.sublist(1).join('|');
          if (chatId != null && _onNotificationTap != null) {
            _onNotificationTap!(chatId, chatName);
          }
        }
      } catch (_) {}
    }
  }

  void Function(int chatId, String chatName)? _onNotificationTap;

  void setOnNotificationTap(void Function(int chatId, String chatName)? callback) {
    _onNotificationTap = callback;
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      return granted ?? false;
    }
    return false;
  }

  Future<void> showMessageNotification({
    required int chatId,
    required String senderName,
    required String preview,
    required String messageType,
    String? chatName,
  }) async {
    if (!_initialized || kIsWeb) return;

    final title = chatName != null ? '$senderName ($chatName)' : senderName;

    String body;
    if (messageType == 'image') {
      body = 'Đã gửi một hình ảnh';
    } else if (messageType == 'voice') {
      body = 'Đã gửi một tin nhắn thoại';
    } else if (messageType == 'file') {
      body = 'Đã gửi một tệp đính kèm';
    } else if (!_isMessagePreview) {
      body = 'Bạn có một tin nhắn mới';
    } else {
      body = preview.length > 200 ? '${preview.substring(0, 200)}...' : preview;
    }

    // Build sound based on user settings
    String? soundName;
    if (_messageSound != 'default' && _messageSound != 'none') {
      soundName = _messageSound;
    }

    final androidDetails = AndroidNotificationDetails(
      'chat_messages',
      'Tin nhắn chat',
      channelDescription: 'Thông báo tin nhắn mới',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      playSound: _messageSound != 'none',
      enableVibration: _isMessageVibration,
      category: AndroidNotificationCategory.message,
      styleInformation: BigTextStyleInformation(''),
      sound: soundName != null ? RawResourceAndroidNotificationSound(soundName) : null,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: _messageSound != 'none',
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // payload = chatId|chatName
    final payload = '$chatId|${chatName ?? senderName}';

    await _plugin.show(
      chatId,
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> showIncomingCallNotification({
    required String callerName,
    required bool isVideo,
    String? callerAvatar,
  }) async {
    if (!_initialized || kIsWeb) return;

    final androidDetails = AndroidNotificationDetails(
      'incoming_calls',
      'Cuộc gọi đến',
      channelDescription: 'Thông báo cuộc gọi đến',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      playSound: _callSound != 'none',
      enableVibration: _isCallVibration,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true,
      timeoutAfter: 30000, // Auto dismiss after 30s if not answered
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final title = isVideo ? 'Cuộc gọi video đến' : 'Cuộc gọi thoại đến';

    await _plugin.show(
      999999, // Special ID for call notifications
      title,
      '$callerName đang gọi cho bạn...',
      details,
    );
  }

  Future<void> cancelCallNotification() async {
    await _plugin.cancel(999999);
  }

  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }
}
