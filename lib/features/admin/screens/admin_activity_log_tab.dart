import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';

class AdminActivityLogTab extends StatefulWidget {
  const AdminActivityLogTab({super.key});

  @override
  State<AdminActivityLogTab> createState() => _AdminActivityLogTabState();
}

class _AdminActivityLogTabState extends State<AdminActivityLogTab> {
  List<dynamic> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.getActivityLog();
      if (mounted) setState(() { _logs = (data['logs'] as List?) ?? []; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'lock_user': return 'Khóa tài khoản';
      case 'unlock_user': return 'Mở khóa tài khoản';
      case 'delete_user': return 'Xóa người dùng';
      case 'create_user': return 'Tạo người dùng';
      case 'reset_password': return 'Đặt lại mật khẩu';
      case 'delete_group': return 'Xóa nhóm';
      case 'login': return 'Đăng nhập';
      default: return action;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_logs.isEmpty) return const Center(child: Text('Chưa có nhật ký'));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: _logs.length,
        itemBuilder: (context, index) {
          final log = Map<String, dynamic>.from(_logs[index]);
          return ListTile(
            leading: const Icon(Icons.history),
            title: Text(_actionLabel(log['action'] ?? '')),
            subtitle: Text(
              '${log['admin_name'] ?? 'Admin'} • ${log['target_type'] ?? ''} #${log['target_id'] ?? ''}\n${log['details'] ?? ''}',
            ),
            trailing: Text(
              _formatTime(log['created_at']),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            isThreeLine: true,
          );
        },
      ),
    );
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
