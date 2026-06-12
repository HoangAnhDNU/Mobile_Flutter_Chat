/// Lớp cơ sở cho tất cả các failures trong ứng dụng
abstract class Failure {
  final String message;
  const Failure(this.message);
}

/// Server failure - lỗi từ API
class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Lỗi máy chủ']);
}

/// Cache failure - lỗi lưu trữ cục bộ
class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Lỗi bộ nhớ đệm']);
}

/// Network failure - lỗi kết nối mạng
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Không có kết nối mạng']);
}

/// Authentication failure - lỗi xác thực
class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Lỗi xác thực']);
}

/// Validation failure - lỗi validate dữ liệu
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}
