import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import 'admin_group_edit_screen.dart';

/// Tab Quản lý nhóm chat.
class AdminGroupsTab extends StatefulWidget {
  const AdminGroupsTab({super.key});

  @override
  State<AdminGroupsTab> createState() => _AdminGroupsTabState();
}

class _AdminGroupsTabState extends State<AdminGroupsTab> with AutomaticKeepAliveClientMixin {
  List<dynamic> _groups = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() => _isLoading = true);
    try {
      _groups = await ApiService.adminGetGroups();
    } catch (e) {
      debugPrint('Lỗi tải nhóm: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? AppColors.error : AppColors.success),
    );
  }

  Future<void> _openEdit(Map<String, dynamic> group) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminGroupEditScreen(
          chatId: group['id'].toString(),
          initialName: group['name']?.toString() ?? 'Nhóm',
        ),
      ),
    );
    _loadGroups();
  }

  Future<void> _deleteGroup(Map<String, dynamic> group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Giải tán nhóm'),
        content: Text('Bạn có chắc muốn giải tán nhóm "${group['name']}"? Toàn bộ tin nhắn sẽ bị xóa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Giải tán', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirm != true) return;
    final ok = await ApiService.adminDeleteGroup(group['id'].toString());
    _showSnack(ok ? 'Đã giải tán nhóm' : 'Thất bại', error: !ok);
    if (ok) _loadGroups();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
              ? const Center(child: Text('Chưa có nhóm nào', style: TextStyle(color: AppColors.textSecondary)))
              : RefreshIndicator(
                  onRefresh: _loadGroups,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _groups.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final g = _groups[index] as Map<String, dynamic>;
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          onTap: () => _openEdit(g),
                          leading: CircleAvatar(
                            backgroundColor: Colors.deepPurple.withValues(alpha: 0.12),
                            backgroundImage: (g['avatar_url'] != null && g['avatar_url'].toString().startsWith('data:image'))
                                ? _imageFromDataUri(g['avatar_url'])
                                : null,
                            child: (g['avatar_url'] == null || !g['avatar_url'].toString().startsWith('data:image'))
                                ? const Icon(Icons.groups, color: Colors.deepPurple)
                                : null,
                          ),
                          title: Text(g['name'] ?? 'Nhóm', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${g['member_count'] ?? 0} thành viên • ${g['message_count'] ?? 0} tin nhắn'),
                          trailing: PopupMenuButton<String>(
                            onSelected: (a) {
                              if (a == 'edit') _openEdit(g);
                              if (a == 'delete') _deleteGroup(g);
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa nhóm')),
                              const PopupMenuItem(value: 'delete', child: Text('Giải tán nhóm', style: TextStyle(color: AppColors.error))),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
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
