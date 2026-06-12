import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Core
import 'core/network/network_info.dart';

// Auth Feature
import 'features/auth/data/datasources/auth_local_data_source.dart';
import 'features/auth/data/datasources/auth_remote_data_source.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/usecases/login_usecase.dart';
import 'features/auth/domain/usecases/register_usecase.dart';
import 'features/auth/domain/usecases/logout_usecase.dart';
import 'features/auth/domain/usecases/get_current_user_usecase.dart';
import 'features/auth/presentation/providers/auth_notifier.dart';

// Chat Feature
import 'features/chat/data/datasources/chat_remote_data_source.dart';
import 'features/chat/data/repositories/chat_repository_impl.dart';
// import 'features/chat/data/repositories/message_repository_impl.dart';
import 'features/chat/domain/repositories/chat_repository.dart';
// import 'features/chat/domain/repositories/message_repository.dart';
import 'features/chat/domain/usecases/get_chats_usecase.dart';
import 'features/chat/presentation/providers/chat_provider.dart';

/// Service locator instance
final sl = GetIt.instance;

/// Khởi tạo tất cả dependencies
Future<void> init() async {
  //! Features - Auth
  // Providers
  sl.registerFactory(
    () => AuthNotifier(
      loginUseCase: sl(),
      registerUseCase: sl(),
      logoutUseCase: sl(),
      getCurrentUserUseCase: sl(),
    ),
  );

  // Use cases
  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton(() => RegisterUseCase(sl()));
  sl.registerLazySingleton(() => LogoutUseCase(sl()));
  sl.registerLazySingleton(() => GetCurrentUserUseCase(sl()));

  // Repository
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  // Data sources
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(client: sl()),
  );
  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(sharedPreferences: sl()),
  );

  //! Features - Chat
  // Providers
  sl.registerFactory(
    () => ChatNotifier(
      getChatsUseCase: sl(),
    ),
  );
  // TODO: MessageNotifier cần MessageRepository
  // sl.registerFactory(
  //   () => MessageNotifier(
  //     getMessagesUseCase: sl(),
  //     sendMessageUseCase: sl(),
  //   ),
  // );

  // Use cases
  sl.registerLazySingleton(() => GetChatsUseCase(sl()));
  // TODO: Message use cases cần MessageRepository
  // sl.registerLazySingleton(() => GetMessagesUseCase(sl()));
  // sl.registerLazySingleton(() => SendMessageUseCase(sl()));

  // Repository
  sl.registerLazySingleton<ChatRepository>(
    () => ChatRepositoryImpl(
      remoteDataSource: sl(),
      authLocalDataSource: sl(),
      networkInfo: sl(),
    ),
  );
  // TODO: Tạo MessageRepository sau
  // sl.registerLazySingleton<MessageRepository>(
  //   () => MessageRepositoryImpl(
  //     remoteDataSource: sl(),
  //     authLocalDataSource: sl(),
  //     networkInfo: sl(),
  //   ),
  // );

  // Data sources
  sl.registerLazySingleton<ChatRemoteDataSource>(
    () => ChatRemoteDataSourceImpl(client: sl()),
  );

  //! Core
  sl.registerLazySingleton<NetworkInfo>(
    () => NetworkInfoImpl(sl()),
  );

  //! External
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);
  sl.registerLazySingleton(() => http.Client());
  sl.registerLazySingleton(() => Connectivity());
}
