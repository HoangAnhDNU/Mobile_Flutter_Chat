import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_config.dart';

/// ApiService - lớp adapter giao tiếp với backend Python (FastAPI).
///
/// Backend Python trả về dữ liệu dạng snake_case với shape riêng
/// (ví dụ {chats: [...], total}, message dùng "content"/"type"/"status").
/// Lớp này chuyển đổi (adapt) các response đó về đúng định dạng mà
/// các màn hình UI hiện có đang đọc (text, sender_uid, otherUser, chat_name...).
class ApiService {
  static String get baseUrl => AppConfig.baseUrl;
  static const Duration _timeout = Duration(seconds: 15);
  static String? _token;
  static String? _uid;

  static String? get uid => _uid;
  static bool get isLoggedIn => _token != null && _uid != null;

  // ==================== HTTP helpers ====================

  static Future<http.Response> _get(Uri url, {Map<String, String>? headers}) =>
      http.get(url, headers: headers).timeout(_timeout);

  static Future<http.Response> _post(Uri url, {Map<String, String>? headers, Object? body}) =>
      http.post(url, headers: headers, body: body).timeout(_timeout);

  static Future<http.Response> _put(Uri url, {Map<String, String>? headers, Object? body}) =>
      http.put(url, headers: headers, body: body).timeout(_timeout);

  static Future<http.Response> _delete(Uri url, {Map<String, String>? headers, Object? body}) =>
      http.delete(url, headers: headers, body: body).timeout(_timeout);

