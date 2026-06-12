import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/message_entity.dart';
import '../repositories/chat_repository.dart';

/// Use case lấy tin nhắn của một chat
class GetMessagesUseCase implements UseCase<List<MessageEntity>, GetMessagesParams> {
  final MessageRepository repository;

  GetMessagesUseCase(this.repository);

  @override
  Future<Either<Failure, List<MessageEntity>>> call(GetMessagesParams params) {
    return repository.getMessages(
      chatId: params.chatId,
      page: params.page,
      limit: params.limit,
    );
  }
}

class GetMessagesParams extends Equatable {
  final String chatId;
  final int page;
  final int limit;

  const GetMessagesParams({
    required this.chatId,
    this.page = 1,
    this.limit = 50,
  });

  @override
  List<Object> get props => [chatId, page, limit];
}
