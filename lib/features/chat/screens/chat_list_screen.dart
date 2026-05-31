import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  int _currentTabIndex = 0;
  final _currentUser = FirebaseAuth.instance.currentUser;

  ImageProvider _getImageProvider(String url) {
    if (url.startsWith('data:image')) {
      final base64Str = url.split(',').last;
      return MemoryImage(base64Decode(base64Str));
    }
    return CachedNetworkImageProvider(url);
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
    if (_currentUser == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Lỗi: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Không có người dùng'));
        }

        final users = snapshot.data!.docs
            .where((doc) => doc.id != _currentUser!.uid)
            .toList();

        if (users.isEmpty) {
          return const Center(
            child: Text('Chưa có người dùng khác', style: TextStyle(color: AppColors.textSecondary)),
          );
        }

        return ListView.separated(
          itemCount: users.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
          itemBuilder: (context, index) {
            final user = users[index].data() as Map<String, dynamic>;
            final userId = users[index].id;
            final displayName = user['displayName'] ?? 'Unknown';
            final email = user['email'] ?? '';
            final avatarUrl = user['avatarUrl'] ?? '';
            final isOnline = user['isOnline'] ?? false;

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
      },
    );
  }

  Future<void> _startChatWithUser(String otherUserId, String otherUserName) async {
    final existingChat = await FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: _currentUser!.uid)
        .get();

    String? existingChatId;
    for (final doc in existingChat.docs) {
      final participants = List<String>.from(doc['participants'] ?? []);
      if (participants.contains(otherUserId) && participants.length == 2) {
        existingChatId = doc.id;
        break;
      }
    }

    if (existingChatId != null) {
      if (!mounted) return;
      Navigator.pushNamed(context, AppRoutes.chatDetail,
          arguments: {'chatId': existingChatId, 'chatName': otherUserName});
      return;
    }

    final chatDoc = await FirebaseFirestore.instance.collection('chats').add({
      'participants': [_currentUser!.uid, otherUserId],
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': _currentUser!.uid,
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'chatName': '',
    });

    if (!mounted) return;
    Navigator.pushNamed(context, AppRoutes.chatDetail,
        arguments: {'chatId': chatDoc.id, 'chatName': otherUserName});
  }

  Widget _buildChatList() {
    if (_currentUser == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: _currentUser!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: 12),
                Text(
                  'Lỗi tải dữ liệu: ${snapshot.error}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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

        final chats = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final aTime = (a.data() as Map<String, dynamic>)['lastMessageTime'] as Timestamp?;
            final bTime = (b.data() as Map<String, dynamic>)['lastMessageTime'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });
        return ListView.separated(
          itemCount: chats.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
          itemBuilder: (context, index) {
            final chat = chats[index].data() as Map<String, dynamic>;
            final chatId = chats[index].id;
            return Dismissible(
              key: Key(chatId),
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
              onDismissed: (_) {
                FirebaseFirestore.instance.collection('chats').doc(chatId).delete();
              },
              child: _buildChatItem(chatId, chat),
            );
          },
        );
      },
    );
  }

  Widget _buildChatItem(String chatId, Map<String, dynamic> chat) {
    final participants = List<String>.from(chat['participants'] ?? []);
    final otherUserId = participants.firstWhere(
      (id) => id != _currentUser!.uid,
      orElse: () => '',
    );
    final lastMessage = chat['lastMessage'] ?? '';
    final lastMessageTime = chat['lastMessageTime'] as Timestamp?;
    final chatName = chat['chatName'] ?? '';

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
      builder: (context, userSnapshot) {
        String displayName = chatName;
        String avatarUrl = '';

        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          if (displayName.isEmpty) {
            displayName = userData['displayName'] ?? 'Unknown';
          }
          avatarUrl = userData['avatarUrl'] ?? '';
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
                  _formatTime(lastMessageTime.toDate()),
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
