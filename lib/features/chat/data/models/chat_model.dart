import '../../domain/entities/chat_entity.dart';
import '../../../auth/data/models/user_model.dart';
import 'message_model.dart';

/// Model cho Chat
class ChatModel extends ChatEntity {
  const ChatModel({
    required super.id,
    super.name,
    super.avatarUrl,
    required super.isGroup,
    super.creatorId,
    required super.participants,
    super.lastMessage,
    super.unreadCount,
    super.isPinned,
    super.isMuted,
    super.isArchived,
    required super.createdAt,
    super.updatedAt,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    return ChatModel(
      id: json['id']?.toString() ?? '',
      name: json['name'],
      avatarUrl: json['avatar_url'] ?? json['avatarUrl'],
      isGroup: json['is_group'] ?? json['isGroup'] ?? false,
      creatorId: json['creator_id']?.toString() ?? json['creatorId']?.toString(),
      participants: (json['participants'] as List<dynamic>?)
              ?.map((p) => UserModel.fromJson(p))
              .toList() ??
          [],
      lastMessage: json['last_message'] != null
          ? MessageModel.fromJson(json['last_message'])
          : null,
      unreadCount: json['unread_count'] ?? json['unreadCount'] ?? 0,
      isPinned: json['is_pinned'] ?? json['isPinned'] ?? false,
      isMuted: json['is_muted'] ?? json['isMuted'] ?? false,
      isArchived: json['is_archived'] ?? json['isArchived'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatar_url': avatarUrl,
      'is_group': isGroup,
      'creator_id': creatorId,
      'participants': participants
          .map((p) => (p as UserModel).toJson())
          .toList(),
      'last_message': lastMessage != null
          ? (lastMessage as MessageModel).toJson()
          : null,
      'unread_count': unreadCount,
      'is_pinned': isPinned,
      'is_muted': isMuted,
      'is_archived': isArchived,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  ChatModel copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    bool? isGroup,
    String? creatorId,
    List<UserModel>? participants,
    MessageModel? lastMessage,
    int? unreadCount,
    bool? isPinned,
    bool? isMuted,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatModel(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isGroup: isGroup ?? this.isGroup,
      creatorId: creatorId ?? this.creatorId,
      participants: participants ?? this.participants.cast<UserModel>(),
      lastMessage: lastMessage ?? this.lastMessage as MessageModel?,
      unreadCount: unreadCount ?? this.unreadCount,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
