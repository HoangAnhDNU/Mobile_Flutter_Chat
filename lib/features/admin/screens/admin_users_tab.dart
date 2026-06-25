import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/socket_service.dart';
import '../../../core/utils/app_localizations.dart';
import 'admin_user_form_screen.dart';

/// Tab Quản lý người dùng.
class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key});

  @override
  State<AdminUsersTab> createState() => AdminUsersTabState();
}

class AdminUsersTabState extends State<AdminUsersTab> with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  List<dynamic> _users = [];
  bool _isLoading = true;
  StreamSubscription<Map<String, dynamic>>? _presenceSub;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    loadUsers();
    // Real-time: cập nhật danh sách khi có người online/offline
    _presenceSub = SocketService.instance.onPresence.listen((_) {
      if (mounted) loadUsers(query: _searchController.text, silent: true);
    });
  }

  @override
  void dispose() {
    _presenceSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> loadUsers({String? query, bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final data = await ApiService.adminGetUsers(query: query);
      _users = data['users'] as List;
    } catch (e) {
      debugPrint('Lỗi tải users: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? AppColors.error : AppColors.success),
    );
  }

  Future<void> _openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AdminUserFormScreen()),
    );
    if (created == true) loadUsers(query: _searchController.text);
  }

  Future<void> _openEdit(Map<String, dynamic> user) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AdminUserFormScreen(user: user)),
    );
    if (updated == true) loadUsers(query: _searchController.text);
  }

  Future<void> _toggleLock(Map<String, dynamic> user) async {
    final locked = user['is_locked'] == true;
    final ok = locked
        ? await ApiService.adminUnlockUser(user['id'])
        : await ApiService.adminLockUser(user['id']);
    if (ok) {
      _showSnack(locked ? AppLocalizations.of(context).translate('user_unlocked') : AppLocalizations.of(context).translate('user_locked'));
      loadUsers(query: _searchController.text);
    } else {
      _showSnack(AppLocalizations.of(context).translate('action_failed'), error: true);
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).translate('delete_user')),
        content: Text(AppLocalizations.of(context).tr('delete_user_confirm', params: {'name': user['display_name']})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(context).translate('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context).translate('delete'), style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final ok = await ApiService.adminDeleteUser(user['id']);
    if (ok) {
      _showSnack(AppLocalizations.of(context).translate('user_deleted'));
      loadUsers(query: _searchController.text);
    } else {
      _showSnack(AppLocalizations.of(context).translate('cannot_delete_user'), error: true);
    }
  }

  Future<void> _resetPassword(Map<String, dynamic> user) async {
    final controller = TextEditingController();
    final newPass = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).translate('reset_password')),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: InputDecoration(labelText: AppLocalizations.of(context).translate('new_password_min')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context).translate('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: Text(AppLocalizations.of(context).translate('save'))),
        ],
      ),
    );
    if (newPass == null) return;
    if (newPass.length < 6) {
      _showSnack(AppLocalizations.of(context).translate('password_min_6'), error: true);
      return;
    }
    final ok = await ApiService.adminResetPassword(user['id'], newPass);
    _showSnack(ok ? AppLocalizations.of(context).translate('password_reset') : AppLocalizations.of(context).translate('action_failed'), error: !ok);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: _openCreate,
        icon: const Icon(Icons.person_add),
        label: Text(AppLocalizations.of(context).translate('add')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).translate('search_users'),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onSubmitted: (v) => loadUsers(query: v),
              onChanged: (v) {
                if (v.isEmpty) loadUsers();
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _users.isEmpty
                    ? Center(child: Text(AppLocalizations.of(context).translate('no_users'), style: const TextStyle(color: AppColors.textSecondary)))
                    : RefreshIndicator(
                        onRefresh: () => loadUsers(query: _searchController.text),
                        child: ListView.separated(
                          itemCount: _users.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) => _userTile(_users[index] as Map<String, dynamic>),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _userTile(Map<String, dynamic> user) {
    final locked = user['is_locked'] == true;
    final isAdmin = user['role'] == 'admin';
    final online = user['is_online'] == true;
    return ListTile(
      onTap: () => _openEdit(user),
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
        backgroundImage: (user['avatar_url'] != null && user['avatar_url'].toString().startsWith('data:image'))
            ? _imageFromDataUri(user['avatar_url'])
            : null,
        child: (user['avatar_url'] == null || user['avatar_url'].toString().isEmpty)
            ? Text(
                (user['display_name'] ?? '?').toString().isNotEmpty ? user['display_name'][0].toUpperCase() : '?',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
              )
            : null,
      ),
      title: Row(
        children: [
          Flexible(child: Text(user['display_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
          if (isAdmin) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
              child: const Text('ADMIN', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ],
          if (locked) ...[
            const SizedBox(width: 6),
            const Icon(Icons.lock, size: 14, color: AppColors.error),
          ],
        ],
      ),
      subtitle: Text('${user['email'] ?? ''}${online ? ' • ${AppLocalizations.of(context).translate("online")}' : ''}', style: const TextStyle(fontSize: 12)),
      trailing: PopupMenuButton<String>(
        onSelected: (action) {
          switch (action) {
            case 'edit':
              _openEdit(user);
              break;
            case 'lock':
              _toggleLock(user);
              break;
            case 'reset':
              _resetPassword(user);
              break;
            case 'delete':
              _deleteUser(user);
              break;
          }
        },
        itemBuilder: (ctx) => [
          PopupMenuItem(value: 'edit', child: Text(AppLocalizations.of(context).translate('edit_user_info'))),
          PopupMenuItem(value: 'lock', child: Text(locked ? AppLocalizations.of(context).translate('unlock') : AppLocalizations.of(context).translate('lock_user'))),
          PopupMenuItem(value: 'reset', child: Text(AppLocalizations.of(context).translate('reset_password'))),
          PopupMenuItem(value: 'delete', child: Text(AppLocalizations.of(context).translate('delete'), style: const TextStyle(color: AppColors.error))),
        ],
      ),
    );
  }

  ImageProvider? _imageFromDataUri(String uri) {
    try {
      return MemoryImage(base64Decode(uri.split(',').last));
    } catch (_) {
      return null;
    }
  }
}
