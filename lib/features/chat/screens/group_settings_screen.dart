import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';

class GroupSettingsScreen extends StatefulWidget {
  const GroupSettingsScreen({super.key});

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _currentUser = FirebaseAuth.instance.currentUser;
  final _nameController = TextEditingController();

  late String _chatId;
  String _groupAvatar = '';
  String _adminId = '';
  bool _isEditing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _chatId = args?['chatId'] ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _isAdmin => _adminId == _currentUser?.uid;

  Future<void> _updateGroupName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    await _firestore.collection('chats').doc(_chatId).update({
      'groupName': name,
      'chatName': name,
    });
    setState(() => _isEditing = false);
  }

  Future<void> _changeGroupAvatar() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile == null) return;

    final file = File(pickedFile.path);
    final ref = FirebaseStorage.instance.ref().child('group_avatars/$_chatId.jpg');
    await ref.putFile(file);
    final url = await ref.getDownloadURL();

    await _firestore.collection('chats').doc(_chatId).update({'groupAvatar': url});
    setState(() => _groupAvatar = url);
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
    await _firestore.collection('chats').doc(_chatId).update({
      'participants': FieldValue.arrayRemove([userId]),
    });
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

    final chatDoc = await _firestore.collection('chats').doc(_chatId).get();
    final participants = List<String>.from(chatDoc['participants'] ?? []);

    await _firestore.collection('chats').doc(_chatId).update({
      'participants': FieldValue.arrayRemove([_currentUser!.uid]),
    });

    if (_isAdmin && participants.length > 1) {
      final nextAdmin = participants.firstWhere((id) => id != _currentUser!.uid, orElse: () => '');
      if (nextAdmin.isNotEmpty) {
        await _firestore.collection('chats').doc(_chatId).update({'adminId': nextAdmin});
      }
    }

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.chatList, (route) => false);
  }

  Future<void> _addMembers() async {
    final chatDoc = await _firestore.collection('chats').doc(_chatId).get();
    final currentParticipants = List<String>.from(chatDoc['participants'] ?? []);

    if (!mounted) return;

    final result = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => _AddMembersScreen(excludeIds: currentParticipants),
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _firestore.collection('chats').doc(_chatId).update({
        'participants': FieldValue.arrayUnion(result),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('chats').doc(_chatId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final chat = snapshot.data!.data() as Map<String, dynamic>;
        _adminId = chat['adminId'] ?? '';
        _groupAvatar = chat['groupAvatar'] ?? '';
        if (!_isEditing) {
          _nameController.text = chat['groupName'] ?? '';
        }

        final participants = List<String>.from(chat['participants'] ?? []);

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
                        backgroundImage: _groupAvatar.isNotEmpty ? NetworkImage(_groupAvatar) : null,
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
                    Text('Thành viên (${participants.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    if (_isAdmin)
                      TextButton.icon(
                        onPressed: _addMembers,
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('Thêm'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                ...participants.map((uid) => FutureBuilder<DocumentSnapshot>(
                  future: _firestore.collection('users').doc(uid).get(),
                  builder: (context, userSnap) {
                    if (!userSnap.hasData) return const SizedBox.shrink();
                    final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
                    final name = userData['displayName'] ?? 'Unknown';
                    final avatar = userData['avatarUrl'] ?? '';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                        child: avatar.isEmpty ? Text(name[0].toUpperCase(), style: const TextStyle(color: AppColors.primary)) : null,
                      ),
                      title: Text(name),
                      subtitle: uid == _adminId ? const Text('Admin', style: TextStyle(color: AppColors.primary, fontSize: 12)) : null,
                      trailing: (_isAdmin && uid != _currentUser!.uid)
                          ? IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: AppColors.error),
                              onPressed: () => _removeMember(uid),
                            )
                          : null,
                    );
                  },
                )),
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
      },
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final users = snapshot.data!.docs.where((d) => !widget.excludeIds.contains(d.id)).toList();
          if (users.isEmpty) return const Center(child: Text('Không có người dùng để thêm'));

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index].data() as Map<String, dynamic>;
              final uid = users[index].id;
              final name = user['displayName'] ?? 'Unknown';

              return CheckboxListTile(
                title: Text(name),
                subtitle: Text(user['email'] ?? '', style: const TextStyle(fontSize: 12)),
                value: _selected.contains(uid),
                onChanged: (v) => setState(() => v == true ? _selected.add(uid) : _selected.remove(uid)),
                activeColor: AppColors.primary,
              );
            },
          );
        },
      ),
    );
  }
}
