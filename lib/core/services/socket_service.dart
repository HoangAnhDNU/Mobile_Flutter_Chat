import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import '../constants/app_config.dart';

class SocketService {
  static SocketService? _instance;
  WebSocketChannel? _channel;
  String? _uid;
  bool _isConnected = false;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _presenceController = StreamController<Map<String, dynamic>>.broadcast();
  final _deliveryController = StreamController<Map<String, dynamic>>.broadcast();
  final _reactionController = StreamController<Map<String, dynamic>>.broadcast();
  final _deleteController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;
  Stream<Map<String, dynamic>> get onTyping => _typingController.stream;
  Stream<Map<String, dynamic>> get onPresence => _presenceController.stream;
  Stream<Map<String, dynamic>> get onDelivery => _deliveryController.stream;
  Stream<Map<String, dynamic>> get onReaction => _reactionController.stream;
  Stream<Map<String, dynamic>> get onDelete => _deleteController.stream;

  bool get isConnected => _isConnected;

  static SocketService get instance {
    _instance ??= SocketService._();
    return _instance!;
  }

  SocketService._();

  void connect(String uid) {
    _uid = uid;
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse(AppConfig.wsUrl),
      );
      _isConnected = true;

      // Send user_online event
      _send({'event': 'user_online', 'data': uid});

      _channel!.stream.listen(
        (data) {
          final message = jsonDecode(data as String) as Map<String, dynamic>;
          _handleEvent(message);
        },
        onDone: () {
          _isConnected = false;
          _reconnect();
        },
        onError: (error) {
          _isConnected = false;
          _reconnect();
        },
      );
    } catch (e) {
      _isConnected = false;
    }
  }

  void _handleEvent(Map<String, dynamic> message) {
    final event = message['event'] as String?;
    final data = message['data'] as Map<String, dynamic>?;
    if (event == null || data == null) return;

    switch (event) {
      case 'new_message':
        _messageController.add(data);
        break;
      case 'user_typing':
        _typingController.add(data);
        break;
      case 'presence_update':
        _presenceController.add(data);
        break;
      case 'delivery_update':
        _deliveryController.add(data);
        break;
      case 'reaction_update':
        _reactionController.add(data);
        break;
      case 'message_deleted':
        _deleteController.add(data);
        break;
    }
  }

  void _send(Map<String, dynamic> data) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  void joinChat(int chatId) {
    _send({'event': 'join_chat', 'data': chatId});
  }

  void leaveChat(int chatId) {
    _send({'event': 'leave_chat', 'data': chatId});
  }

  void sendTyping(int chatId, bool isTyping) {
    _send({
      'event': 'typing',
      'data': {'chatId': chatId, 'uid': _uid, 'isTyping': isTyping},
    });
  }

  void sendMessageDelivered(int messageId, String senderUid) {
    _send({
      'event': 'message_delivered',
      'data': {'messageId': messageId, 'senderUid': senderUid},
    });
  }

  void sendMessageRead(int messageId, String senderUid) {
    _send({
      'event': 'message_read',
      'data': {'messageId': messageId, 'senderUid': senderUid},
    });
  }

  void sendReaction(int chatId, int messageId, String emoji) {
    _send({
      'event': 'add_reaction',
      'data': {'chatId': chatId, 'messageId': messageId, 'userUid': _uid, 'emoji': emoji},
    });
  }

  void _reconnect() {
    if (_uid != null) {
      Future.delayed(const Duration(seconds: 3), () {
        if (!_isConnected) connect(_uid!);
      });
    }
  }

  void disconnect() {
    _isConnected = false;
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _typingController.close();
    _presenceController.close();
    _deliveryController.close();
    _reactionController.close();
    _deleteController.close();
    _instance = null;
  }
}
