import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/app_localizations.dart';
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
          initialName: group['name']?.toString() ?? AppLocalizations.of(context).translate('group'),
        ),
      ),
    );
    _loadGroups();
  }

  Future<void> _deleteGroup(Map<String, dynamic> group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).translate('disband_group')),
        content: Text(AppLocalizations.of(context).tr('disband_group_confirm', params: {'name': group['name']})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(context).translate('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppLocalizations.of(context).translate('disband_group'), style: const TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirm != true) return;
    final ok = await ApiService.adminDeleteGroup(group['id'].toString());
    if (!mounted) return;
    _showSnack(ok ? AppLocalizations.of(context).translate('group_disbanded') : AppLocalizations.of(context).translate('action_failed'), error: !ok);
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
              ? Center(child: Text(AppLocalizations.of(context).translate('no_groups'), style: const TextStyle(color: AppColors.textSecondary)))
              : RefreshIndicator(
                  onRefresh: _loadGroups,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _groups.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
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
                          title: Text(g['name'] ?? AppLocalizations.of(context).translate('group'), style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(AppLocalizations.of(context).tr('group_members_messages', params: {'members': g['member_count'] ?? 0, 'messages': g['message_count'] ?? 0})),
                          trailing: PopupMenuButton<String>(
                            onSelected: (a) {
                              if (a == 'edit') _openEdit(g);
                              if (a == 'delete') _deleteGroup(g);
                            },
                            itemBuilder: (ctx) => [
                              PopupMenuItem(value: 'edit', child: Text(AppLocalizations.of(context).translate('edit_group'))),
                              PopupMenuItem(value: 'delete', child: Text(AppLocalizations.of(context).translate('disband_group'), style: const TextStyle(color: AppColors.error))),
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
