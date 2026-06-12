import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/user_entity.dart';

/// Interface cho Auth Repository
/// Định nghĩa các phương thức mà Data layer phải implement
abstract class AuthRepository {
  /// Đăng nhập với email và password
  Future<Either<Failure, UserEntity>> login({
    required String email,
    required String password,
  });

  /// Đăng ký tài khoản mới
  Future<Either<Failure, UserEntity>> register({
    required String email,
    required String password,
    required String displayName,
  });

  /// Đăng xuất
  Future<Either<Failure, void>> logout();

  /// Lấy user hiện tại từ cache
  Future<Either<Failure, UserEntity>> getCurrentUser();

  /// Kiểm tra đã đăng nhập chưa
  Future<bool> isLoggedIn();

  /// Cập nhật token
  Future<Either<Failure, void>> refreshToken();
}
