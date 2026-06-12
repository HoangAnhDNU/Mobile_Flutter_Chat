import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/chat_entity.dart';
import '../repositories/chat_repository.dart';

/// Use case lấy danh sách chats
class GetChatsUseCase implements UseCase<List<ChatEntity>, GetChatsParams> {
  final ChatRepository repository;

  GetChatsUseCase(this.repository);

  @override
  Future<Either<Failure, List<ChatEntity>>> call(GetChatsParams params) {
    return repository.getChats(
      page: params.page,
      limit: params.limit,
    );
  }
}

class GetChatsParams extends Equatable {
  final int page;
  final int limit;

  const GetChatsParams({
    this.page = 1,
    this.limit = 20,
  });

  @override
  List<Object> get props => [page, limit];
}
