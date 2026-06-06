import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/services/api_service.dart';
import '../../auth/providers/auth_provider.dart';

class CreateChatScreen extends StatefulWidget {
  const CreateChatScreen({super.key});

  @override
  State<CreateChatScreen> createState() => _CreateChatScreenState();
}

class _CreateChatScreenState extends State<CreateChatScreen> {
  final _searchController = TextEditingController();
  List<dynamic> _users = [];
  bool _isLoading = false;
  String _searchQuery = '';
  bool _isGroupMode = false;
  final Set<String> _selectedUserIds = {};
  final Map<String, String> _selectedUserNames = {};

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      _users = await ApiService.getUsers();
    } catch (e) {
      debugPrint('Error loading users: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _createChat(String otherUserId, String otherUserName) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.uid == null) return;

    final result = await ApiService.createChat(
      participants: [authProvider.uid!, otherUserId],
      createdBy: authProvider.uid!,
    );

    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.chatDetail,
      arguments: {'chatId': result['chatId'], 'chatName': otherUserName},
    );
  }

  Future<void> _createGroup() async {
    if (_selectedUserIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chọn ít nhất 2 người để tạo nhóm')),
      );
      return;
    }

    final groupNameController = TextEditingController();
    final groupName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tạo nhóm'),
        content: TextField(
          controller: groupNameController,
          decoration: const InputDecoration(hintText: 'Tên nhóm'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(context, groupNameController.text.trim()),
            child: const Text('Tạo'),
          ),
        ],
      ),
    );

    if (groupName == null || groupName.isEmpty) return;
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    if (authProvider.uid == null) return;

    final participants = [authProvider.uid!, ..._selectedUserIds];
    final result = await ApiService.createChat(
      participants: participants,
      createdBy: authProvider.uid!,
      chatName: groupName,
    );

    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.chatDetail,
      arguments: {'chatId': result['chatId'], 'chatName': groupName},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isGroupMode ? 'Tạo nhóm (${_selectedUserIds.length})' : 'Chat mới'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_isGroupMode) {
              setState(() {
                _isGroupMode = false;
                _selectedUserIds.clear();
                _selectedUserNames.clear();
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          if (!_isGroupMode)
            TextButton(
              onPressed: () => setState(() => _isGroupMode = true),
              child: const Text('Tạo nhóm'),
            ),
          if (_isGroupMode && _selectedUserIds.length >= 2)
            IconButton(
              icon: const Icon(Icons.check, color: AppColors.primary),
              onPressed: _createGroup,
            ),
        ],
      ),
      body: Column(
        children: [
          if (_isGroupMode && _selectedUserNames.isNotEmpty)
            SizedBox(
              height: 80,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: _selectedUserNames.entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              child: Text(e.value[0].toUpperCase(), style: const TextStyle(color: AppColors.primary)),
                            ),
                            Positioned(
                              top: -2,
                              right: -2,
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _selectedUserIds.remove(e.key);
                                  _selectedUserNames.remove(e.key);
                                }),
                                child: const CircleAvatar(
                                  radius: 10,
                                  backgroundColor: AppColors.error,
                                  child: Icon(Icons.close, size: 12, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 50,
                          child: Text(e.value, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm theo tên hoặc email...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppColors.inputFill,
              ),
              onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
            ),
          ),
          Expanded(child: _buildUserList()),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_users.isEmpty) {
      return const Center(child: Text('Không tìm thấy người dùng'));
    }

    final authProvider = context.read<AuthProvider>();
    final filteredUsers = _users.where((user) {
      final userData = user as Map<String, dynamic>;
      if (userData['uid'] == authProvider.uid) return false;

      if (_searchQuery.isNotEmpty) {
        final name = (userData['display_name'] ?? '').toString().toLowerCase();
        final email = (userData['email'] ?? '').toString().toLowerCase();
        return name.contains(_searchQuery) || email.contains(_searchQuery);
      }
      return true;
    }).toList();

    if (filteredUsers.isEmpty) {
      return const Center(child: Text('Không tìm thấy người dùng'));
    }

    return ListView.separated(
      itemCount: filteredUsers.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final user = filteredUsers[index] as Map<String, dynamic>;
        final userId = user['uid'] as String;
        final displayName = user['display_name'] ?? 'Unknown';
        final email = user['email'] ?? '';
        final avatarUrl = user['avatar_url'] ?? '';

        return ListTile(
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
            child: avatarUrl.isEmpty
                ? Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          trailing: _isGroupMode
              ? Checkbox(
                  value: _selectedUserIds.contains(userId),
                  onChanged: (checked) => setState(() {
                    if (checked == true) {
                      _selectedUserIds.add(userId);
                      _selectedUserNames[userId] = displayName;
                    } else {
                      _selectedUserIds.remove(userId);
                      _selectedUserNames.remove(userId);
                    }
                  }),
                  activeColor: AppColors.primary,
                )
              : null,
          onTap: _isGroupMode
              ? () => setState(() {
                    if (_selectedUserIds.contains(userId)) {
                      _selectedUserIds.remove(userId);
                      _selectedUserNames.remove(userId);
                    } else {
                      _selectedUserIds.add(userId);
                      _selectedUserNames[userId] = displayName;
                    }
                  })
              : () => _createChat(userId, displayName),
        );
      },
    );
  }
}
