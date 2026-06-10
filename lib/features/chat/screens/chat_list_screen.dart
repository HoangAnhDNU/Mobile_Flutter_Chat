import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/services/api_service.dart';
import '../../auth/providers/auth_provider.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  int _currentTabIndex = 0;
  List<dynamic> _chats = [];
  List<dynamic> _users = [];
  bool _isLoading = false;

  ImageProvider _getImageProvider(String url) {
    if (url.startsWith('data:image')) {
      final base64Str = url.split(',').last;
      return MemoryImage(base64Decode(base64Str));
    }
    return CachedNetworkImageProvider(url);
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.uid != null) {
        _chats = await ApiService.getChats();
        _users = await ApiService.getUsers();
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: const Icon(Icons.person, color: AppColors.primary, size: 20),
          ),
        ),
        title: const Text(
          'Messages',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.profile),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.createChat),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.edit_square, color: Colors.white),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (index) => setState(() => _currentTabIndex = index),
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'Chats'),
          BottomNavigationBarItem(icon: Icon(Icons.call), label: 'Calls'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'People'),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentTabIndex) {
      case 0:
        return _buildChatList();
      case 1:
        return const Center(child: Text('Calls - Tùy chọn'));
      case 2:
        return _buildPeopleList();
      default:
        return _buildChatList();
    }
  }

  Widget _buildPeopleList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_users.isEmpty) {
      return const Center(child: Text('Không có người dùng'));
    }

    return ListView.separated(
      itemCount: _users.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final user = _users[index] as Map<String, dynamic>;
        final userId = user['uid'] as String;
        final displayName = user['display_name'] ?? 'Unknown';
        final email = user['email'] ?? '';
        final avatarUrl = user['avatar_url'] ?? '';
        final isOnline = (user['is_online'] == 1 || user['is_online'] == true);

        return ListTile(
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                backgroundImage: avatarUrl.isNotEmpty ? _getImageProvider(avatarUrl) : null,
                child: avatarUrl.isEmpty
                    ? Text(
                        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isOnline ? AppColors.success : AppColors.textSecondary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                  ),
                ),
              ),
            ],
          ),
          title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          trailing: Text(
            isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 12,
              color: isOnline ? AppColors.success : AppColors.textSecondary,
            ),
          ),
          onTap: () => _startChatWithUser(userId, displayName),
        );
      },
    );
  }

  Future<void> _startChatWithUser(String otherUserId, String otherUserName) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.uid == null) return;

    final result = await ApiService.createChat(
      participants: [authProvider.uid!, otherUserId],
      createdBy: authProvider.uid!,
    );

    if (!mounted) return;
    Navigator.pushNamed(context, AppRoutes.chatDetail,
        arguments: {'chatId': result['chatId'], 'chatName': otherUserName});
    
    await _loadData();
  }

  Widget _buildChatList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_chats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text(
              'Chưa có cuộc trò chuyện nào',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bấm + để bắt đầu chat',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _chats.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final chat = _chats[index] as Map<String, dynamic>;
        final chatId = chat['id'] as int;
        return Dismissible(
          key: Key(chatId.toString()),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: AppColors.error,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Xóa cuộc trò chuyện'),
                content: const Text('Bạn có chắc muốn xóa?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa', style: TextStyle(color: AppColors.error))),
                ],
              ),
            ) ?? false;
          },
          onDismissed: (_) async {
            await ApiService.deleteChat(chatId);
            await _loadData();
          },
          child: _buildChatItem(chat),
        );
      },
    );
  }

  Widget _buildChatItem(Map<String, dynamic> chat) {
    final chatId = chat['id'] as int;
    final lastMessage = chat['last_message'] ?? '';
    final lastMessageTime = chat['last_message_time'];
    final chatName = chat['chat_name'] ?? '';
    final otherUser = chat['otherUser'] as Map<String, dynamic>?;

    String displayName = chatName;
    String avatarUrl = '';

    if (otherUser != null) {
      if (displayName.isEmpty) {
        displayName = otherUser['display_name'] ?? 'Unknown';
      }
      avatarUrl = otherUser['avatar_url'] ?? '';
    }

    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
        backgroundImage: avatarUrl.isNotEmpty ? _getImageProvider(avatarUrl) : null,
        child: avatarUrl.isEmpty
            ? Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
              )
            : null,
      ),
      title: Text(
        displayName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
      trailing: lastMessageTime != null
          ? Text(
              _formatTime(DateTime.parse(lastMessageTime)),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            )
          : null,
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.chatDetail,
          arguments: {'chatId': chatId, 'chatName': displayName},
        );
      },
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inDays == 0) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dateTime.weekday - 1];
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }
}
