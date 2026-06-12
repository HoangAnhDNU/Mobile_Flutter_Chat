import 'package:equatable/equatable.dart';
import 'message_entity.dart';
import '../../../auth/domain/entities/user_entity.dart';

/// Entity đại diện cho một cuộc hội thoại
class ChatEntity extends Equatable {
  final String id;
  final String? name;
  final String? avatarUrl;
  final bool isGroup;
  final String? creatorId;
  final List<UserEntity> participants;
  final MessageEntity? lastMessage;
  final int unreadCount;
  final bool isPinned;
  final bool isMuted;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ChatEntity({
    required this.id,
    this.name,
    this.avatarUrl,
    required this.isGroup,
    this.creatorId,
    required this.participants,
    this.lastMessage,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isMuted = false,
    this.isArchived = false,
    required this.createdAt,
    this.updatedAt,
  });

  /// Lấy tên hiển thị cho chat (tên nhóm hoặc tên người kia trong chat 1-1)
  String getDisplayName(String currentUserId) {
    if (isGroup && name != null) return name!;
    final otherUser = participants.where((p) => p.id != currentUserId).firstOrNull;
    return otherUser?.displayName ?? 'Không xác định';
  }

  /// Lấy avatar cho chat
  String? getDisplayAvatar(String currentUserId) {
    if (isGroup) return avatarUrl;
    final otherUser = participants.where((p) => p.id != currentUserId).firstOrNull;
    return otherUser?.avatarUrl;
  }

  @override
  List<Object?> get props => [
        id,
        name,
        avatarUrl,
        isGroup,
        creatorId,
        participants,
        lastMessage,
        unreadCount,
        isPinned,
        isMuted,
        isArchived,
        createdAt,
        updatedAt,
      ];
}
