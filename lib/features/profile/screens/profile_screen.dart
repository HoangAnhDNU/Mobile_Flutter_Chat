import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_config.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/services/api_service.dart';
import '../../../core/themes/theme_provider.dart';
import '../../../core/utils/app_localizations.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();

  bool _isEditing = false;
  bool _notificationsEnabled = true;
  String _avatarUrl = '';
  String _email = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadPreferences();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.uid == null) return;

    setState(() {
      _nameController.text = authProvider.displayName ?? '';
      _avatarUrl = authProvider.avatarUrl ?? '';
      _email = authProvider.email ?? '';
    });
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications') ?? true;
    });
  }

  Future<void> _updateDisplayName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    final authProvider = context.read<AuthProvider>();
    if (authProvider.uid == null) return;

    await ApiService.updateUser(authProvider.uid!, displayName: newName);
    await authProvider.updateUserData(displayName: newName);

    setState(() => _isEditing = false);
    await _loadUserData();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã cập nhật tên'), backgroundColor: AppColors.success),
    );
  }

  Future<void> _changeAvatar() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.uid == null) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 30, maxWidth: 400);
    if (pickedFile == null) return;

    final file = File(pickedFile.path);
    final bytes = await file.readAsBytes();
    final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';

    await ApiService.updateUser(authProvider.uid!, avatarUrl: base64Image);
    await authProvider.updateUserData(avatarUrl: base64Image);

    setState(() => _avatarUrl = base64Image);
  }

  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications', value);
    setState(() => _notificationsEnabled = value);
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Đăng xuất', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    await authProvider.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
  }

  Future<void> _showChangePasswordDialog() async {
    final oldC = TextEditingController();
    final newC = TextEditingController();
    final confirmC = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đổi mật khẩu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldC,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mật khẩu hiện tại'),
            ),
            TextField(
              controller: newC,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mật khẩu mới (≥6 ký tự)'),
            ),
            TextField(
              controller: confirmC,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Xác nhận mật khẩu mới'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cập nhật')),
        ],
      ),
    );

    if (result != true) return;
    if (newC.text.length < 6) {
      _showSnack('Mật khẩu mới phải từ 6 ký tự', error: true);
      return;
    }
    if (newC.text != confirmC.text) {
      _showSnack('Xác nhận mật khẩu không khớp', error: true);
      return;
    }
    final res = await ApiService.changePassword(oldC.text, newC.text);
    if (res['ok'] == true) {
      _showSnack(res['message']?.toString() ?? 'Đổi mật khẩu thành công');
    } else {
      _showSnack(res['error']?.toString() ?? 'Đổi mật khẩu thất bại', error: true);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? AppColors.error : AppColors.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('profile')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.check, color: AppColors.primary),
              onPressed: _updateDisplayName,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            GestureDetector(
              onTap: _changeAvatar,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        backgroundImage: _avatarUrl.isNotEmpty ? NetworkImage(AppConfig.resolveMediaUrl(_avatarUrl)) : null,
                    child: _avatarUrl.isEmpty
                        ? const Icon(Icons.person, size: 50, color: AppColors.primary)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              enabled: _isEditing,
              decoration: InputDecoration(
                labelText: l10n.translate('display_name'),
                suffixIcon: IconButton(
                  icon: Icon(_isEditing ? Icons.close : Icons.edit, size: 20),
                  onPressed: () => setState(() => _isEditing = !_isEditing),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              enabled: false,
              decoration: InputDecoration(
                labelText: l10n.translate('email'),
                hintText: _email,
              ),
              controller: TextEditingController(text: _email),
            ),
            const SizedBox(height: 32),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(l10n.translate('notifications')),
                    subtitle: const Text('Nhận thông báo tin nhắn mới'),
                    value: _notificationsEnabled,
                    onChanged: _toggleNotifications,
                    activeTrackColor: AppColors.primary,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: Text(l10n.translate('dark_mode')),
                    subtitle: const Text('Giao diện tối cho mắt'),
                    value: context.watch<ThemeProvider>().isDarkMode,
                    onChanged: (value) => context.read<ThemeProvider>().toggleTheme(),
                    activeTrackColor: AppColors.primary,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: Text(l10n.translate('language')),
                    subtitle: Text(context.watch<ThemeProvider>().locale.languageCode == 'vi' ? 'Tiếng Việt' : 'English'),
                    trailing: const Icon(Icons.language, size: 20),
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                title: const Text('Tiếng Việt'),
                                trailing: context.read<ThemeProvider>().locale.languageCode == 'vi' ? const Icon(Icons.check, color: AppColors.primary) : null,
                                onTap: () {
                                  context.read<ThemeProvider>().setLanguage('vi');
                                  Navigator.pop(context);
                                },
                              ),
                              ListTile(
                                title: const Text('English'),
                                trailing: context.read<ThemeProvider>().locale.languageCode == 'en' ? const Icon(Icons.check, color: AppColors.primary) : null,
                                onTap: () {
                                  context.read<ThemeProvider>().setLanguage('en');
                                  Navigator.pop(context);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.lock_outline, size: 20),
                    title: const Text('Đổi mật khẩu'),
                    subtitle: const Text('Cập nhật mật khẩu đăng nhập'),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: _showChangePasswordDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout, color: Colors.white),
                label: Text(l10n.translate('logout')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
