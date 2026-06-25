import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_config.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/socket_service.dart';
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
  StreamSubscription? _messageSub;
  StreamSubscription? _deleteSub;
  StreamSubscription? _editSub;

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
    _messageSub = SocketService.instance.onMessage.listen((event) {
      _loadData();
    });
    _deleteSub = SocketService.instance.onDelete.listen((event) {
      _loadData();
    });
    _editSub = SocketService.instance.onEdit.listen((event) {
      _loadData();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final joinCode = args?['joinCode'] as String?;
      if (joinCode != null && joinCode.isNotEmpty) {
        Navigator.pushNamed(context, AppRoutes.joinGroup, arguments: {'code': joinCode});
      }
    });
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _deleteSub?.cancel();
    _editSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
            tooltip: AppLocalizations.of(context).translate('friends'),
            onPressed: () async {
              await Navigator.pushNamed(context, AppRoutes.friends);
              _loadData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              await Navigator.pushNamed(context, AppRoutes.profile);
              _loadData();
            },
          ),
        ],
      ),
      body: _buildChatList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.pushNamed(context, AppRoutes.createChat);
          _loadData();
        },
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
                title: Text(AppLocalizations.of(context).translate('delete_chat')),
                content: Text(AppLocalizations.of(context).translate('delete_chat_confirm')),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppLocalizations.of(context).translate('cancel'))),
                  TextButton(onPressed: () => Navigator.pop(context, true), child: Text(AppLocalizations.of(context).translate('delete'), style: const TextStyle(color: AppColors.error))),
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
    final authProvider = context.read<AuthProvider>();
    final myUid = authProvider.uid;

    String displayName = chatName;
    String avatarUrl = isGroup ? (chat['avatar_url']?.toString() ?? '') : '';

    if (otherUser != null) {
      if (displayName.isEmpty) {
        displayName = otherUser['display_name'] ?? 'Unknown';
      }
      avatarUrl = otherUser['avatar_url'] ?? '';
    }

    String subtitle = lastMessage;
    final senderUid = chat['last_message_sender_uid']?.toString() ?? '';
    final senderName = chat['last_message_sender_name']?.toString() ?? '';
    if (lastMessage.isNotEmpty) {
      String prefix;
      if (senderUid == myUid) {
        prefix = AppLocalizations.of(context).translate('you');
      } else if (isGroup) {
        prefix = senderName.isNotEmpty ? senderName : '???';
      } else {
        prefix = displayName;
      }
      subtitle = '$prefix: $lastMessage';
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
        subtitle,
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
      onTap: () async {
        await Navigator.pushNamed(
          context,
          AppRoutes.chatDetail,
          arguments: {
            'chatId': chatId,
            'chatName': displayName,
            'chatAvatar': avatarUrl,
            'isGroup': chat['is_group'] == true,
          },
        );
        _loadData();
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
