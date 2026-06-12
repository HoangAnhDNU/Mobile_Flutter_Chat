import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/error/exceptions.dart';
import '../models/user_model.dart';

/// Keys cho SharedPreferences
class AuthCacheKeys {
  static const String cachedUser = 'CACHED_USER';
  static const String cachedToken = 'CACHED_TOKEN';
}

/// Interface cho Local Data Source
abstract class AuthLocalDataSource {
  /// Lấy user đã cache
  Future<UserModel> getCachedUser();

  /// Lưu user vào cache
  Future<void> cacheUser(UserModel user);

  /// Lấy token đã cache
  Future<String> getCachedToken();

  /// Lưu token vào cache
  Future<void> cacheToken(String token);

  /// Xóa tất cả cache (khi logout)
  Future<void> clearCache();

  /// Kiểm tra có user trong cache không
  Future<bool> hasUser();
}

/// Implementation cho Local Data Source
class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final SharedPreferences sharedPreferences;

  AuthLocalDataSourceImpl({required this.sharedPreferences});

  @override
  Future<UserModel> getCachedUser() async {
    final jsonString = sharedPreferences.getString(AuthCacheKeys.cachedUser);
    if (jsonString != null) {
      return UserModel.fromJson(jsonDecode(jsonString));
    } else {
      throw const CacheException('Không tìm thấy user trong cache');
    }
  }

  @override
  Future<void> cacheUser(UserModel user) async {
    await sharedPreferences.setString(
      AuthCacheKeys.cachedUser,
      jsonEncode(user.toJson()),
    );
  }

  @override
  Future<String> getCachedToken() async {
    final token = sharedPreferences.getString(AuthCacheKeys.cachedToken);
    if (token != null) {
      return token;
    } else {
      throw const CacheException('Không tìm thấy token trong cache');
    }
  }

  @override
  Future<void> cacheToken(String token) async {
    await sharedPreferences.setString(AuthCacheKeys.cachedToken, token);
  }

  @override
  Future<void> clearCache() async {
    await sharedPreferences.remove(AuthCacheKeys.cachedUser);
    await sharedPreferences.remove(AuthCacheKeys.cachedToken);
  }

  @override
  Future<bool> hasUser() async {
    return sharedPreferences.containsKey(AuthCacheKeys.cachedUser) &&
           sharedPreferences.containsKey(AuthCacheKeys.cachedToken);
  }
}
