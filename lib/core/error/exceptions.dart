/// Exception cơ sở cho Server errors
class ServerException implements Exception {
  final String message;
  final int? statusCode;
  
  const ServerException({
    this.message = 'Lỗi máy chủ',
    this.statusCode,
  });
}

/// Exception cho Cache errors
class CacheException implements Exception {
  final String message;
  
  const CacheException([this.message = 'Lỗi bộ nhớ đệm']);
}

/// Exception cho Network errors
class NetworkException implements Exception {
  final String message;
  
  const NetworkException([this.message = 'Không có kết nối mạng']);
}

/// Exception cho Authentication errors
class AuthException implements Exception {
  final String message;
  
  const AuthException([this.message = 'Lỗi xác thực']);
}
