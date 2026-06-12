import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/constants/app_config.dart';
import '../../../../core/error/exceptions.dart';
import '../models/user_model.dart';

/// Interface cho Remote Data Source
abstract class AuthRemoteDataSource {
  /// Đăng nhập và trả về user với token
  Future<AuthResponse> login({
    required String email,
    required String password,
  });

  /// Đăng ký tài khoản mới
  Future<AuthResponse> register({
    required String email,
    required String password,
    required String displayName,
  });

  /// Đăng xuất
  Future<void> logout(String token);

  /// Lấy thông tin user hiện tại
  Future<UserModel> getCurrentUser(String token);
}

/// Response chứa user và token
class AuthResponse {
  final UserModel user;
  final String token;

  AuthResponse({required this.user, required this.token});
}

/// Implementation cho Remote Data Source
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final http.Client client;

  AuthRemoteDataSourceImpl({required this.client});

  String get _baseUrl => AppConfig.baseOrigin;

  @override
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await client.post(
      Uri.parse('$_baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return AuthResponse(
        user: UserModel.fromJson(data['user']),
        token: data['token'],
      );
    } else {
      final error = jsonDecode(response.body);
      throw ServerException(
        message: error['message'] ?? 'Đăng nhập thất bại',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<AuthResponse> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await client.post(
      Uri.parse('$_baseUrl/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'display_name': displayName,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return AuthResponse(
        user: UserModel.fromJson(data['user']),
        token: data['token'],
      );
    } else {
      final error = jsonDecode(response.body);
      throw ServerException(
        message: error['message'] ?? 'Đăng ký thất bại',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<void> logout(String token) async {
    final response = await client.post(
      Uri.parse('$_baseUrl/api/auth/logout'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw ServerException(
        message: 'Đăng xuất thất bại',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<UserModel> getCurrentUser(String token) async {
    final response = await client.get(
      Uri.parse('$_baseUrl/api/user/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return UserModel.fromJson(data['user'] ?? data);
    } else {
      throw ServerException(
        message: 'Không thể lấy thông tin người dùng',
        statusCode: response.statusCode,
      );
    }
  }
}
