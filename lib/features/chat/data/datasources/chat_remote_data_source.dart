import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/constants/app_config.dart';
import '../../../../core/error/exceptions.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

/// Interface cho Chat Remote Data Source
abstract class ChatRemoteDataSource {
  Future<List<ChatModel>> getChats({
    required String token,
    int page = 1,
    int limit = 20,
  });

  Future<ChatModel> getChatById({
    required String token,
    required String chatId,
  });

  Future<ChatModel> createDirectChat({
    required String token,
    required String userId,
  });

  Future<ChatModel> createGroupChat({
    required String token,
    required String name,
    required List<String> participantIds,
    String? avatarUrl,
  });

  Future<List<MessageModel>> getMessages({
    required String token,
    required String chatId,
    int page = 1,
    int limit = 50,
  });

  Future<MessageModel> sendMessage({
    required String token,
    required String chatId,
    required String content,
    String? replyToId,
  });

  Future<void> deleteMessage({
    required String token,
    required String messageId,
    bool deleteForEveryone = false,
  });

  Future<void> addReaction({
    required String token,
    required String messageId,
    required String emoji,
  });

  Future<void> markAsRead({
    required String token,
    required String chatId,
  });
}

/// Implementation
class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  final http.Client client;

  ChatRemoteDataSourceImpl({required this.client});

  String get _baseUrl => AppConfig.baseOrigin;

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  @override
  Future<List<ChatModel>> getChats({
    required String token,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await client.get(
      Uri.parse('$_baseUrl/api/chat?page=$page&limit=$limit'),
      headers: _headers(token),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final chats = data['chats'] ?? data;
      return (chats as List).map((c) => ChatModel.fromJson(c)).toList();
    } else {
      throw ServerException(
        message: 'Không thể tải danh sách chat',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<ChatModel> getChatById({
    required String token,
    required String chatId,
  }) async {
    final response = await client.get(
      Uri.parse('$_baseUrl/api/chat/$chatId'),
      headers: _headers(token),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return ChatModel.fromJson(data['chat'] ?? data);
    } else {
      throw ServerException(
        message: 'Không tìm thấy cuộc hội thoại',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<ChatModel> createDirectChat({
    required String token,
    required String userId,
  }) async {
    final response = await client.post(
      Uri.parse('$_baseUrl/api/chat/direct'),
      headers: _headers(token),
      body: jsonEncode({'user_id': userId}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return ChatModel.fromJson(data['chat'] ?? data);
    } else {
      throw ServerException(
        message: 'Không thể tạo cuộc hội thoại',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<ChatModel> createGroupChat({
    required String token,
    required String name,
    required List<String> participantIds,
    String? avatarUrl,
  }) async {
    final response = await client.post(
      Uri.parse('$_baseUrl/api/chat/group'),
      headers: _headers(token),
      body: jsonEncode({
        'name': name,
        'participant_ids': participantIds,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return ChatModel.fromJson(data['chat'] ?? data);
    } else {
      throw ServerException(
        message: 'Không thể tạo nhóm',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<List<MessageModel>> getMessages({
    required String token,
    required String chatId,
    int page = 1,
    int limit = 50,
  }) async {
    final response = await client.get(
      Uri.parse('$_baseUrl/api/chat/$chatId/messages?page=$page&limit=$limit'),
      headers: _headers(token),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final messages = data['messages'] ?? data;
      return (messages as List).map((m) => MessageModel.fromJson(m)).toList();
    } else {
      throw ServerException(
        message: 'Không thể tải tin nhắn',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<MessageModel> sendMessage({
    required String token,
    required String chatId,
    required String content,
    String? replyToId,
  }) async {
    final response = await client.post(
      Uri.parse('$_baseUrl/api/chat/$chatId/messages'),
      headers: _headers(token),
      body: jsonEncode({
        'content': content,
        if (replyToId != null) 'reply_to_id': replyToId,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return MessageModel.fromJson(data['message'] ?? data);
    } else {
      throw ServerException(
        message: 'Không thể gửi tin nhắn',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<void> deleteMessage({
    required String token,
    required String messageId,
    bool deleteForEveryone = false,
  }) async {
    final response = await client.delete(
      Uri.parse('$_baseUrl/api/chat/messages/$messageId?for_everyone=$deleteForEveryone'),
      headers: _headers(token),
    );

    if (response.statusCode != 200) {
      throw ServerException(
        message: 'Không thể xóa tin nhắn',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<void> addReaction({
    required String token,
    required String messageId,
    required String emoji,
  }) async {
    final response = await client.post(
      Uri.parse('$_baseUrl/api/chat/messages/$messageId/reactions'),
      headers: _headers(token),
      body: jsonEncode({'emoji': emoji}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ServerException(
        message: 'Không thể thêm reaction',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<void> markAsRead({
    required String token,
    required String chatId,
  }) async {
    final response = await client.post(
      Uri.parse('$_baseUrl/api/chat/$chatId/read'),
      headers: _headers(token),
    );

    if (response.statusCode != 200) {
      throw ServerException(
        message: 'Không thể đánh dấu đã đọc',
        statusCode: response.statusCode,
      );
    }
  }
}