  /// Decode body với UTF-8 để hiển thị tiếng Việt chính xác.
  static dynamic _decode(http.Response response) {
    if (response.bodyBytes.isEmpty) return {};
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (e) {
      debugPrint('Failed to decode response: ${response.body}');
      return {'error': 'Server error: ${response.statusCode}'};
    }
  }

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  // ==================== Token / Session ====================

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    _uid = prefs.getString('uid');
  }

  static Future<void> saveToken(String token, String uid) async {
    _token = token;
    _uid = uid;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('uid', uid);
  }

  static Future<void> clearToken() async {
    _token = null;
    _uid = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('uid');
  }

  // ==================== Adapters ====================

  /// Chuẩn hóa user về map có cả snake_case và camelCase để mọi màn dùng được.
  static Map<String, dynamic> _adaptUser(Map<String, dynamic> u) {
    final id = u['id']?.toString() ?? u['uid']?.toString() ?? '';
    return {
      'uid': id,
      'id': id,
      'email': u['email'] ?? '',
      'display_name': u['display_name'] ?? u['displayName'] ?? '',
      'displayName': u['display_name'] ?? u['displayName'] ?? '',
      'avatar_url': u['avatar_url'] ?? u['avatarUrl'] ?? '',
      'avatarUrl': u['avatar_url'] ?? u['avatarUrl'] ?? '',
      'role': u['role'] ?? 'user',
      'is_locked': u['is_locked'] ?? false,
      'is_online': u['is_online'] ?? false,
    };
  }

  /// Chuyển message của backend Python về định dạng UI đang đọc.
  static Map<String, dynamic> _adaptMessage(Map<String, dynamic> m) {
    return {
      'id': int.tryParse(m['id']?.toString() ?? '') ?? 0,
      'text': m['content'] ?? '',
      'sender_uid': m['sender_id']?.toString() ?? '',
      'sender_name': m['sender_name'] ?? '',
      'sender_avatar': m['sender_avatar'],
      'created_at': m['created_at'],
      'is_edited': m['edited_at'] != null,
      'message_type': m['type'] ?? 'text',
      'imageUrl': m['media_url'],
      'image_base64': null,
      'voice_duration': 0,
      'delivery_status': m['status'] ?? 'sent',
      'reply_to_text': null,
      'reply_to_sender': null,
      'is_pinned': m['is_pinned'] == true,
      'is_deleted': m['is_deleted'] == true,
      'forwarded': m['forwarded'] == true,
      'image_label': m['image_label'],
      'reactions': (m['reactions'] as List?)
              ?.map((r) => Map<String, dynamic>.from(r as Map))
              .toList() ??
          [],
    };
  }

  /// Chuyển chat của backend Python về định dạng UI (chat list) đang đọc.
  static Map<String, dynamic> _adaptChat(Map<String, dynamic> c) {
    final isGroup = c['is_group'] == true;
    final participants = (c['participants'] as List?)
            ?.map((p) => Map<String, dynamic>.from(p as Map))
            .toList() ??
        [];

    String chatName;
    Map<String, dynamic>? otherUser;
    String avatarUrl = c['avatar_url']?.toString() ?? '';

    if (isGroup) {
      chatName = (c['name']?.toString().isNotEmpty == true) ? c['name'] : 'Nhóm';
    } else {
      Map<String, dynamic>? other;
      for (final p in participants) {
        if (p['id']?.toString() != _uid) {
          other = p;
          break;
        }
      }
      other ??= participants.isNotEmpty ? participants.first : null;
      if (other != null) {
        otherUser = _adaptUser(other);
        chatName = otherUser['display_name'];
        avatarUrl = otherUser['avatar_url'];
      } else {
        chatName = c['name']?.toString() ?? '';
      }
    }

    final lastMessage = c['last_message'] as Map?;

    return {
      'id': int.tryParse(c['id']?.toString() ?? '') ?? 0,
      'chat_name': chatName,
      'otherUser': otherUser,
      'avatar_url': avatarUrl,
      'is_group': isGroup,
      'last_message': lastMessage?['content'] ?? '',
      'last_message_time': lastMessage?['created_at'],
      'last_message_sender_uid': lastMessage?['sender_id']?.toString() ?? '',
      'last_message_sender_name': lastMessage?['sender_name']?.toString() ?? '',
    };
  }

  // ==================== Auth ====================

  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'display_name': displayName,
        }),
      );

      final data = _decode(response) as Map<String, dynamic>;
      if (response.statusCode == 200 || response.statusCode == 201) {
        final user = _adaptUser(Map<String, dynamic>.from(data['user']));
        await saveToken(data['token'], user['uid']);
        return {'user': user, 'token': data['token']};
      }
      return {'error': data['detail'] ?? data['message'] ?? 'Đăng ký thất bại'};
    } catch (e) {
      return {'error': 'Không thể kết nối đến máy chủ'};
    }
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final data = _decode(response) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        final user = _adaptUser(Map<String, dynamic>.from(data['user']));
        await saveToken(data['token'], user['uid']);
        return {'user': user, 'token': data['token']};
      }
      return {'error': data['detail'] ?? data['message'] ?? 'Đăng nhập thất bại'};
    } catch (e) {
      return {'error': 'Không thể kết nối đến máy chủ'};
    }
  }

  static Future<void> logout() async {
    try {
      await _post(Uri.parse('$baseUrl/auth/logout'), headers: _headers);
    } catch (_) {
      // Bỏ qua lỗi khi đăng xuất
    }
    await clearToken();
  }

  // ==================== User ====================

  /// Lấy danh sách user. Backend chỉ có /user/search?q= (bắt buộc q>=1 ký tự),
  /// dùng "@" để khớp mọi email -> liệt kê được tất cả user khác.
  static Future<List<dynamic>> getUsers() async {
    try {
      final response = await _get(
        Uri.parse('$baseUrl/user/search?q=@&page=1&limit=100'),
        headers: _headers,
      );
      if (response.statusCode != 200) return [];
      final data = _decode(response);
      final users = (data is Map ? data['users'] : data) as List? ?? [];
      return users.map((u) => _adaptUser(Map<String, dynamic>.from(u as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<dynamic>> searchUsers(String query) async {
    if (query.trim().isEmpty) return getUsers();
    try {
      final response = await _get(
        Uri.parse('$baseUrl/user/search?q=${Uri.encodeComponent(query)}&page=1&limit=50'),
        headers: _headers,
      );
      if (response.statusCode != 200) return [];
      final data = _decode(response);
      final users = (data is Map ? data['users'] : data) as List? ?? [];
      return users.map((u) => _adaptUser(Map<String, dynamic>.from(u as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> getUser(String uid) async {
    final response = await _get(
      Uri.parse('$baseUrl/user/$uid'),
      headers: _headers,
    );
    final data = _decode(response) as Map<String, dynamic>;
    if (data['user'] != null) {
      return _adaptUser(Map<String, dynamic>.from(data['user']));
    }
    return {};
  }

  static Future<Map<String, dynamic>> updateUser(
    String uid, {
    String? displayName,
    String? avatarUrl,
  }) async {
    final response = await _put(
      Uri.parse('$baseUrl/user/me'),
      headers: _headers,
      body: jsonEncode({
        if (displayName != null) 'display_name': displayName,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      }),
    );
    final data = _decode(response) as Map<String, dynamic>;
    if (data['user'] != null) {
      return _adaptUser(Map<String, dynamic>.from(data['user']));
    }
    return data;
  }

  /// Backend chưa có endpoint cập nhật trạng thái online -> bỏ qua.
  static Future<void> updateOnlineStatus(String uid, bool isOnline) async {}

  /// Đổi mật khẩu. Trả về {ok, message/error}.
  static Future<Map<String, dynamic>> changePassword(String oldPassword, String newPassword) async {
    final response = await _post(
      Uri.parse('$baseUrl/user/change-password'),
      headers: _headers,
      body: jsonEncode({'old_password': oldPassword, 'new_password': newPassword}),
    );
    final data = _decode(response) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      return {'ok': true, 'message': data['message'] ?? 'Đổi mật khẩu thành công'};
    }
    return {'ok': false, 'error': data['detail'] ?? 'Đổi mật khẩu thất bại'};
  }

  // ==================== Chat ====================

  static Future<List<dynamic>> getChats() async {
    final response = await _get(
      Uri.parse('$baseUrl/chat?page=1&limit=50'),
      headers: _headers,
    );
    if (response.statusCode != 200) return [];
    final data = _decode(response);
    final chats = (data is Map ? data['chats'] : data) as List? ?? [];
    return chats.map((c) => _adaptChat(Map<String, dynamic>.from(c as Map))).toList();
  }

  static Future<List<dynamic>> getMessages(int chatId) async {
    final response = await _get(
      Uri.parse('$baseUrl/chat/$chatId/messages?page=1&limit=100'),
      headers: _headers,
    );
    if (response.statusCode != 200) return [];
    final data = _decode(response);
    final messages = (data is Map ? data['messages'] : data) as List? ?? [];
    return messages.map((m) => _adaptMessage(Map<String, dynamic>.from(m as Map))).toList();
  }

  /// Tạo chat. participants gồm uid của mình + các uid khác.
  /// Có chatName hoặc nhiều hơn 1 người khác -> tạo nhóm, ngược lại chat 1-1.
  static Future<Map<String, dynamic>> createChat({
    required List<String> participants,
    required String createdBy,
    String? chatName,
  }) async {
    final others = participants.where((p) => p != createdBy).toList();
    final isGroup = (chatName != null && chatName.isNotEmpty) || others.length > 1;

    try {
      final http.Response response;
      if (isGroup) {
        response = await _post(
          Uri.parse('$baseUrl/chat/group'),
          headers: _headers,
          body: jsonEncode({
            'name': chatName ?? 'Nhóm mới',
            'participant_ids': others,
          }),
        );
      } else {
        response = await _post(
          Uri.parse('$baseUrl/chat/direct'),
          headers: _headers,
          body: jsonEncode({'user_id': others.isNotEmpty ? others.first : ''}),
        );
      }

      debugPrint('createChat response status: ${response.statusCode}');

      final data = _decode(response) as Map<String, dynamic>;
      final chat = data['chat'] as Map?;
      final chatId = int.tryParse(chat?['id']?.toString() ?? '') ?? 0;
      return {'chatId': chatId, 'chat': chat};
    } catch (e) {
      debugPrint('createChat error: $e');
      final chats = await getChats();
      for (final c in chats) {
        final cm = c as Map<String, dynamic>;
        final cId = int.tryParse(cm['id']?.toString() ?? '') ?? 0;
        final cIsGroup = cm['is_group'] == true;
        final otherUser = cm['otherUser'] as Map?;
        if (!cIsGroup && others.isNotEmpty) {
          if (otherUser?['uid']?.toString() == others.first) {
            return {'chatId': cId, 'chat': cm};
          }
        }
        if (cIsGroup && chatName != null && chatName.isNotEmpty) {
          if (cm['chat_name']?.toString() == chatName) {
            return {'chatId': cId, 'chat': cm};
          }
        }
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> sendMessage({
    required int chatId,
    required String senderUid,
    required String senderName,
    required String text,
    String messageType = 'text',
    String? imageBase64,
    String? voiceBase64,
    int? voiceDuration,
  }) async {
    // Backend yêu cầu content tối thiểu 1 ký tự.
    final content = text.isNotEmpty
        ? text
        : (messageType == 'image'
            ? '[Hình ảnh]'
            : messageType == 'voice'
                ? '[Tin nhắn thoại]'
                : ' ');
    // Ảnh/âm thanh được lưu dưới dạng data URI base64 trong media_url.
    String? mediaUrl;
    if (messageType == 'image' && imageBase64 != null) {
      mediaUrl = imageBase64.startsWith('data:') ? imageBase64 : 'data:image/png;base64,$imageBase64';
    } else if (messageType == 'voice' && voiceBase64 != null) {
      mediaUrl = voiceBase64.startsWith('data:') ? voiceBase64 : 'data:audio/m4a;base64,$voiceBase64';
    }
    final response = await _post(
      Uri.parse('$baseUrl/chat/$chatId/messages'),
      headers: _headers,
      body: jsonEncode({
        'content': content,
        'type': messageType,
        if (mediaUrl != null) 'media_url': mediaUrl,
      }),
    );
    final data = _decode(response) as Map<String, dynamic>;
    if (data['message'] != null) {
      return _adaptMessage(Map<String, dynamic>.from(data['message']));
    }
    return {};
  }

  static Future<Map<String, dynamic>> sendReplyMessage({
    required int chatId,
    required String senderUid,
    required String senderName,
    required String text,
    String messageType = 'text',
    String? imageBase64,
    String? voiceBase64,
    int? voiceDuration,
    int? replyToId,
    String? replyToText,
    String? replyToSender,
  }) async {
    final content = text.isNotEmpty ? text : ' ';
    final response = await _post(
      Uri.parse('$baseUrl/chat/$chatId/messages'),
      headers: _headers,
      body: jsonEncode({
        'content': content,
        'type': messageType,
        if (replyToId != null) 'reply_to_id': replyToId.toString(),
      }),
    );
    final data = _decode(response) as Map<String, dynamic>;
    if (data['message'] != null) {
      return _adaptMessage(Map<String, dynamic>.from(data['message']));
    }
    return {};
  }

  static Future<void> updateMessage(int messageId, String text) async {
    await _put(
      Uri.parse('$baseUrl/chat/messages/$messageId'),
      headers: _headers,
      body: jsonEncode({'content': text}),
    );
  }

  static Future<void> deleteMessage(int messageId) async {
    await _delete(
      Uri.parse('$baseUrl/chat/messages/$messageId?for_everyone=false'),
      headers: _headers,
    );
  }

  static Future<void> deleteForMe(int messageId) async {
    await _delete(
      Uri.parse('$baseUrl/chat/messages/$messageId?for_everyone=false'),
      headers: _headers,
    );
  }

  static Future<void> deleteForEveryone(int messageId) async {
    await _delete(
      Uri.parse('$baseUrl/chat/messages/$messageId?for_everyone=true'),
      headers: _headers,
    );
  }

  /// Xóa toàn bộ lịch sử tin nhắn của một cuộc trò chuyện.
  static Future<bool> clearChat(int chatId) async {
    final response = await _delete(Uri.parse('$baseUrl/chat/$chatId/messages'), headers: _headers);
    return response.statusCode == 200;
  }

  static Future<bool> deleteChat(int chatId) async {
    try {
      final response = await _delete(Uri.parse('$baseUrl/chat/$chatId'), headers: _headers);
      return response.statusCode == 200;
    } catch (_) {
      return true;
    }
  }

  /// Backend chưa có endpoint typing -> bỏ qua.
  static Future<void> updateTypingStatus(int chatId, String uid, bool isTyping) async {}

  static Future<Map<String, dynamic>> getTypingUser(int chatId) async => {};

  /// Tìm kiếm tin nhắn theo từ khóa trong một cuộc trò chuyện.
  static Future<List<dynamic>> searchMessages(int chatId, String query) async {
    if (query.trim().isEmpty) return [];
    final response = await _get(
      Uri.parse('$baseUrl/chat/$chatId/search?q=${Uri.encodeComponent(query)}'),
      headers: _headers,
    );
    if (response.statusCode != 200) return [];
    final data = _decode(response);
    final messages = (data is Map ? data['messages'] : data) as List? ?? [];
    return messages.map((m) => _adaptMessage(Map<String, dynamic>.from(m as Map))).toList();
  }

  // ==================== Reactions ====================

  static Future<void> addReaction(int messageId, String emoji) async {
    await _post(
      Uri.parse('$baseUrl/chat/messages/$messageId/reactions'),
      headers: _headers,
      body: jsonEncode({'emoji': emoji}),
    );
  }

  /// Backend đã dùng toggle qua addReaction nên removeReaction gọi lại addReaction.
  static Future<void> removeReaction(int messageId, String emoji) async {
    await addReaction(messageId, emoji);
  }

  static Future<List<dynamic>> getReactions(int messageId) async => [];

  // ==================== Read receipts ====================

  static Future<void> markAsRead(int chatId) async {
    try {
      await _post(Uri.parse('$baseUrl/chat/$chatId/read'), headers: _headers);
    } catch (_) {}
  }

  // ==================== Pin (tối đa 3 tin mỗi chat) ====================

  /// Ghim/bỏ ghim. Trả về true nếu thành công, kèm thông báo lỗi nếu có.
  static Future<Map<String, dynamic>> pinMessage(int chatId, int messageId) async {
    final response = await _post(
      Uri.parse('$baseUrl/chat/$chatId/messages/$messageId/pin'),
      headers: _headers,
    );
    final data = _decode(response) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      return {'ok': true, 'is_pinned': data['is_pinned'] == true};
    }
    return {'ok': false, 'error': data['detail'] ?? 'Ghim thất bại'};
  }

  static Future<List<dynamic>> getPinnedMessages(int chatId) async {
    final response = await _get(Uri.parse('$baseUrl/chat/$chatId/pinned'), headers: _headers);
    if (response.statusCode != 200) return [];
    final data = _decode(response);
    final messages = (data is Map ? data['messages'] : data) as List? ?? [];
    return messages.map((m) => _adaptMessage(Map<String, dynamic>.from(m as Map))).toList();
  }

  // ==================== Mute / Archive ====================

  static Future<void> muteChat(int chatId, bool isMuted) async {
    try {
      await _post(Uri.parse('$baseUrl/chat/$chatId/mute'), headers: _headers);
    } catch (_) {}
  }

  static Future<void> archiveChat(int chatId, bool isArchived) async {
    try {
      await _post(Uri.parse('$baseUrl/chat/$chatId/archive'), headers: _headers);
    } catch (_) {}
  }

  static Future<void> clearChatHistory(int chatId) async {
    await _delete(Uri.parse('$baseUrl/chat/$chatId/messages'), headers: _headers);
  }

  // ==================== Forward ====================

  static Future<Map<String, dynamic>> forwardMessage(int messageId, int targetChatId) async {
    final response = await _post(
      Uri.parse('$baseUrl/chat/messages/$messageId/forward'),
      headers: _headers,
      body: jsonEncode({'target_chat_id': targetChatId}),
    );
    return _decode(response) as Map<String, dynamic>;
  }

  // ==================== Block ====================

  static Future<void> blockUser(String blockedUid) async {
    await _post(
      Uri.parse('$baseUrl/block'),
      headers: _headers,
      body: jsonEncode({'user_id': blockedUid}),
    );
  }

  static Future<void> unblockUser(String blockedUid) async {
    await _delete(Uri.parse('$baseUrl/block/$blockedUid'), headers: _headers);
  }

  static Future<List<dynamic>> getBlockedUsers() async {
    try {
      final response = await _get(Uri.parse('$baseUrl/block'), headers: _headers);
      final data = _decode(response) as Map<String, dynamic>;
      return (data['blocked_users'] as List?) ?? [];
    } catch (_) {
      return [];
    }
  }

  // ==================== Privacy ====================

  static Future<Map<String, dynamic>> getPrivacySettings() async {
    try {
      final response = await _get(Uri.parse('$baseUrl/privacy'), headers: _headers);
      final data = _decode(response) as Map<String, dynamic>;
      return (data['privacy'] as Map<String, dynamic>?) ?? {};
    } catch (_) {
      return {};
    }
  }

  static Future<void> updatePrivacySettings(Map<String, dynamic> settings) async {
    await _put(
      Uri.parse('$baseUrl/privacy'),
      headers: _headers,
      body: jsonEncode(settings),
    );
  }

  // ==================== Group Invite ====================

  static Future<Map<String, dynamic>?> getInviteLink(int chatId) async {
    try {
      final response = await _get(Uri.parse('$baseUrl/invite/$chatId'), headers: _headers);
      final data = _decode(response) as Map<String, dynamic>;
      return data['invite'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> createInviteLink(int chatId) async {
    final response = await _post(Uri.parse('$baseUrl/invite/$chatId'), headers: _headers);
    final data = _decode(response) as Map<String, dynamic>;
    return data['invite'] as Map<String, dynamic>?;
  }

  static Future<void> revokeInviteLink(int chatId) async {
    await _delete(Uri.parse('$baseUrl/invite/$chatId'), headers: _headers);
  }

  static Future<Map<String, dynamic>> joinViaInvite(String code) async {
    final response = await _post(Uri.parse('$baseUrl/invite/join/$code'), headers: _headers);
    return _decode(response) as Map<String, dynamic>;
  }

  // ==================== Admin Activity Log ====================

  static Future<Map<String, dynamic>> getActivityLog({int page = 1, int limit = 50}) async {
    final response = await _get(
      Uri.parse('$baseUrl/admin/activity-log?page=$page&limit=$limit'),
      headers: _headers,
    );
    return _decode(response) as Map<String, dynamic>;
  }

  // ==================== Group management ====================

  static Future<Map<String, dynamic>> getChatInfo(int chatId) async {
    final response = await _get(
      Uri.parse('$baseUrl/chat/$chatId'),
      headers: _headers,
    );
    final data = _decode(response) as Map<String, dynamic>;
    final chat = data['chat'] as Map? ?? {};
    final participants = (chat['participants'] as List?)
            ?.map((p) => _adaptUser(Map<String, dynamic>.from(p as Map)))
            .toList() ??
        [];
    return {
      'chat_name': chat['name']?.toString() ?? '',
      'group_avatar': chat['avatar_url']?.toString() ?? '',
      'created_by': chat['creator_id']?.toString() ?? '',
      'is_group': chat['is_group'] == true,
      'participants': participants,
    };
  }

  /// Backend chưa có endpoint cập nhật nhóm -> bỏ qua.
  static Future<void> updateGroup(int chatId, {String? groupName, String? groupAvatar}) async {}

  static Future<void> addParticipant(int chatId, String userUid) async {
    await _post(
      Uri.parse('$baseUrl/chat/$chatId/participants'),
      headers: _headers,
      body: jsonEncode({'user_ids': [userUid]}),
    );
  }

  static Future<void> removeParticipant(int chatId, String userUid) async {
    await _delete(
      Uri.parse('$baseUrl/chat/$chatId/participants/$userUid'),
      headers: _headers,
    );
  }

  static Future<void> leaveGroup(int chatId) async {
    await _post(
      Uri.parse('$baseUrl/chat/$chatId/leave'),
      headers: _headers,
    );
  }

  // ==================== Admin ====================

  /// Thống kê tổng quan cho dashboard admin.
  static Future<Map<String, dynamic>> adminGetStats() async {
    final response = await _get(Uri.parse('$baseUrl/admin/stats'), headers: _headers);
    if (response.statusCode != 200) return {};
    return Map<String, dynamic>.from(_decode(response) as Map);
  }

  /// Danh sách người dùng (tìm kiếm + phân trang).
  static Future<Map<String, dynamic>> adminGetUsers({String? query, int page = 1, int limit = 50}) async {
    final q = (query != null && query.isNotEmpty) ? '&q=${Uri.encodeComponent(query)}' : '';
    final response = await _get(
      Uri.parse('$baseUrl/admin/users?page=$page&limit=$limit$q'),
      headers: _headers,
    );
    if (response.statusCode != 200) return {'users': [], 'total': 0};
    final data = _decode(response) as Map<String, dynamic>;
    final users = (data['users'] as List?)
            ?.map((u) => _adaptUser(Map<String, dynamic>.from(u as Map)))
            .toList() ??
        [];
    return {'users': users, 'total': data['total'] ?? users.length};
  }

  static Future<Map<String, dynamic>> adminCreateUser({
    required String email,
    required String password,
    required String displayName,
    String role = 'user',
  }) async {
    final response = await _post(
      Uri.parse('$baseUrl/admin/users'),
      headers: _headers,
      body: jsonEncode({
        'email': email,
        'password': password,
        'display_name': displayName,
        'role': role,
      }),
    );
    final data = _decode(response) as Map<String, dynamic>;
    if (response.statusCode == 200 || response.statusCode == 201) {
      return {'ok': true, 'user': data['user']};
    }
    return {'ok': false, 'error': data['detail'] ?? 'Tạo người dùng thất bại'};
  }

  static Future<bool> adminUpdateUser(String userId, {String? displayName, String? role, String? email, String? avatarUrl}) async {
    final response = await _put(
      Uri.parse('$baseUrl/admin/users/$userId'),
      headers: _headers,
      body: jsonEncode({
        if (displayName != null) 'display_name': displayName,
        if (role != null) 'role': role,
        if (email != null) 'email': email,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      }),
    );
    return response.statusCode == 200;
  }

  static Future<bool> adminLockUser(String userId) async {
    final response = await _post(Uri.parse('$baseUrl/admin/users/$userId/lock'), headers: _headers);
    return response.statusCode == 200;
  }

  static Future<bool> adminUnlockUser(String userId) async {
    final response = await _post(Uri.parse('$baseUrl/admin/users/$userId/unlock'), headers: _headers);
    return response.statusCode == 200;
  }

  static Future<bool> adminResetPassword(String userId, String newPassword) async {
    final response = await _post(
      Uri.parse('$baseUrl/admin/users/$userId/reset-password'),
      headers: _headers,
      body: jsonEncode({'new_password': newPassword}),
    );
    return response.statusCode == 200;
  }

  static Future<bool> adminDeleteUser(String userId) async {
    final response = await _delete(Uri.parse('$baseUrl/admin/users/$userId'), headers: _headers);
    return response.statusCode == 200;
  }

  static Future<List<dynamic>> adminGetGroups() async {
    final response = await _get(Uri.parse('$baseUrl/admin/groups'), headers: _headers);
    if (response.statusCode != 200) return [];
    final data = _decode(response) as Map<String, dynamic>;
    return (data['groups'] as List?) ?? [];
  }

  static Future<bool> adminDeleteGroup(String chatId) async {
    final response = await _delete(Uri.parse('$baseUrl/admin/groups/$chatId'), headers: _headers);
    return response.statusCode == 200;
  }

  /// Chi tiết nhóm cho admin: {group, members}.
  static Future<Map<String, dynamic>> adminGetGroupDetail(String chatId) async {
    final response = await _get(Uri.parse('$baseUrl/admin/groups/$chatId'), headers: _headers);
    if (response.statusCode != 200) return {};
    final data = _decode(response) as Map<String, dynamic>;
    final group = Map<String, dynamic>.from(data['group'] as Map? ?? {});
    final members = (data['members'] as List?)
            ?.map((m) => _adaptUser(Map<String, dynamic>.from(m as Map)))
            .toList() ??
        [];
    return {'group': group, 'members': members};
  }

  static Future<bool> adminUpdateGroup(String chatId, {String? name, String? avatarUrl}) async {
    final response = await _put(
      Uri.parse('$baseUrl/admin/groups/$chatId'),
      headers: _headers,
      body: jsonEncode({
        if (name != null) 'name': name,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      }),
    );
    return response.statusCode == 200;
  }

  static Future<bool> adminAddGroupMembers(String chatId, List<String> userIds) async {
    final response = await _post(
      Uri.parse('$baseUrl/admin/groups/$chatId/members'),
      headers: _headers,
      body: jsonEncode({'user_ids': userIds}),
    );
    return response.statusCode == 200;
  }

  static Future<bool> adminRemoveGroupMember(String chatId, String userId) async {
    final response = await _delete(
      Uri.parse('$baseUrl/admin/groups/$chatId/members/$userId'),
      headers: _headers,
    );
    return response.statusCode == 200;
  }

  // ==================== Bạn bè ====================

  static Future<Map<String, dynamic>> sendFriendRequest(String email) async {
    final response = await _post(
      Uri.parse('$baseUrl/friend/request'),
      headers: _headers,
      body: jsonEncode({'email': email}),
    );
    final data = _decode(response) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      return {'ok': true, 'message': data['message'] ?? 'Đã gửi lời mời'};
    }
    return {'ok': false, 'error': data['detail'] ?? 'Gửi lời mời thất bại'};
  }

  static Future<List<dynamic>> getFriends() async {
    final response = await _get(Uri.parse('$baseUrl/friend/list'), headers: _headers);
    if (response.statusCode != 200) return [];
    final data = _decode(response) as Map<String, dynamic>;
    return (data['friends'] as List?)
            ?.map((u) => _adaptUser(Map<String, dynamic>.from(u as Map)))
            .toList() ??
        [];
  }

  static Future<List<dynamic>> getFriendRequests() async {
    final response = await _get(Uri.parse('$baseUrl/friend/requests'), headers: _headers);
    if (response.statusCode != 200) return [];
    final data = _decode(response) as Map<String, dynamic>;
    return (data['requests'] as List?)?.map((u) {
          final m = _adaptUser(Map<String, dynamic>.from(u as Map));
          m['friendship_id'] = (u)['friendship_id']?.toString() ?? '';
          return m;
        }).toList() ??
        [];
  }

  static Future<bool> acceptFriendRequest(String friendshipId) async {
    final response = await _post(Uri.parse('$baseUrl/friend/$friendshipId/accept'), headers: _headers);
    return response.statusCode == 200;
  }

  static Future<bool> rejectFriendRequest(String friendshipId) async {
    final response = await _post(Uri.parse('$baseUrl/friend/$friendshipId/reject'), headers: _headers);
    return response.statusCode == 200;
  }

  static Future<bool> unfriend(String userId) async {
    final response = await _delete(Uri.parse('$baseUrl/friend/$userId'), headers: _headers);
    return response.statusCode == 200;
  }
}
