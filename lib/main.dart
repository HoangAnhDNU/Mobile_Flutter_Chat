import 'package:flutter/material.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp(
        title: 'Flutter Chat',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeProvider.themeMode,
        initialRoute: AppRoutes.splash,
        routes: {
          AppRoutes.splash: (_) => const SplashScreen(),
          AppRoutes.login: (_) => const LoginScreen(),
          AppRoutes.register: (_) => const RegisterScreen(),
          AppRoutes.forgotPassword: (_) => const ForgotPasswordScreen(),
          AppRoutes.chatList: (_) => const ChatListScreen(),
          AppRoutes.chatDetail: (_) => const ChatDetailScreen(),
          AppRoutes.createChat: (_) => const CreateChatScreen(),
          AppRoutes.profile: (_) => const ProfileScreen(),
          AppRoutes.groupSettings: (_) => const GroupSettingsScreen(),
        },
      ),
      ),
    );
  }
}
