import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../constants/app_config.dart';

@JS('console.log')
external void jsConsoleLog(String message);

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
  final _callOfferController = StreamController<Map<String, dynamic>>.broadcast();
  final _callAnswerController = StreamController<Map<String, dynamic>>.broadcast();
  final _callIceController = StreamController<Map<String, dynamic>>.broadcast();
  final _callEndController = StreamController<Map<String, dynamic>>.broadcast();
  final _callRejectController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;
  Stream<Map<String, dynamic>> get onTyping => _typingController.stream;
  Stream<Map<String, dynamic>> get onPresence => _presenceController.stream;
  Stream<Map<String, dynamic>> get onDelivery => _deliveryController.stream;
  Stream<Map<String, dynamic>> get onReaction => _reactionController.stream;
  Stream<Map<String, dynamic>> get onDelete => _deleteController.stream;
  Stream<Map<String, dynamic>> get onPin => _pinController.stream;
  Stream<Map<String, dynamic>> get onEdit => _editController.stream;
  Stream<void> get onConnect => _connectController.stream;
  Stream<Map<String, dynamic>> get onCallOffer => _callOfferController.stream;
  Stream<Map<String, dynamic>> get onCallAnswer => _callAnswerController.stream;
  Stream<Map<String, dynamic>> get onCallIce => _callIceController.stream;
  Stream<Map<String, dynamic>> get onCallEnd => _callEndController.stream;
  Stream<Map<String, dynamic>> get onCallReject => _callRejectController.stream;

  Map<String, bool> get presenceCache => _presenceCache;

  bool get isConnected => _isConnected;
  int? get currentChatId => _currentChatId;

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
        ..onAny((event, data) {
          if (kIsWeb && event.startsWith('call_')) {
            jsConsoleLog('[SOCKET onAny] event=$event');
          }
        })
        ..onConnect((_) {
          _isConnected = true;
          _connectController.add(null);
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
        ..on('call_offer', (data) {
          // Also log to browser console for web debugging
          if (kIsWeb) {
            jsConsoleLog('[CALL] Received call_offer from ${data is Map ? data['fromUid'] : data}');
          }
          _callOfferController.add(_toMap(data));
        })
        ..on('call_answer', (data) => _callAnswerController.add(_toMap(data)))
        ..on('call_ice_candidate', (data) => _callIceController.add(_toMap(data)))
        ..on('call_end', (data) => _callEndController.add(_toMap(data)))
        ..on('call_reject', (data) => _callRejectController.add(_toMap(data)))
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
      _socket!.emit('new_message', data);
    }
  }

  void injectMessage(Map<String, dynamic> data) {
    _messageController.add(data);
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

  void sendCallOffer(String targetUid, bool isVideo, String callerName, Map<String, dynamic> sdp, [String? callerAvatar]) {
    if (_socket != null && _isConnected) {
      _socket!.emit('call_offer', {
        'targetUid': targetUid,
        'isVideo': isVideo,
        'callerName': callerName,
        'callerAvatar': callerAvatar,
        'sdp': sdp,
      });
    }
  }

  void sendCallAnswer(String targetUid, Map<String, dynamic> sdp) {
    if (_socket != null && _isConnected) {
      _socket!.emit('call_answer', {
        'targetUid': targetUid,
        'sdp': sdp,
      });
    }
  }

  void sendCallIceCandidate(String targetUid, Map<String, dynamic> candidate) {
    if (_socket != null && _isConnected) {
      _socket!.emit('call_ice_candidate', {
        'targetUid': targetUid,
        'candidate': candidate,
      });
    }
  }

  void sendCallEnd(String targetUid) {
    if (_socket != null && _isConnected) {
      _socket!.emit('call_end', {'targetUid': targetUid});
    }
  }

  void sendCallReject(String targetUid) {
    if (_socket != null && _isConnected) {
      _socket!.emit('call_reject', {'targetUid': targetUid});
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
    _callOfferController.close();
    _callAnswerController.close();
    _callIceController.close();
    _callEndController.close();
    _callRejectController.close();
    _instance = null;
  }
}
