import 'package:flutter/foundation.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/register_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/get_current_user_usecase.dart';

/// Trạng thái xác thực
enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

/// Provider quản lý state xác thực theo Clean Architecture
class AuthNotifier extends ChangeNotifier {
  final LoginUseCase loginUseCase;
  final RegisterUseCase registerUseCase;
  final LogoutUseCase logoutUseCase;
  final GetCurrentUserUseCase getCurrentUserUseCase;

  AuthNotifier({
    required this.loginUseCase,
    required this.registerUseCase,
    required this.logoutUseCase,
    required this.getCurrentUserUseCase,
  });

  // State
  AuthStatus _status = AuthStatus.initial;
  UserEntity? _user;
  String? _errorMessage;

  // Getters
  AuthStatus get status => _status;
  UserEntity? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;

  /// Đăng nhập
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await loginUseCase(LoginParams(
      email: email,
      password: password,
    ));

    return result.fold(
      (failure) {
        _status = AuthStatus.error;
        _errorMessage = failure.message;
        notifyListeners();
        return false;
      },
      (user) {
        _user = user;
        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      },
    );
  }

  /// Đăng ký
  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await registerUseCase(RegisterParams(
      email: email,
      password: password,
      displayName: displayName,
    ));

    return result.fold(
      (failure) {
        _status = AuthStatus.error;
        _errorMessage = failure.message;
        notifyListeners();
        return false;
      },
      (user) {
        _user = user;
        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      },
    );
  }

  /// Đăng xuất
  Future<void> logout() async {
    _status = AuthStatus.loading;
    notifyListeners();

    await logoutUseCase(const NoParams());
    
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// Kiểm tra và khôi phục phiên đăng nhập
  Future<void> checkAuthStatus() async {
    _status = AuthStatus.loading;
    notifyListeners();

    final result = await getCurrentUserUseCase(const NoParams());

    result.fold(
      (failure) {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
      },
      (user) {
        _user = user;
        _status = AuthStatus.authenticated;
        notifyListeners();
      },
    );
  }

  /// Xóa thông báo lỗi
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
