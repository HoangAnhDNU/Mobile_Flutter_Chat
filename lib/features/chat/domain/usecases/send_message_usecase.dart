import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/message_entity.dart';
import '../repositories/chat_repository.dart';

/// Use case gửi tin nhắn văn bản
class SendMessageUseCase implements UseCase<MessageEntity, SendMessageParams> {
  final MessageRepository repository;

  SendMessageUseCase(this.repository);

  @override
  Future<Either<Failure, MessageEntity>> call(SendMessageParams params) {
    return repository.sendTextMessage(
      chatId: params.chatId,
      content: params.content,
      replyToId: params.replyToId,
    );
  }
}

class SendMessageParams extends Equatable {
  final String chatId;
  final String content;
  final String? replyToId;

  const SendMessageParams({
    required this.chatId,
    required this.content,
    this.replyToId,
  });

  @override
  List<Object?> get props => [chatId, content, replyToId];
}
