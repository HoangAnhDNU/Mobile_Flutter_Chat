import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_config.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/app_localizations.dart';
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
  Map<String, dynamic>? _inviteLink;
  bool _loadingInvite = false;

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
      if (!mounted) return;
      debugPrint('[GroupSettings] getChatInfo response: $info');
      debugPrint('[GroupSettings] created_by type: ${info['created_by']?.runtimeType}, value: ${info['created_by']}');
      debugPrint('[GroupSettings] current user uid: ${context.read<AuthProvider>().uid}');
      setState(() {
        _nameController.text = info['chat_name'] ?? '';
        _groupAvatar = info['group_avatar'] ?? '';
        _adminId = info['created_by']?.toString() ?? '';
        _participants = List<Map<String, dynamic>>.from(info['participants'] ?? []);
      });
      debugPrint('[GroupSettings] _adminId set to: $_adminId, _isAdmin: $_isAdmin');
      await _loadInviteLink();
    } catch (e) {
      debugPrint('Error loading group info: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadInviteLink() async {
    setState(() => _loadingInvite = true);
    try {
      final invite = await ApiService.getInviteLink(_chatId);
      if (mounted) setState(() => _inviteLink = invite);
    } catch (e) {
      debugPrint('Error loading invite link: $e');
    }
    if (mounted) setState(() => _loadingInvite = false);
  }

  Future<void> _createInviteLink() async {
    try {
      final invite = await ApiService.createInviteLink(_chatId);
      if (mounted) setState(() => _inviteLink = invite);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).tr('create_link_failed', params: {'error': e}))),
      );
    }
  }

  Future<void> _revokeInviteLink() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).translate('disable_link')),
        content: Text(AppLocalizations.of(context).translate('disable_link_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(context).translate('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppLocalizations.of(context).translate('confirm'), style: const TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.revokeInviteLink(_chatId);
      if (mounted) setState(() => _inviteLink = null);
      await _createInviteLink();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).tr('revoke_link_failed', params: {'error': e}))),
      );
    }
  }

  void _shareInviteLink() {
    if (_inviteLink == null) return;
    final code = _inviteLink!['code']?.toString() ?? '';
    if (code.isEmpty) return;
    final link = '${AppConfig.baseOrigin}/#/join-group?code=$code';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).translate('invite_link')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(link, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).translate('share_link_desc'),
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: link));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppLocalizations.of(context).translate('link_copied'))),
              );
            },
            child: Text(AppLocalizations.of(context).translate('copy')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final auth = context.read<AuthProvider>();
                await ApiService.sendMessage(
                  chatId: _chatId,
                  senderUid: auth.uid!,
                  senderName: auth.displayName ?? '',
                  text: link,
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(context).translate('link_sent'))),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(context).tr('send_link_failed', params: {'error': e}))),
                );
              }
            },
            child: Text(AppLocalizations.of(context).translate('send_link_to_chat')),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context).translate('close'))),
        ],
      ),
    );
  }

  Future<void> _updateGroupName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final result = await ApiService.updateGroup(_chatId, groupName: name);
    if (!mounted) return;
    if (result.containsKey('error')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error'].toString())),
      );
      return;
    }
    await _loadGroupInfo();
    setState(() => _isEditing = false);
  }

  Future<void> _changeGroupAvatar() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 30, maxWidth: 400);
    if (pickedFile == null) return;

    final file = File(pickedFile.path);
    final bytes = await file.readAsBytes();
    final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';

    final result = await ApiService.updateGroup(_chatId, groupAvatar: base64Image);
    if (!mounted) return;
    if (result.containsKey('error')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error'].toString())),
      );
      return;
    }
    setState(() => _groupAvatar = base64Image);
  }

  Future<void> _removeMember(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).translate('remove_member')),
        content: Text(AppLocalizations.of(context).translate('remove_member_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(context).translate('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppLocalizations.of(context).translate('delete'), style: const TextStyle(color: AppColors.error))),
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
        title: Text(AppLocalizations.of(context).translate('leave_group')),
        content: Text(AppLocalizations.of(context).translate('leave_group_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(context).translate('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppLocalizations.of(context).translate('leave_group'), style: const TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirm != true) return;

    await ApiService.leaveGroup(_chatId);
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.chatList, (route) => false);
  }

  Future<void> _deleteGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).translate('delete_group')),
        content: Text(AppLocalizations.of(context).translate('delete_group_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(context).translate('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppLocalizations.of(context).translate('delete_group'), style: const TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ApiService.deleteChat(_chatId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).translate('group_deleted'))),
      );
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.chatList, (route) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).tr('delete_group_failed', params: {'error': e}))),
      );
    }
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
        title: Text(AppLocalizations.of(context).translate('group_settings')),
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
                labelText: AppLocalizations.of(context).translate('group_name'),
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
                Text(AppLocalizations.of(context).tr('members', params: {'count': _participants.length}), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                if (_isAdmin)
                  TextButton.icon(
                    onPressed: _addMembers,
                    icon: const Icon(Icons.person_add, size: 18),
                    label: Text(AppLocalizations.of(context).translate('add')),
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
                subtitle: uid == _adminId ? Text(AppLocalizations.of(context).translate('admin'), style: const TextStyle(color: AppColors.primary, fontSize: 12)) : null,
                trailing: (_isAdmin && uid != authProvider.uid)
                    ? IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: AppColors.error),
                        onPressed: () => _removeMember(uid),
                      )
                    : null,
              );
            }),
            const SizedBox(height: 24),
            // Invite link section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.link, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(AppLocalizations.of(context).translate('invite_link'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_loadingInvite)
                      const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
                    else if (_inviteLink != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Code: ${_inviteLink!['code'] ?? ''}',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _shareInviteLink,
                                  icon: const Icon(Icons.share, size: 18),
                                  label: Text(AppLocalizations.of(context).translate('view_link')),
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                                ),
                              ),
                              if (_isAdmin) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.refresh, color: AppColors.error),
                                  tooltip: AppLocalizations.of(context).translate('create_new_link'),
                                  onPressed: _revokeInviteLink,
                                ),
                              ],
                            ],
                          ),
                        ],
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: _isAdmin ? _createInviteLink : null,
                        icon: const Icon(Icons.add_link, size: 18),
                        label: Text(AppLocalizations.of(context).translate('create_invite_link')),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_isAdmin)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _deleteGroup,
                  icon: const Icon(Icons.delete_forever, color: Colors.white),
                  label: Text(AppLocalizations.of(context).translate('delete_group')),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _leaveGroup,
                  icon: const Icon(Icons.exit_to_app, color: Colors.white),
                  label: Text(AppLocalizations.of(context).translate('leave_group')),
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
      // Chỉ lấy danh sách bạn bè — thêm thành viên chỉ được thêm người đã kết bạn
      final friends = await ApiService.getFriends();
      setState(() {
        _users = friends.where((u) => !widget.excludeIds.contains(u['uid'])).toList();
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
        title: Text(AppLocalizations.of(context).translate('add_members')),
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
              ? Center(child: Text(AppLocalizations.of(context).translate('no_users_to_add')))
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
