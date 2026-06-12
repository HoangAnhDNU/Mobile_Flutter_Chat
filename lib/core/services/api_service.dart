import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_config.dart';

class ApiService {
  static const String baseUrl = AppConfig.baseUrl;
  static const Duration _timeout = Duration(seconds: 10);
  static String? _token;
  static String? _uid;

  static Future<http.Response> _get(Uri url, {Map<String, String>? headers}) =>
      http.get(url, headers: headers).timeout(_timeout);

  static Future<http.Response> _post(Uri url, {Map<String, String>? headers, Object? body}) =>
      http.post(url, headers: headers, body: body).timeout(_timeout);

  static Future<http.Response> _put(Uri url, {Map<String, String>? headers, Object? body}) =>
      http.put(url, headers: headers, body: body).timeout(_timeout);

  static Future<http.Response> _delete(Uri url, {Map<String, String>? headers, Object? body}) =>
      http.delete(url, headers: headers, body: body).timeout(_timeout);

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

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  // Auth
  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await _post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'displayName': displayName,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      await saveToken(data['token'], data['user']['uid']);
    }
    return data;
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      await saveToken(data['token'], data['user']['uid']);
    }
    return data;
  }

  static Future<void> logout() async {
    if (_uid != null) {
      await _post(
        Uri.parse('$baseUrl/auth/logout'),
        headers: _headers,
        body: jsonEncode({'uid': _uid}),
      );
    }
    await clearToken();
  }

  // User
  static Future<List<dynamic>> getUsers() async {
    final response = await _get(
      Uri.parse('$baseUrl/user?uid=$_uid'),
      headers: _headers,
    );
    final data = jsonDecode(response.body);
    return data is List ? data : [];
  }

  static Future<Map<String, dynamic>> getUser(String uid) async {
    final response = await _get(
      Uri.parse('$baseUrl/user/$uid'),
      headers: _headers,
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> updateUser(String uid, {
    String? displayName,
    String? avatarUrl,
  }) async {
    final response = await _put(
      Uri.parse('$baseUrl/user/$uid'),
      headers: _headers,
      body: jsonEncode({
        if (displayName != null) 'displayName': displayName,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<void> updateOnlineStatus(String uid, bool isOnline) async {
    await _put(
      Uri.parse('$baseUrl/user/$uid/online'),
      headers: _headers,
      body: jsonEncode({'isOnline': isOnline}),
    );
  }

  // Chat
  static Future<List<dynamic>> getChats() async {
    final response = await _get(
      Uri.parse('$baseUrl/chat?uid=$_uid'),
      headers: _headers,
    );
    final data = jsonDecode(response.body);
    return data is List ? data : [];
  }

  static Future<List<dynamic>> getMessages(int chatId) async {
    final response = await _get(
      Uri.parse('$baseUrl/chat/$chatId/messages'),
      headers: _headers,
    );
    final data = jsonDecode(response.body);
    return data is List ? data : [];
  }

  static Future<Map<String, dynamic>> createChat({
    required List<String> participants,
    required String createdBy,
    String? chatName,
  }) async {
    final response = await _post(
      Uri.parse('$baseUrl/chat'),
      headers: _headers,
      body: jsonEncode({
        'participants': participants,
        'createdBy': createdBy,
        'chatName': chatName ?? '',
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> sendMessage({
    required int chatId,
    required String senderUid,
    required String senderName,
    required String text,
    String messageType = 'text',
    String? imageBase64,
  }) async {
    final response = await _post(
      Uri.parse('$baseUrl/chat/$chatId/messages'),
      headers: _headers,
      body: jsonEncode({
        'senderUid': senderUid,
        'senderName': senderName,
        'text': text,
        'messageType': messageType,
        'imageBase64': imageBase64,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<void> updateMessage(int messageId, String text) async {
    await _put(
      Uri.parse('$baseUrl/chat/messages/$messageId'),
      headers: _headers,
      body: jsonEncode({'text': text}),
    );
  }

  static Future<void> deleteMessage(int messageId) async {
    await _delete(
      Uri.parse('$baseUrl/chat/messages/$messageId'),
      headers: _headers,
    );
  }

  static Future<void> clearChat(int chatId) async {
    await _delete(
      Uri.parse('$baseUrl/chat/$chatId/messages'),
      headers: _headers,
    );
  }

  static Future<void> deleteChat(int chatId) async {
    await _delete(
      Uri.parse('$baseUrl/chat/$chatId'),
      headers: _headers,
    );
  }

  static Future<void> updateTypingStatus(int chatId, String uid, bool isTyping) async {
    await _put(
      Uri.parse('$baseUrl/chat/$chatId/typing'),
      headers: _headers,
      body: jsonEncode({'uid': uid, 'isTyping': isTyping}),
    );
  }

  static Future<Map<String, dynamic>> getTypingUser(int chatId) async {
    final response = await _get(
      Uri.parse('$baseUrl/chat/$chatId/typing'),
      headers: _headers,
    );
    return jsonDecode(response.body);
  }

  // Search messages
  static Future<List<dynamic>> searchMessages(int chatId, String query) async {
    final response = await _get(
      Uri.parse('$baseUrl/chat/$chatId/search?query=$query&uid=$_uid'),
      headers: _headers,
    );
    final data = jsonDecode(response.body);
    return data is List ? data : [];
  }

  // Reactions
  static Future<void> addReaction(int messageId, String emoji) async {
    await _post(
      Uri.parse('$baseUrl/chat/messages/$messageId/reactions'),
      headers: _headers,
      body: jsonEncode({'userUid': _uid, 'emoji': emoji}),
    );
  }

  static Future<void> removeReaction(int messageId, String emoji) async {
    await _delete(
      Uri.parse('$baseUrl/chat/messages/$messageId/reactions'),
      headers: _headers,
      body: jsonEncode({'userUid': _uid, 'emoji': emoji}),
    );
  }

  static Future<List<dynamic>> getReactions(int messageId) async {
    final response = await _get(
      Uri.parse('$baseUrl/chat/messages/$messageId/reactions'),
      headers: _headers,
    );
    return jsonDecode(response.body);
  }

  // Read receipts
  static Future<void> markAsRead(int chatId) async {
    await _post(
      Uri.parse('$baseUrl/chat/$chatId/read'),
      headers: _headers,
      body: jsonEncode({'userUid': _uid}),
    );
  }

  // Pin messages
  static Future<void> pinMessage(int messageId, bool isPinned) async {
    await _put(
      Uri.parse('$baseUrl/chat/messages/$messageId/pin'),
      headers: _headers,
      body: jsonEncode({'isPinned': isPinned}),
    );
  }

  static Future<List<dynamic>> getPinnedMessages(int chatId) async {
    final response = await _get(
      Uri.parse('$baseUrl/chat/$chatId/pinned'),
      headers: _headers,
    );
    final data = jsonDecode(response.body);
    return data is List ? data : [];
  }

  // Delete for me / everyone
  static Future<void> deleteForMe(int messageId) async {
    await _post(
      Uri.parse('$baseUrl/chat/messages/$messageId/delete-for-me'),
      headers: _headers,
      body: jsonEncode({'userUid': _uid}),
    );
  }

  static Future<void> deleteForEveryone(int messageId) async {
    await _post(
      Uri.parse('$baseUrl/chat/messages/$messageId/delete-for-everyone'),
      headers: _headers,
    );
  }

  // Mute/Archive
  static Future<void> muteChat(int chatId, bool isMuted) async {
    await _put(
      Uri.parse('$baseUrl/chat/$chatId/mute'),
      headers: _headers,
      body: jsonEncode({'userUid': _uid, 'isMuted': isMuted}),
    );
  }

  static Future<void> archiveChat(int chatId, bool isArchived) async {
    await _put(
      Uri.parse('$baseUrl/chat/$chatId/archive'),
      headers: _headers,
      body: jsonEncode({'userUid': _uid, 'isArchived': isArchived}),
    );
  }

  // Reply message
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
    final response = await _post(
      Uri.parse('$baseUrl/chat/$chatId/messages/reply'),
      headers: _headers,
      body: jsonEncode({
        'senderUid': senderUid,
        'senderName': senderName,
        'text': text,
        'messageType': messageType,
        'imageBase64': imageBase64,
        'voiceBase64': voiceBase64,
        'voiceDuration': voiceDuration,
        'replyToId': replyToId,
        'replyToText': replyToText,
        'replyToSender': replyToSender,
      }),
    );
    return jsonDecode(response.body);
  }

  // Block user
  static Future<void> blockUser(String blockedUid) async {
    await _post(
      Uri.parse('$baseUrl/user/$_uid/block'),
      headers: _headers,
      body: jsonEncode({'blockedUid': blockedUid}),
    );
  }

  static Future<void> unblockUser(String blockedUid) async {
    await _delete(
      Uri.parse('$baseUrl/user/$_uid/block'),
      headers: _headers,
      body: jsonEncode({'blockedUid': blockedUid}),
    );
  }

  static Future<List<dynamic>> getBlockedUsers() async {
    final response = await _get(
      Uri.parse('$baseUrl/user/$_uid/blocked'),
      headers: _headers,
    );
    return jsonDecode(response.body);
  }

  // Group management
  static Future<Map<String, dynamic>> getChatInfo(int chatId) async {
    final response = await _get(
      Uri.parse('$baseUrl/chat/$chatId/info'),
      headers: _headers,
    );
    return jsonDecode(response.body);
  }

  static Future<void> updateGroup(int chatId, {String? groupName, String? groupAvatar}) async {
    await _put(
      Uri.parse('$baseUrl/chat/$chatId/group'),
      headers: _headers,
      body: jsonEncode({
        'adminUid': _uid,
        if (groupName != null) 'groupName': groupName,
        if (groupAvatar != null) 'groupAvatar': groupAvatar,
      }),
    );
  }

  static Future<void> addParticipant(int chatId, String userUid) async {
    await _post(
      Uri.parse('$baseUrl/chat/$chatId/participants'),
      headers: _headers,
      body: jsonEncode({'userUid': userUid, 'adminUid': _uid}),
    );
  }

  static Future<void> removeParticipant(int chatId, String userUid) async {
    await _delete(
      Uri.parse('$baseUrl/chat/$chatId/participants/$userUid'),
      headers: _headers,
      body: jsonEncode({'adminUid': _uid}),
    );
  }

  static Future<void> leaveGroup(int chatId) async {
    await _post(
      Uri.parse('$baseUrl/chat/$chatId/leave'),
      headers: _headers,
      body: jsonEncode({'userUid': _uid}),
    );
  }

  static String? get uid => _uid;
  static bool get isLoggedIn => _token != null && _uid != null;

  // ==================== AI Speech-to-Text ====================

  static Future<Map<String, dynamic>> transcribeAudio(String filePath) async {
    final uri = Uri.parse('${AppConfig.sttUrl}/transcribe');
    final request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath('audio', filePath));

    final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Lỗi chuyển giọng nói');
    }
  }
}
