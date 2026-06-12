import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/chat_entity.dart';
import '../entities/message_entity.dart';

/// Interface cho Chat Repository
abstract class ChatRepository {
  /// Lấy danh sách các cuộc hội thoại
  Future<Either<Failure, List<ChatEntity>>> getChats({
    int page = 1,
    int limit = 20,
  });

  /// Lấy chi tiết một cuộc hội thoại
  Future<Either<Failure, ChatEntity>> getChatById(String chatId);

  /// Tạo chat 1-1 mới
  Future<Either<Failure, ChatEntity>> createDirectChat(String userId);

  /// Tạo nhóm chat mới
  Future<Either<Failure, ChatEntity>> createGroupChat({
    required String name,
    required List<String> participantIds,
    String? avatarUrl,
  });

  /// Cập nhật thông tin nhóm
  Future<Either<Failure, ChatEntity>> updateGroupChat({
    required String chatId,
    String? name,
    String? avatarUrl,
  });

  /// Thêm thành viên vào nhóm
  Future<Either<Failure, void>> addParticipants({
    required String chatId,
    required List<String> userIds,
  });

  /// Xóa thành viên khỏi nhóm
  Future<Either<Failure, void>> removeParticipant({
    required String chatId,
    required String userId,
  });

  /// Rời khỏi nhóm
  Future<Either<Failure, void>> leaveGroup(String chatId);

  /// Xóa cuộc hội thoại
  Future<Either<Failure, void>> deleteChat(String chatId);

  /// Ghim/bỏ ghim chat
  Future<Either<Failure, void>> togglePinChat(String chatId);

  /// Tắt/bật thông báo chat
  Future<Either<Failure, void>> toggleMuteChat(String chatId);

  /// Lưu trữ/bỏ lưu trữ chat
  Future<Either<Failure, void>> toggleArchiveChat(String chatId);

  /// Tìm kiếm chat
  Future<Either<Failure, List<ChatEntity>>> searchChats(String query);
}

/// Interface cho Message Repository
abstract class MessageRepository {
  /// Lấy tin nhắn của một cuộc hội thoại
  Future<Either<Failure, List<MessageEntity>>> getMessages({
    required String chatId,
    int page = 1,
    int limit = 50,
  });

  /// Gửi tin nhắn văn bản
  Future<Either<Failure, MessageEntity>> sendTextMessage({
    required String chatId,
    required String content,
    String? replyToId,
  });

  /// Gửi tin nhắn media (hình ảnh, video, file)
  Future<Either<Failure, MessageEntity>> sendMediaMessage({
    required String chatId,
    required String filePath,
    required MessageType type,
    String? caption,
  });

  /// Chỉnh sửa tin nhắn
  Future<Either<Failure, MessageEntity>> editMessage({
    required String messageId,
    required String newContent,
  });

  /// Xóa tin nhắn
  Future<Either<Failure, void>> deleteMessage({
    required String messageId,
    bool deleteForEveryone = false,
  });

  /// Thêm reaction
  Future<Either<Failure, void>> addReaction({
    required String messageId,
    required String emoji,
  });

  /// Xóa reaction
  Future<Either<Failure, void>> removeReaction({
    required String messageId,
    required String reactionId,
  });

  /// Đánh dấu đã đọc
  Future<Either<Failure, void>> markAsRead(String chatId);

  /// Tìm kiếm tin nhắn
  Future<Either<Failure, List<MessageEntity>>> searchMessages({
    required String chatId,
    required String query,
  });
}
