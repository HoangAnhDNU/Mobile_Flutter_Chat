import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_routes.dart';
import 'core/services/api_service.dart';
import 'core/themes/app_theme.dart';
import 'core/themes/theme_provider.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/auth/screens/forgot_password_screen.dart';
import 'features/chat/screens/chat_list_screen.dart';
import 'features/chat/screens/chat_detail_screen.dart';
import 'features/chat/screens/create_chat_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/chat/screens/group_settings_screen.dart';
import 'features/admin/screens/admin_dashboard_screen.dart';
import 'features/friends/screens/friends_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await ApiService.init();
  } catch (e) {
    debugPrint('ApiService init error: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Flutter Chat',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme,
            initialRoute: AppRoutes.splash,
            // Khi refresh trên web ở một route bất kỳ (vd /#/admin, /#/chat-detail),
            // luôn khởi động lại từ splash để nạp lại phiên đăng nhập rồi điều hướng
            // đúng, tránh dựng thẳng màn hình thiếu dữ liệu hoặc thiếu arguments.
            onGenerateInitialRoutes: (initialRoute) => [
              MaterialPageRoute(
                settings: const RouteSettings(name: AppRoutes.splash),
                builder: (context) => const SplashScreen(),
              ),
            ],
            routes: {
              AppRoutes.splash: (context) => const SplashScreen(),
              AppRoutes.login: (context) => const LoginScreen(),
              AppRoutes.register: (context) => const RegisterScreen(),
              AppRoutes.forgotPassword: (context) => const ForgotPasswordScreen(),
              AppRoutes.chatList: (context) => const ChatListScreen(),
              AppRoutes.profile: (context) => const ProfileScreen(),
              AppRoutes.adminDashboard: (context) => const AdminDashboardScreen(),
              AppRoutes.friends: (context) => const FriendsScreen(),
            },
            onGenerateRoute: (settings) {
              if (settings.name == AppRoutes.chatDetail) {
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  settings: settings,
                  builder: (context) => ChatDetailScreen(
                    chatId: args['chatId'],
                    chatName: args['chatName'],
                    isGroup: args['isGroup'] ?? false,
                  ),
                );
              } else if (settings.name == AppRoutes.createChat) {
                return MaterialPageRoute(
                  settings: settings,
                  builder: (context) => const CreateChatScreen(),
                );
              } else if (settings.name == AppRoutes.groupSettings) {
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  settings: settings,
                  builder: (context) => GroupSettingsScreen(
                    chatId: args['chatId'],
                  ),
                );
              }
              return null;
            },
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('vi', 'VN'),
              Locale('en', 'US'),
            ],
            locale: const Locale('vi', 'VN'),
          );
        },
      ),
    );
  }
}
