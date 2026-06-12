import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../constants/app_config.dart';

class SocketService {
  static SocketService? _instance;
  io.Socket? _socket;
  String? _uid;
  bool _isConnected = false;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _presenceController = StreamController<Map<String, dynamic>>.broadcast();
  final _deliveryController = StreamController<Map<String, dynamic>>.broadcast();
  final _reactionController = StreamController<Map<String, dynamic>>.broadcast();
  final _deleteController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;
  Stream<Map<String, dynamic>> get onTyping => _typingController.stream;
  Stream<Map<String, dynamic>> get onPresence => _presenceController.stream;
  Stream<Map<String, dynamic>> get onDelivery => _deliveryController.stream;
  Stream<Map<String, dynamic>> get onReaction => _reactionController.stream;
  Stream<Map<String, dynamic>> get onDelete => _deleteController.stream;
  Stream<bool> get onConnectionChange => _connectionController.stream;

  bool get isConnected => _isConnected;

  static SocketService get instance {
    _instance ??= SocketService._();
    return _instance!;
  }

  SocketService._();

  void connect(String uid) {
    _uid = uid;
    disconnect();

    final serverUrl = 'http://${AppConfig.serverHost}:${AppConfig.serverPort}';
    debugPrint('[Socket] Connecting to $serverUrl ...');

    _socket = io.io(serverUrl, io.OptionBuilder()
      .setTransports(['websocket'])
      .disableAutoConnect()
      .enableReconnection()
      .setReconnectionDelay(3000)
      .setReconnectionAttempts(99999)
      .build());

    _socket!.onConnect((_) {
      debugPrint('[Socket] Connected');
      _isConnected = true;
      _connectionController.add(true);
      _socket!.emit('user_online', uid);
    });

    _socket!.onDisconnect((_) {
      debugPrint('[Socket] Disconnected');
      _isConnected = false;
      _connectionController.add(false);
    });

    _socket!.onConnectError((err) {
      debugPrint('[Socket] Connection error: $err');
      _isConnected = false;
      _connectionController.add(false);
    });

    _socket!.onReconnect((_) {
      debugPrint('[Socket] Reconnected');
      _isConnected = true;
      _connectionController.add(true);
      _socket!.emit('user_online', uid);
    });

    _socket!.on('new_message', (data) {
      if (data is Map) {
        _messageController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('user_typing', (data) {
      if (data is Map) {
        _typingController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('presence_update', (data) {
      if (data is Map) {
        _presenceController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('delivery_update', (data) {
      if (data is Map) {
        _deliveryController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('reaction_update', (data) {
      if (data is Map) {
        _reactionController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('message_deleted', (data) {
      if (data is Map) {
        _deleteController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.connect();
  }

  void joinChat(int chatId) {
    _socket?.emit('join_chat', chatId);
  }

  void leaveChat(int chatId) {
    _socket?.emit('leave_chat', chatId);
  }

  void sendTyping(int chatId, bool isTyping) {
    _socket?.emit('typing', {
      'chatId': chatId,
      'uid': _uid,
      'isTyping': isTyping,
    });
  }

  void sendMessageDelivered(int messageId, String senderUid) {
    _socket?.emit('message_delivered', {
      'messageId': messageId,
      'senderUid': senderUid,
    });
  }

  void sendMessageRead(int messageId, String senderUid) {
    _socket?.emit('message_read', {
      'messageId': messageId,
      'senderUid': senderUid,
    });
  }

  void sendReaction(int chatId, int messageId, String emoji) {
    _socket?.emit('add_reaction', {
      'chatId': chatId,
      'messageId': messageId,
      'userUid': _uid,
      'emoji': emoji,
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _typingController.close();
    _presenceController.close();
    _deliveryController.close();
    _reactionController.close();
    _deleteController.close();
    _connectionController.close();
    _instance = null;
  }
}
