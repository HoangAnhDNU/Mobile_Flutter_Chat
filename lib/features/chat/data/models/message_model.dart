import '../../domain/entities/message_entity.dart';

/// Model cho Message
class MessageModel extends MessageEntity {
  const MessageModel({
    required super.id,
    required super.chatId,
    required super.senderId,
    required super.senderName,
    super.senderAvatar,
    required super.content,
    super.type,
    super.status,
    super.mediaUrl,
    super.thumbnailUrl,
    super.replyToId,
    super.replyToMessage,
    super.reactions,
    super.isDeleted,
    required super.createdAt,
    super.editedAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id']?.toString() ?? '',
      chatId: json['chat_id']?.toString() ?? json['chatId']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? json['senderId']?.toString() ?? '',
      senderName: json['sender_name'] ?? json['senderName'] ?? '',
      senderAvatar: json['sender_avatar'] ?? json['senderAvatar'],
      content: json['content'] ?? '',
      type: _parseMessageType(json['type']),
      status: _parseMessageStatus(json['status']),
      mediaUrl: json['media_url'] ?? json['mediaUrl'],
      thumbnailUrl: json['thumbnail_url'] ?? json['thumbnailUrl'],
      replyToId: json['reply_to_id']?.toString() ?? json['replyToId']?.toString(),
      reactions: (json['reactions'] as List<dynamic>?)
              ?.map((r) => ReactionModel.fromJson(r))
              .toList() ??
          [],
      isDeleted: json['is_deleted'] ?? json['isDeleted'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      editedAt: json['edited_at'] != null
          ? DateTime.tryParse(json['edited_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chat_id': chatId,
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_avatar': senderAvatar,
      'content': content,
      'type': type.name,
      'status': status.name,
      'media_url': mediaUrl,
      'thumbnail_url': thumbnailUrl,
      'reply_to_id': replyToId,
      'reactions': reactions
          .map((r) => (r as ReactionModel).toJson())
          .toList(),
      'is_deleted': isDeleted,
      'created_at': createdAt.toIso8601String(),
      'edited_at': editedAt?.toIso8601String(),
    };
  }

  static MessageType _parseMessageType(String? type) {
    switch (type) {
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.video;
      case 'file':
        return MessageType.file;
      case 'audio':
        return MessageType.audio;
      case 'location':
        return MessageType.location;
      case 'system':
        return MessageType.system;
      default:
        return MessageType.text;
    }
  }

  static MessageStatus _parseMessageStatus(String? status) {
    switch (status) {
      case 'sending':
        return MessageStatus.sending;
      case 'delivered':
        return MessageStatus.delivered;
      case 'read':
        return MessageStatus.read;
      case 'failed':
        return MessageStatus.failed;
      default:
        return MessageStatus.sent;
    }
  }

  MessageModel copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? senderName,
    String? senderAvatar,
    String? content,
    MessageType? type,
    MessageStatus? status,
    String? mediaUrl,
    String? thumbnailUrl,
    String? replyToId,
    List<ReactionEntity>? reactions,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? editedAt,
  }) {
    return MessageModel(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      content: content ?? this.content,
      type: type ?? this.type,
      status: status ?? this.status,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      replyToId: replyToId ?? this.replyToId,
      reactions: reactions ?? this.reactions,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
    );
  }
}

/// Model cho Reaction
class ReactionModel extends ReactionEntity {
  const ReactionModel({
    required super.id,
    required super.userId,
    required super.userName,
    required super.emoji,
    required super.createdAt,
  });

  factory ReactionModel.fromJson(Map<String, dynamic> json) {
    return ReactionModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? json['userId']?.toString() ?? '',
      userName: json['user_name'] ?? json['userName'] ?? '',
      emoji: json['emoji'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'emoji': emoji,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
