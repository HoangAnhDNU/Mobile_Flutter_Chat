import 'package:equatable/equatable.dart';

/// Enum cho trạng thái gửi tin nhắn
enum MessageStatus {
  sending,   // Đang gửi
  sent,      // Đã gửi
  delivered, // Đã chuyển
  read,      // Đã đọc
  failed,    // Lỗi
}

/// Enum cho loại tin nhắn
enum MessageType {
  text,
  image,
  video,
  file,
  audio,
  location,
  system,
}

/// Entity đại diện cho tin nhắn
class MessageEntity extends Equatable {
  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String content;
  final MessageType type;
  final MessageStatus status;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final String? replyToId;
  final MessageEntity? replyToMessage;
  final List<ReactionEntity> reactions;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime? editedAt;

  const MessageEntity({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.content,
    this.type = MessageType.text,
    this.status = MessageStatus.sent,
    this.mediaUrl,
    this.thumbnailUrl,
    this.replyToId,
    this.replyToMessage,
    this.reactions = const [],
    this.isDeleted = false,
    required this.createdAt,
    this.editedAt,
  });

  /// Kiểm tra tin nhắn có phải của user hiện tại không
  bool isMine(String currentUserId) => senderId == currentUserId;

  @override
  List<Object?> get props => [
        id,
        chatId,
        senderId,
        senderName,
        senderAvatar,
        content,
        type,
        status,
        mediaUrl,
        thumbnailUrl,
        replyToId,
        reactions,
        isDeleted,
        createdAt,
        editedAt,
      ];
}

/// Entity cho reaction trên tin nhắn
class ReactionEntity extends Equatable {
  final String id;
  final String userId;
  final String userName;
  final String emoji;
  final DateTime createdAt;

  const ReactionEntity({
    required this.id,
    required this.userId,
    required this.userName,
    required this.emoji,
    required this.createdAt,
  });

  @override
  List<Object> get props => [id, userId, userName, emoji, createdAt];
}
