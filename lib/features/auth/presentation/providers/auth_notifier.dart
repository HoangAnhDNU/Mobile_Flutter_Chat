import 'package:flutter/foundation.dart';

import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/register_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/get_current_user_usecase.dart';
import '../../../../core/usecases/usecase.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

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

  AuthStatus _status = AuthStatus.initial;
  AuthStatus get status => _status;

  String? _uid;
  String? _email;
  String? _displayName;
  String? _avatarUrl;
  String? _errorMessage;

  String? get uid => _uid;
  String? get email => _email;
  String? get displayName => _displayName;
  String? get avatarUrl => _avatarUrl;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _uid != null && _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> checkAuthStatus() async {
    _status = AuthStatus.loading;
    notifyListeners();

    final result = await getCurrentUserUseCase(NoParams());

    result.fold(
      (failure) {
        _status = AuthStatus.unauthenticated;
        _uid = null;
        _email = null;
        _displayName = null;
        _avatarUrl = null;
        notifyListeners();
      },
      (user) {
        _status = AuthStatus.authenticated;
        _uid = user.id;
        _email = user.email;
        _displayName = user.displayName;
        _avatarUrl = user.avatarUrl;
        notifyListeners();
      },
    );
  }

  Future<bool> login(String email, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await loginUseCase(
      LoginParams(email: email.trim(), password: password),
    );

    return result.fold(
      (failure) {
        _status = AuthStatus.error;
        _errorMessage = _getErrorMessage(failure.toString());
        notifyListeners();
        return false;
      },
      (user) {
        _status = AuthStatus.authenticated;
        _uid = user.id;
        _email = user.email;
        _displayName = user.displayName;
        _avatarUrl = user.avatarUrl;
        notifyListeners();
        return true;
      },
    );
  }

  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await registerUseCase(
      RegisterParams(
        email: email.trim(),
        password: password,
        displayName: displayName.trim(),
      ),
    );

    return result.fold(
      (failure) {
        _status = AuthStatus.error;
        _errorMessage = _getErrorMessage(failure.toString());
        notifyListeners();
        return false;
      },
      (user) {
        _status = AuthStatus.authenticated;
        _uid = user.id;
        _email = user.email;
        _displayName = user.displayName;
        _avatarUrl = user.avatarUrl;
        notifyListeners();
        return true;
      },
    );
  }

  Future<void> logout() async {
    _status = AuthStatus.loading;
    notifyListeners();

    await logoutUseCase(NoParams());

    _status = AuthStatus.unauthenticated;
    _uid = null;
    _email = null;
    _displayName = null;
    _avatarUrl = null;
    notifyListeners();
  }

  String _getErrorMessage(String failure) {
    if (failure.contains('ServerFailure')) {
      return 'Lỗi kết nối server. Vui lòng thử lại.';
    } else if (failure.contains('NetworkFailure')) {
      return 'Không có kết nối mạng.';
    } else if (failure.contains('AuthFailure')) {
      return 'Email hoặc mật khẩu không đúng.';
    } else if (failure.contains('ValidationFailure')) {
      return 'Thông tin không hợp lệ.';
    }
    return 'Đã xảy ra lỗi. Vui lòng thử lại.';
  }
}
