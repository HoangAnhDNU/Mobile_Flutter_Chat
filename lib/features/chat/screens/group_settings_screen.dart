import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_config.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/services/api_service.dart';
import '../../auth/providers/auth_provider.dart';

class GroupSettingsScreen extends StatefulWidget {
  final int chatId;
  
  const GroupSettingsScreen({
    super.key,
    required this.chatId,
  });

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  final _nameController = TextEditingController();

  int _chatId = 0;
  String _groupAvatar = '';
  String _adminId = '';
  bool _isEditing = false;
  bool _isLoading = true;
  bool _initialized = false;
  List<Map<String, dynamic>> _participants = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _chatId = args?['chatId'] ?? 0;
      _loadGroupInfo();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _isAdmin {
    final authProvider = context.read<AuthProvider>();
    return _adminId == authProvider.uid;
  }

  ImageProvider _getAvatarImage(String url) {
    if (url.startsWith('data:')) {
      final base64Str = url.split(',').last;
      return MemoryImage(base64Decode(base64Str));
    }
    return NetworkImage(AppConfig.resolveMediaUrl(url));
  }

  Future<void> _loadGroupInfo() async {
    setState(() => _isLoading = true);
    try {
      final info = await ApiService.getChatInfo(_chatId);
      setState(() {
        _nameController.text = info['chat_name'] ?? '';
        _groupAvatar = info['group_avatar'] ?? '';
        _adminId = info['created_by'] ?? '';
        _participants = List<Map<String, dynamic>>.from(info['participants'] ?? []);
      });
    } catch (e) {
      debugPrint('Error loading group info: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _updateGroupName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    await ApiService.updateGroup(_chatId, groupName: name);
    setState(() => _isEditing = false);
    await _loadGroupInfo();
  }

  Future<void> _changeGroupAvatar() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 30, maxWidth: 400);
    if (pickedFile == null) return;

    final file = File(pickedFile.path);
    final bytes = await file.readAsBytes();
    final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';

    await ApiService.updateGroup(_chatId, groupAvatar: base64Image);
    setState(() => _groupAvatar = base64Image);
  }

  Future<void> _removeMember(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa thành viên'),
        content: const Text('Bạn có chắc muốn xóa thành viên này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirm != true) return;
    await ApiService.removeParticipant(_chatId, userId);
    await _loadGroupInfo();
  }

  Future<void> _leaveGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rời nhóm'),
        content: const Text('Bạn có chắc muốn rời nhóm này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Rời nhóm', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirm != true) return;

    await ApiService.leaveGroup(_chatId);
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.chatList, (route) => false);
  }

  Future<void> _addMembers() async {
    final currentUids = _participants.map((p) => p['uid'] as String).toList();
    if (!mounted) return;

    final result = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => _AddMembersScreen(excludeIds: currentUids),
      ),
    );

    if (result != null && result.isNotEmpty) {
      for (final uid in result) {
        await ApiService.addParticipant(_chatId, uid);
      }
      await _loadGroupInfo();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt nhóm'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.check, color: AppColors.primary),
              onPressed: _updateGroupName,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _isAdmin ? _changeGroupAvatar : null,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    backgroundImage: _groupAvatar.isNotEmpty ? _getAvatarImage(_groupAvatar) : null,
                    child: _groupAvatar.isEmpty
                        ? const Icon(Icons.group, size: 50, color: AppColors.primary)
                        : null,
                  ),
                  if (_isAdmin)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              enabled: _isAdmin && _isEditing,
              decoration: InputDecoration(
                labelText: 'Tên nhóm',
                suffixIcon: _isAdmin
                    ? IconButton(
                        icon: Icon(_isEditing ? Icons.close : Icons.edit, size: 20),
                        onPressed: () => setState(() => _isEditing = !_isEditing),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Thành viên (${_participants.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                if (_isAdmin)
                  TextButton.icon(
                    onPressed: _addMembers,
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Thêm'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ..._participants.map((user) {
              final name = user['displayName'] ?? 'Unknown';
              final avatar = user['avatarUrl'] ?? '';
              final uid = user['uid'] ?? '';

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage: avatar.isNotEmpty ? _getAvatarImage(avatar) : null,
                  child: avatar.isEmpty ? Text(name[0].toUpperCase(), style: const TextStyle(color: AppColors.primary)) : null,
                ),
                title: Text(name),
                subtitle: uid == _adminId ? const Text('Admin', style: TextStyle(color: AppColors.primary, fontSize: 12)) : null,
                trailing: (_isAdmin && uid != authProvider.uid)
                    ? IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: AppColors.error),
                        onPressed: () => _removeMember(uid),
                      )
                    : null,
              );
            }),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _leaveGroup,
                icon: const Icon(Icons.exit_to_app, color: Colors.white),
                label: const Text('Rời nhóm'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddMembersScreen extends StatefulWidget {
  final List<String> excludeIds;
  const _AddMembersScreen({required this.excludeIds});

  @override
  State<_AddMembersScreen> createState() => _AddMembersScreenState();
}

class _AddMembersScreenState extends State<_AddMembersScreen> {
  final Set<String> _selected = {};
  List<dynamic> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await ApiService.getUsers();
      setState(() {
        _users = users.where((u) => !widget.excludeIds.contains(u['uid'])).toList();
      });
    } catch (e) {
      debugPrint('Error loading users: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm thành viên'),
        actions: [
          if (_selected.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.check, color: AppColors.primary),
              onPressed: () => Navigator.pop(context, _selected.toList()),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? const Center(child: Text('Không có người dùng để thêm'))
              : ListView.builder(
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index] as Map<String, dynamic>;
                    final uid = user['uid'] ?? '';
                    final name = user['displayName'] ?? 'Unknown';

                    return CheckboxListTile(
                      title: Text(name),
                      subtitle: Text(user['email'] ?? '', style: const TextStyle(fontSize: 12)),
                      value: _selected.contains(uid),
                      onChanged: (v) => setState(() => v == true ? _selected.add(uid) : _selected.remove(uid)),
                      activeColor: AppColors.primary,
                    );
                  },
                ),
    );
  }
}
