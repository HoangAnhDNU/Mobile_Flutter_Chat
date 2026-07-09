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
import 'privacy_settings_screen.dart';
import 'blocked_users_screen.dart';

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

  ImageProvider _getAvatarImage(String url) {
    if (url.startsWith('data:')) {
      final base64Str = url.split(',').last;
      return MemoryImage(base64Decode(base64Str));
    }
    return NetworkImage(AppConfig.resolveMediaUrl(url));
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
      SnackBar(content: Text(AppLocalizations.of(context).translate('name_updated')), backgroundColor: AppColors.success),
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
        title: Text(AppLocalizations.of(context).translate('logout')),
        content: Text(AppLocalizations.of(context).translate('logout_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppLocalizations.of(context).translate('cancel'))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(AppLocalizations.of(context).translate('logout'), style: const TextStyle(color: AppColors.error))),
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
        title: Text(AppLocalizations.of(context).translate('change_password')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldC,
              obscureText: true,
              decoration: InputDecoration(labelText: AppLocalizations.of(context).translate('current_password')),
            ),
            TextField(
              controller: newC,
              obscureText: true,
              decoration: InputDecoration(labelText: AppLocalizations.of(context).translate('new_password')),
            ),
            TextField(
              controller: confirmC,
              obscureText: true,
              decoration: InputDecoration(labelText: AppLocalizations.of(context).translate('confirm_new_password')),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(context).translate('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppLocalizations.of(context).translate('update'))),
        ],
      ),
    );

    if (result != true) return;
    if (!mounted) return;
    if (newC.text.length < 6) {
      _showSnack(AppLocalizations.of(context).translate('password_min_6'), error: true);
      return;
    }
    if (newC.text != confirmC.text) {
      _showSnack(AppLocalizations.of(context).translate('password_mismatch'), error: true);
      return;
    }
    final res = await ApiService.changePassword(oldC.text, newC.text);
    if (!mounted) return;
    if (res['ok'] == true) {
      _showSnack(res['message']?.toString() ?? AppLocalizations.of(context).translate('password_changed'));
    } else {
      _showSnack(res['error']?.toString() ?? AppLocalizations.of(context).translate('password_change_failed'), error: true);
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
                    backgroundImage: _avatarUrl.isNotEmpty ? _getAvatarImage(_avatarUrl) : null,
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
                    subtitle: Text(l10n.translate('notifications_subtitle')),
                    value: _notificationsEnabled,
                    onChanged: _toggleNotifications,
                    activeTrackColor: AppColors.primary,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: Text(l10n.translate('dark_mode')),
                    subtitle: Text(l10n.translate('dark_mode_subtitle')),
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
                                title: Text(l10n.translate('vietnamese')),
                                trailing: context.read<ThemeProvider>().locale.languageCode == 'vi' ? const Icon(Icons.check, color: AppColors.primary) : null,
                                onTap: () {
                                  context.read<ThemeProvider>().setLanguage('vi');
                                  Navigator.pop(context);
                                },
                              ),
                              ListTile(
                                title: Text(l10n.translate('english')),
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
                    title: Text(l10n.translate('change_password')),
                    subtitle: Text(l10n.translate('change_password_subtitle')),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: _showChangePasswordDialog,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.shield_outlined, size: 20),
                    title: Text(l10n.translate('privacy')),
                    subtitle: Text(l10n.translate('privacy_subtitle')),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacySettingsScreen())),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.notifications_outlined, size: 20),
                    title: Text('Cài đặt thông báo'),
                    subtitle: Text('Âm thanh, rung, xem trước'),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => Navigator.pushNamed(context, AppRoutes.notificationSettings),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.block, size: 20),
                    title: Text(l10n.translate('blocked_users')),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BlockedUsersScreen())),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.text_fields, size: 20),
                    title: Text(l10n.translate('font_size')),
                    subtitle: Text('${context.watch<ThemeProvider>().fontSize.toInt()}'),
                    trailing: SizedBox(
                      width: 150,
                      child: Slider(
                        value: context.watch<ThemeProvider>().fontSize,
                        min: 13,
                        max: 24,
                        divisions: 11,
                        onChanged: (v) => context.read<ThemeProvider>().setFontSize(v),
                      ),
                    ),
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
