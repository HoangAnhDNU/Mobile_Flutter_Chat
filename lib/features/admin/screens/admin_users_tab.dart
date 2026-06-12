import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/socket_service.dart';
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
      _showSnack(locked ? 'Đã mở khóa tài khoản' : 'Đã khóa tài khoản');
      loadUsers(query: _searchController.text);
    } else {
      _showSnack('Thao tác thất bại', error: true);
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa người dùng'),
        content: Text('Bạn có chắc muốn xóa "${user['display_name']}"? Toàn bộ dữ liệu liên quan sẽ bị xóa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final ok = await ApiService.adminDeleteUser(user['id']);
    if (ok) {
      _showSnack('Đã xóa người dùng');
      loadUsers(query: _searchController.text);
    } else {
      _showSnack('Không thể xóa người dùng này', error: true);
    }
  }

  Future<void> _resetPassword(Map<String, dynamic> user) async {
    final controller = TextEditingController();
    final newPass = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đặt lại mật khẩu'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Mật khẩu mới (tối thiểu 6 ký tự)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Lưu')),
        ],
      ),
    );
    if (newPass == null) return;
    if (newPass.length < 6) {
      _showSnack('Mật khẩu phải từ 6 ký tự', error: true);
      return;
    }
    final ok = await ApiService.adminResetPassword(user['id'], newPass);
    _showSnack(ok ? 'Đã đặt lại mật khẩu' : 'Thất bại', error: !ok);
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
        label: const Text('Thêm'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm theo tên hoặc email...',
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
                    ? const Center(child: Text('Không có người dùng', style: TextStyle(color: AppColors.textSecondary)))
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
      subtitle: Text('${user['email'] ?? ''}${online ? ' • đang online' : ''}', style: const TextStyle(fontSize: 12)),
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
          const PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa thông tin')),
          PopupMenuItem(value: 'lock', child: Text(locked ? 'Mở khóa' : 'Khóa tài khoản')),
          const PopupMenuItem(value: 'reset', child: Text('Đặt lại mật khẩu')),
          const PopupMenuItem(value: 'delete', child: Text('Xóa', style: TextStyle(color: AppColors.error))),
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
