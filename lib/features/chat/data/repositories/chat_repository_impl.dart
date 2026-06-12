import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../auth/data/datasources/auth_local_data_source.dart';
import '../../domain/entities/chat_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_remote_data_source.dart';

/// Implementation của ChatRepository
class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource remoteDataSource;
  final AuthLocalDataSource authLocalDataSource;
  final NetworkInfo networkInfo;

  ChatRepositoryImpl({
    required this.remoteDataSource,
    required this.authLocalDataSource,
    required this.networkInfo,
  });

  Future<String> _getToken() async {
    return await authLocalDataSource.getCachedToken();
  }

  @override
  Future<Either<Failure, List<ChatEntity>>> getChats({
    int page = 1,
    int limit = 20,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final token = await _getToken();
        final chats = await remoteDataSource.getChats(
          token: token,
          page: page,
          limit: limit,
        );
        return Right(chats);
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } on CacheException catch (e) {
        return Left(AuthFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, ChatEntity>> getChatById(String chatId) async {
    if (await networkInfo.isConnected) {
      try {
        final token = await _getToken();
        final chat = await remoteDataSource.getChatById(
          token: token,
          chatId: chatId,
        );
        return Right(chat);
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, ChatEntity>> createDirectChat(String userId) async {
    if (await networkInfo.isConnected) {
      try {
        final token = await _getToken();
        final chat = await remoteDataSource.createDirectChat(
          token: token,
          userId: userId,
        );
        return Right(chat);
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, ChatEntity>> createGroupChat({
    required String name,
    required List<String> participantIds,
    String? avatarUrl,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final token = await _getToken();
        final chat = await remoteDataSource.createGroupChat(
          token: token,
          name: name,
          participantIds: participantIds,
          avatarUrl: avatarUrl,
        );
        return Right(chat);
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, ChatEntity>> updateGroupChat({
    required String chatId,
    String? name,
    String? avatarUrl,
  }) async {
    // TODO: Implement
    return const Left(ServerFailure('Chưa được triển khai'));
  }

  @override
  Future<Either<Failure, void>> addParticipants({
    required String chatId,
    required List<String> userIds,
  }) async {
    // TODO: Implement
    return const Left(ServerFailure('Chưa được triển khai'));
  }

  @override
  Future<Either<Failure, void>> removeParticipant({
    required String chatId,
    required String userId,
  }) async {
    // TODO: Implement
    return const Left(ServerFailure('Chưa được triển khai'));
  }

  @override
  Future<Either<Failure, void>> leaveGroup(String chatId) async {
    // TODO: Implement
    return const Left(ServerFailure('Chưa được triển khai'));
  }

  @override
  Future<Either<Failure, void>> deleteChat(String chatId) async {
    // TODO: Implement
    return const Left(ServerFailure('Chưa được triển khai'));
  }

  @override
  Future<Either<Failure, void>> togglePinChat(String chatId) async {
    // TODO: Implement
    return const Left(ServerFailure('Chưa được triển khai'));
  }

  @override
  Future<Either<Failure, void>> toggleMuteChat(String chatId) async {
    // TODO: Implement
    return const Left(ServerFailure('Chưa được triển khai'));
  }

  @override
  Future<Either<Failure, void>> toggleArchiveChat(String chatId) async {
    // TODO: Implement
    return const Left(ServerFailure('Chưa được triển khai'));
  }

  @override
  Future<Either<Failure, List<ChatEntity>>> searchChats(String query) async {
    // TODO: Implement
    return const Left(ServerFailure('Chưa được triển khai'));
  }
}

/// Implementation của MessageRepository
class MessageRepositoryImpl implements MessageRepository {
  final ChatRemoteDataSource remoteDataSource;
  final AuthLocalDataSource authLocalDataSource;
  final NetworkInfo networkInfo;

  MessageRepositoryImpl({
    required this.remoteDataSource,
    required this.authLocalDataSource,
    required this.networkInfo,
  });

  Future<String> _getToken() async {
    return await authLocalDataSource.getCachedToken();
  }

  @override
  Future<Either<Failure, List<MessageEntity>>> getMessages({
    required String chatId,
    int page = 1,
    int limit = 50,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final token = await _getToken();
        final messages = await remoteDataSource.getMessages(
          token: token,
          chatId: chatId,
          page: page,
          limit: limit,
        );
        return Right(messages);
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, MessageEntity>> sendTextMessage({
    required String chatId,
    required String content,
    String? replyToId,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final token = await _getToken();
        final message = await remoteDataSource.sendMessage(
          token: token,
          chatId: chatId,
          content: content,
          replyToId: replyToId,
        );
        return Right(message);
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, MessageEntity>> sendMediaMessage({
    required String chatId,
    required String filePath,
    required MessageType type,
    String? caption,
  }) async {
    // TODO: Implement file upload
    return const Left(ServerFailure('Chưa được triển khai'));
  }

  @override
  Future<Either<Failure, MessageEntity>> editMessage({
    required String messageId,
    required String newContent,
  }) async {
    // TODO: Implement
    return const Left(ServerFailure('Chưa được triển khai'));
  }

  @override
  Future<Either<Failure, void>> deleteMessage({
    required String messageId,
    bool deleteForEveryone = false,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final token = await _getToken();
        await remoteDataSource.deleteMessage(
          token: token,
          messageId: messageId,
          deleteForEveryone: deleteForEveryone,
        );
        return const Right(null);
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, void>> addReaction({
    required String messageId,
    required String emoji,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final token = await _getToken();
        await remoteDataSource.addReaction(
          token: token,
          messageId: messageId,
          emoji: emoji,
        );
        return const Right(null);
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, void>> removeReaction({
    required String messageId,
    required String reactionId,
  }) async {
    // TODO: Implement
    return const Left(ServerFailure('Chưa được triển khai'));
  }

  @override
  Future<Either<Failure, void>> markAsRead(String chatId) async {
    if (await networkInfo.isConnected) {
      try {
        final token = await _getToken();
        await remoteDataSource.markAsRead(
          token: token,
          chatId: chatId,
        );
        return const Right(null);
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, List<MessageEntity>>> searchMessages({
    required String chatId,
    required String query,
  }) async {
    // TODO: Implement
    return const Left(ServerFailure('Chưa được triển khai'));
  }
}
