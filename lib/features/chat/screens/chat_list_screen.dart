import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_config.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/time_utils.dart';
import '../../../core/utils/app_localizations.dart';
import '../../auth/providers/auth_provider.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<dynamic> _chats = [];
  bool _isLoading = false;

  ImageProvider _getImageProvider(String url) {
    final resolvedUrl = AppConfig.resolveMediaUrl(url);
    if (resolvedUrl.startsWith('data:image')) {
      final base64Str = resolvedUrl.split(',').last;
      return MemoryImage(base64Decode(base64Str));
    }
    return CachedNetworkImageProvider(resolvedUrl);
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
          child: Consumer<AuthProvider>(
            builder: (context, auth, _) => CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              backgroundImage: (auth.avatarUrl != null && auth.avatarUrl!.isNotEmpty)
                  ? _getImageProvider(auth.avatarUrl!)
                  : null,
              child: (auth.avatarUrl == null || auth.avatarUrl!.isEmpty)
                  ? const Icon(Icons.person, color: AppColors.primary, size: 20)
                  : null,
            ),
          ),
        ),
        title: Text(
          AppLocalizations.of(context).translate('chats'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.people_alt_outlined),
            tooltip: 'Bạn bè',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.friends),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.profile),
          ),
        ],
      ),
      body: _buildChatList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.createChat),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.edit_square, color: Colors.white),
      ),
    );
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
            Text(
              AppLocalizations.of(context).translate('no_chats'),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).translate('start_chat'),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
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
    final isGroup = chat['is_group'] == true;
    final otherUser = chat['otherUser'] as Map<String, dynamic>?;

    String displayName = chatName;
    // Với nhóm: dùng avatar của nhóm. Với chat 1-1: dùng avatar đối phương.
    String avatarUrl = isGroup ? (chat['avatar_url']?.toString() ?? '') : '';

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
          arguments: {
            'chatId': chatId,
            'chatName': displayName,
            'chatAvatar': avatarUrl,
            'isGroup': chat['is_group'] == true,
          },
        );
      },
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = TimeUtils.toBangkokTime(DateTime.now());
    final localDateTime = TimeUtils.toBangkokTime(dateTime);
    final diff = now.difference(localDateTime);

    if (diff.inDays == 0) {
      return TimeUtils.formatTime(dateTime);
    } else if (diff.inDays == 1) {
      return 'Hôm qua';
    } else if (diff.inDays < 7) {
      const days = ['Thứ hai', 'Thứ ba', 'Thứ tư', 'Thứ năm', 'Thứ sáu', 'Thứ bảy', 'Chủ nhật'];
      return days[localDateTime.weekday - 1];
    } else {
      return TimeUtils.formatDateShort(dateTime);
    }
  }
}
