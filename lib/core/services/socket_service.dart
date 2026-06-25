import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../constants/app_config.dart';

class SocketService {
  static SocketService? _instance;
  io.Socket? _socket;
  String? _uid;
  bool _isConnected = false;
  int? _currentChatId;
  final Map<String, bool> _presenceCache = {};

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _presenceController = StreamController<Map<String, dynamic>>.broadcast();
  final _deliveryController = StreamController<Map<String, dynamic>>.broadcast();
  final _reactionController = StreamController<Map<String, dynamic>>.broadcast();
  final _deleteController = StreamController<Map<String, dynamic>>.broadcast();
  final _pinController = StreamController<Map<String, dynamic>>.broadcast();
  final _editController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectController = StreamController<void>.broadcast();

  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;
  Stream<Map<String, dynamic>> get onTyping => _typingController.stream;
  Stream<Map<String, dynamic>> get onPresence => _presenceController.stream;
  Stream<Map<String, dynamic>> get onDelivery => _deliveryController.stream;
  Stream<Map<String, dynamic>> get onReaction => _reactionController.stream;
  Stream<Map<String, dynamic>> get onDelete => _deleteController.stream;
  Stream<Map<String, dynamic>> get onPin => _pinController.stream;
  Stream<Map<String, dynamic>> get onEdit => _editController.stream;
  Stream<void> get onConnect => _connectController.stream;

  Map<String, bool> get presenceCache => _presenceCache;

  bool get isConnected => _isConnected;

  static SocketService get instance {
    _instance ??= SocketService._();
    return _instance!;
  }

  SocketService._();

  void connect(String uid) {
    _uid = uid;
    if (_socket != null && _isConnected) {
      return;
    }
    // Dispose old socket if exists
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
    try {
      _socket = io.io(
        AppConfig.wsUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .setReconnectionDelay(3000)
            .build(),
      );

      _socket!
        ..onConnect((_) {
          _isConnected = true;
          _connectController.add(null);
          debugPrint('[SOCKET] Connected, emitting user_online with uid=$uid');
          _socket!.emit('user_online', uid);
          // Tự động vào lại phòng chat hiện tại sau khi kết nối thành công
          // (tránh race condition khi joinChat được gọi lúc socket chưa connect).
          if (_currentChatId != null) {
            _socket!.emit('join_chat', _currentChatId);
          }
        })
        ..on('new_message', (data) => _messageController.add(_toMap(data)))
        ..on('user_typing', (data) => _typingController.add(_toMap(data)))
        ..on('presence_update', (data) {
          final map = _toMap(data);
          final uid = map['uid']?.toString();
          final isOnline = map['is_online'] == true;
          debugPrint('[SOCKET] presence_update: uid=$uid isOnline=$isOnline');
          if (uid != null) {
            _presenceCache[uid] = isOnline;
          }
          _presenceController.add(map);
        })
        ..on('delivery_update', (data) => _deliveryController.add(_toMap(data)))
        ..on('reaction_update', (data) => _reactionController.add(_toMap(data)))
        ..on('message_deleted', (data) => _deleteController.add(_toMap(data)))
        ..on('message_edited', (data) => _editController.add(_toMap(data)))
        ..on('pin_update', (data) => _pinController.add(_toMap(data)))
        ..onDisconnect((_) {
          _isConnected = false;
        })
        ..onConnectError((error) {
          _isConnected = false;
        })
        ..connect();
    } catch (e) {
      _isConnected = false;
    }
  }

  Map<String, dynamic> _toMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    return {'value': data};
  }

  void joinChat(int chatId) {
    _currentChatId = chatId;
    if (_socket != null && _isConnected) {
      _socket!.emit('join_chat', chatId);
    }
  }

  void leaveChat(int chatId) {
    if (_currentChatId == chatId) {
      _currentChatId = null;
    }
    if (_socket != null && _isConnected) {
      _socket!.emit('leave_chat', chatId);
    }
  }

  void sendTyping(int chatId, bool isTyping) {
    if (_socket != null && _isConnected) {
      _socket!.emit('typing', {
        'chatId': chatId,
        'uid': _uid,
        'isTyping': isTyping,
      });
    }
  }

  void sendMessageDelivered(int messageId, String senderUid) {
    if (_socket != null && _isConnected) {
      _socket!.emit('message_delivered', {
        'messageId': messageId,
        'senderUid': senderUid,
      });
    }
  }

  void sendMessageRead(int messageId, String senderUid) {
    if (_socket != null && _isConnected) {
      _socket!.emit('message_read', {
        'messageId': messageId,
        'senderUid': senderUid,
      });
    }
  }

  void sendMessage(Map<String, dynamic> data) {
    if (_socket != null && _isConnected) {
      _socket!.emit('send_message', data);
    }
  }

  void sendReaction(int chatId, int messageId, String emoji) {
    if (_socket != null && _isConnected) {
      _socket!.emit('add_reaction', {
        'chatId': chatId,
        'messageId': messageId,
        'userUid': _uid,
        'emoji': emoji,
      });
    }
  }

  void disconnect() {
    _isConnected = false;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _typingController.close();
    _presenceController.close();
    _deliveryController.close();
    _reactionController.close();
    _deleteController.close();
    _pinController.close();
    _editController.close();
    _connectController.close();
    _instance = null;
  }
}
