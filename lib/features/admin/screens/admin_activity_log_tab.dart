import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);
    switch (action) {
      case 'lock_user': return l10n.translate('log_lock_user');
      case 'unlock_user': return l10n.translate('log_unlock_user');
      case 'delete_user': return l10n.translate('log_delete_user');
      case 'create_user': return l10n.translate('log_create_user');
      case 'reset_password': return l10n.translate('log_reset_password');
      case 'delete_group': return l10n.translate('log_delete_group');
      case 'login': return l10n.translate('log_login');
      default: return action;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_logs.isEmpty) return Center(child: Text(AppLocalizations.of(context).translate('no_logs')));

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
              '${log['admin_name'] ?? AppLocalizations.of(context).translate('admin')} • ${log['target_type'] ?? ''} #${log['target_id'] ?? ''}\n${log['details'] ?? ''}',
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
