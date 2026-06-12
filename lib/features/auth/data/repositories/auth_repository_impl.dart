import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/auth_remote_data_source.dart';

/// Implementation của AuthRepository
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, UserEntity>> login({
    required String email,
    required String password,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final response = await remoteDataSource.login(
          email: email,
          password: password,
        );
        await localDataSource.cacheUser(response.user);
        await localDataSource.cacheToken(response.token);
        return Right(response.user);
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, UserEntity>> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final response = await remoteDataSource.register(
          email: email,
          password: password,
          displayName: displayName,
        );
        await localDataSource.cacheUser(response.user);
        await localDataSource.cacheToken(response.token);
        return Right(response.user);
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      if (await networkInfo.isConnected) {
        final token = await localDataSource.getCachedToken();
        await remoteDataSource.logout(token);
      }
      await localDataSource.clearCache();
      return const Right(null);
    } on ServerException catch (e) {
      // Vẫn clear cache local dù server error
      await localDataSource.clearCache();
      return Left(ServerFailure(e.message));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() async {
    try {
      // Thử lấy từ cache trước
      final cachedUser = await localDataSource.getCachedUser();
      
      // Nếu có mạng, cập nhật từ server
      if (await networkInfo.isConnected) {
        try {
          final token = await localDataSource.getCachedToken();
          final remoteUser = await remoteDataSource.getCurrentUser(token);
          await localDataSource.cacheUser(remoteUser);
          return Right(remoteUser);
        } on ServerException {
          // Nếu server error, trả về cached user
          return Right(cachedUser);
        }
      }
      
      return Right(cachedUser);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<bool> isLoggedIn() async {
    return await localDataSource.hasUser();
  }

  @override
  Future<Either<Failure, void>> refreshToken() async {
    // TODO: Implement refresh token logic
    return const Right(null);
  }
}
