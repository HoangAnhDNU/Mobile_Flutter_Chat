import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/app_localizations.dart';

/// Màn hình chỉnh sửa nhóm chat dành cho Admin:
/// đổi tên, đổi avatar, thêm/xóa thành viên.
class AdminGroupEditScreen extends StatefulWidget {
  final String chatId;
  final String initialName;

  const AdminGroupEditScreen({super.key, required this.chatId, required this.initialName});

  @override
  State<AdminGroupEditScreen> createState() => _AdminGroupEditScreenState();
}

class _AdminGroupEditScreenState extends State<AdminGroupEditScreen> {
  final _nameC = TextEditingController();
  Map<String, dynamic> _group = {};
  List<dynamic> _members = [];
  bool _isLoading = true;
  String? _avatarDataUri;

  @override
  void initState() {
    super.initState();
    _nameC.text = widget.initialName;
    _loadDetail();
  }

  @override
  void dispose() {
    _nameC.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.adminGetGroupDetail(widget.chatId);
      _group = Map<String, dynamic>.from(data['group'] as Map? ?? {});
      _members = (data['members'] as List?) ?? [];
      _nameC.text = _group['name']?.toString() ?? widget.initialName;
      _avatarDataUri = _group['avatar_url']?.toString();
    } catch (e) {
      debugPrint('Lỗi tải chi tiết nhóm: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? AppColors.error : AppColors.success),
    );
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 40, maxWidth: 400);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _avatarDataUri = 'data:image/png;base64,${base64Encode(bytes)}');
  }

  Future<void> _saveInfo() async {
    final ok = await ApiService.adminUpdateGroup(
      widget.chatId,
      name: _nameC.text.trim(),
      avatarUrl: _avatarDataUri,
    );
    if (!mounted) return;
    _showSnack(ok ? AppLocalizations.of(context).translate('group_info_saved') : AppLocalizations.of(context).translate('save_failed'), error: !ok);
    if (ok) _loadDetail();
  }

  Future<void> _removeMember(Map<String, dynamic> member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).translate('remove_member')),
        content: Text(AppLocalizations.of(context).tr('remove_member_from_group', params: {'name': member['display_name']})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(context).translate('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppLocalizations.of(context).translate('delete'), style: const TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirm != true) return;
    final ok = await ApiService.adminRemoveGroupMember(widget.chatId, member['id'].toString());
    if (!mounted) return;
    _showSnack(ok ? AppLocalizations.of(context).translate('member_removed') : AppLocalizations.of(context).translate('action_failed'), error: !ok);
    if (ok) _loadDetail();
  }

  Future<void> _addMembers() async {
    // Lấy toàn bộ user, loại những người đã là thành viên
    final all = await ApiService.getUsers();
    final memberIds = _members.map((m) => m['id'].toString()).toSet();
    final candidates = all.where((u) => !memberIds.contains(u['id'].toString())).toList();

    if (!mounted) return;
    if (candidates.isEmpty) {
      _showSnack(AppLocalizations.of(context).translate('all_users_in_group'));
      return;
    }

    final selected = <String>{};
    final picked = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (ctx, scroll) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(AppLocalizations.of(context).translate('select_members_to_add'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scroll,
                  itemCount: candidates.length,
                  itemBuilder: (ctx, i) {
                    final u = candidates[i] as Map<String, dynamic>;
                    final id = u['id'].toString();
                    final checked = selected.contains(id);
                    return CheckboxListTile(
                      value: checked,
                      title: Text(u['display_name'] ?? ''),
                      subtitle: Text(u['email'] ?? '', style: const TextStyle(fontSize: 12)),
                      onChanged: (v) => setLocal(() => v == true ? selected.add(id) : selected.remove(id)),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(AppLocalizations.of(context).tr('add_members_count', params: {'count': selected.length})),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (picked == true && selected.isNotEmpty) {
      final ok = await ApiService.adminAddGroupMembers(widget.chatId, selected.toList());
      if (!mounted) return;
      _showSnack(ok ? AppLocalizations.of(context).translate('members_added') : AppLocalizations.of(context).translate('action_failed'), error: !ok);
      if (ok) _loadDetail();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).translate('edit_group'), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.save), tooltip: AppLocalizations.of(context).translate('save'), onPressed: _saveInfo),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: Colors.deepPurple.withValues(alpha: 0.12),
                        backgroundImage: (_avatarDataUri != null && _avatarDataUri!.startsWith('data:image'))
                            ? _imageFromDataUri(_avatarDataUri!)
                            : null,
                        child: (_avatarDataUri == null || !_avatarDataUri!.startsWith('data:image'))
                            ? const Icon(Icons.groups, color: Colors.deepPurple, size: 40)
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: InkWell(
                          onTap: _pickAvatar,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _nameC,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).translate('group_name'),
                    prefixIcon: const Icon(Icons.edit_outlined),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text(AppLocalizations.of(context).tr('members', params: {'count': _members.length}),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _addMembers,
                      icon: const Icon(Icons.person_add, size: 18),
                      label: Text(AppLocalizations.of(context).translate('add')),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._members.map((m) => _memberTile(m as Map<String, dynamic>)),
              ],
            ),
    );
  }

  Widget _memberTile(Map<String, dynamic> m) {
    final isCreator = _group['creator_id']?.toString() == m['id'].toString();
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          backgroundImage: (m['avatar_url'] != null && m['avatar_url'].toString().startsWith('data:image'))
              ? _imageFromDataUri(m['avatar_url'])
              : null,
          child: (m['avatar_url'] == null || m['avatar_url'].toString().isEmpty)
              ? Text((m['display_name'] ?? '?').toString().isNotEmpty ? m['display_name'][0].toUpperCase() : '?',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))
              : null,
        ),
        title: Row(
          children: [
            Flexible(child: Text(m['display_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
            if (isCreator) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.deepPurple, borderRadius: BorderRadius.circular(6)),
                child: const Text('OWNER', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        subtitle: Text(m['email'] ?? '', style: const TextStyle(fontSize: 12)),
        trailing: isCreator
            ? null
            : IconButton(
                icon: const Icon(Icons.person_remove, color: AppColors.error),
                tooltip: AppLocalizations.of(context).translate('remove_from_group'),
                onPressed: () => _removeMember(m),
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
