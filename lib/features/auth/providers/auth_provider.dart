import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/socket_service.dart';

class AuthProvider extends ChangeNotifier {
  String? _uid;
  String? _email;
  String? _displayName;
  String? _avatarUrl;
  String _role = 'user';

  String? get uid => _uid;
  String? get email => _email;
  String? get displayName => _displayName;
  String? get avatarUrl => _avatarUrl;
  String get role => _role;
  bool get isAdmin => _role == 'admin';
  bool get isLoggedIn => _uid != null;

  Future<void> loadUserFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _uid = prefs.getString('uid');
    _email = prefs.getString('email');
    _displayName = prefs.getString('displayName');
    _avatarUrl = prefs.getString('avatarUrl');
    _role = prefs.getString('role') ?? 'user';

    if (_uid != null) {
      try {
        final userData = await ApiService.getUser(_uid!);
        _displayName = userData['display_name'];
        _avatarUrl = userData['avatar_url'];
        if (userData['role'] != null) _role = userData['role'];
        await _saveUserToPrefs();
      } catch (e) {
        debugPrint('Error refreshing user data: $e');
      }
      // Khôi phục phiên -> kết nối socket để đánh dấu online
      SocketService.instance.connect(_uid!);
    }
    notifyListeners();
  }

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
      _role = result['user']['role'] ?? 'user';
      await _saveUserToPrefs();

      // Kết nối socket ngay khi đăng nhập để đánh dấu online + nhận realtime
      if (_uid != null) SocketService.instance.connect(_uid!);

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
      await _saveUserToPrefs();

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

  Future<void> _saveUserToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (_uid != null) prefs.setString('uid', _uid!);
    if (_email != null) prefs.setString('email', _email!);
    if (_displayName != null) prefs.setString('displayName', _displayName!);
    if (_avatarUrl != null) prefs.setString('avatarUrl', _avatarUrl!);
    prefs.setString('role', _role);
  }

  Future<void> updateUserData({String? displayName, String? avatarUrl}) async {
    if (displayName != null) _displayName = displayName;
    if (avatarUrl != null) _avatarUrl = avatarUrl;
    await _saveUserToPrefs();
    notifyListeners();
  }

  Future<void> signOut() async {
    // Ngắt socket trước để backend đánh dấu offline + phát presence_update
    SocketService.instance.disconnect();
    await ApiService.logout();
    _uid = null;
    _email = null;
    _displayName = null;
    _avatarUrl = null;
    _role = 'user';
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }

}
