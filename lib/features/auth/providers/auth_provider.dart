import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  String? _uid;
  String? _email;
  String? _displayName;
  String? _avatarUrl;

  String? get uid => _uid;
  String? get email => _email;
  String? get displayName => _displayName;
  String? get avatarUrl => _avatarUrl;
  bool get isLoggedIn => ApiService.isLoggedIn;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    try {
      _setLoading(true);
      _errorMessage = null;

      final result = await ApiService.login(
        email: email.trim(),
        password: password,
      );

      if (result.containsKey('error')) {
        _errorMessage = result['error'];
        _setLoading(false);
        return false;
      }

      _uid = result['user']['uid'];
      _email = result['user']['email'];
      _displayName = result['user']['displayName'];
      _avatarUrl = result['user']['avatarUrl'];

      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = 'Đã xảy ra lỗi. Vui lòng thử lại.';
      _setLoading(false);
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      _setLoading(true);
      _errorMessage = null;

      final result = await ApiService.register(
        email: email.trim(),
        password: password,
        displayName: displayName.trim(),
      );

      if (result.containsKey('error')) {
        _errorMessage = result['error'];
        _setLoading(false);
        return false;
      }

      _uid = result['user']['uid'];
      _email = result['user']['email'];
      _displayName = result['user']['displayName'];

      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = 'Đã xảy ra lỗi. Vui lòng thử lại.';
      _setLoading(false);
      return false;
    }
  }

  Future<bool> resetPassword(String email) async {
    try {
      _setLoading(true);
      _errorMessage = null;

      // Note: Password reset requires email service implementation
      // For now, return success but user needs to implement email service
      _errorMessage = 'Tính năng reset mật khẩu cần cấu hình email server.';
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = 'Đã xảy ra lỗi. Vui lòng thử lại.';
      _setLoading(false);
      return false;
    }
  }

  Future<void> signOut() async {
    await ApiService.logout();
    _uid = null;
    _email = null;
    _displayName = null;
    _avatarUrl = null;
    notifyListeners();
  }

}
