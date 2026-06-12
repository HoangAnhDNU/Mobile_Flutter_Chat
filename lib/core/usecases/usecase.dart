import 'package:dartz/dartz.dart';
import '../error/failures.dart';

/// Lớp cơ sở cho tất cả Use Cases
/// [Type] - kiểu trả về của use case
/// [Params] - tham số đầu vào
abstract class UseCase<Type, Params> {
  Future<Either<Failure, Type>> call(Params params);
}

/// Dùng khi use case không cần tham số
class NoParams {
  const NoParams();
}
