import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../widgets/message_bubble.dart';

class ChatDetailScreen extends StatefulWidget {
  const ChatDetailScreen({super.key});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _currentUser = FirebaseAuth.instance.currentUser;
  final _firestore = FirebaseFirestore.instance;

  String? _editingMessageId;
  bool _isEditing = false;

  late String _chatId;
  late String _chatName;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _chatId = args?['chatId'] ?? '';
    _chatName = args?['chatName'] ?? 'Chat';
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    await _firestore.collection('chats').doc(_chatId).collection('messages').add({
      'text': text,
      'senderId': _currentUser!.uid,
      'senderName': _currentUser!.displayName ?? 'Unknown',
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text',
      'isEdited': false,
    });

    await _firestore.collection('chats').doc(_chatId).update({
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
    });
  }

  bool _isSendingImage = false;

  Future<void> _sendImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 30, maxWidth: 800);
    if (pickedFile == null) return;

    setState(() => _isSendingImage = true);

    try {
      final file = File(pickedFile.path);
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      await _firestore.collection('chats').doc(_chatId).collection('messages').add({
        'text': '',
        'senderId': _currentUser!.uid,
        'senderName': _currentUser!.displayName ?? 'Unknown',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'image',
        'imageBase64': base64Image,
        'isEdited': false,
      });

      await _firestore.collection('chats').doc(_chatId).update({
        'lastMessage': '🖼️ Ảnh',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gửi ảnh thất bại: ${e.toString().length > 80 ? e.toString().substring(0, 80) : e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSendingImage = false);
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('Chọn từ thư viện'),
              onTap: () {
                Navigator.pop(context);
                _sendImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text('Chụp ảnh'),
              onTap: () {
                Navigator.pop(context);
                _sendImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _editingMessageId == null) return;

    _messageController.clear();

    await _firestore
        .collection('chats')
        .doc(_chatId)
        .collection('messages')
        .doc(_editingMessageId)
        .update({
      'text': text,
      'isEdited': true,
      'editedAt': FieldValue.serverTimestamp(),
    });

    setState(() {
      _isEditing = false;
      _editingMessageId = null;
    });
  }

  Future<void> _deleteMessage(String messageId) async {
    await _firestore
        .collection('chats')
        .doc(_chatId)
        .collection('messages')
        .doc(messageId)
        .delete();

    final lastMsg = await _firestore
        .collection('chats')
        .doc(_chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (lastMsg.docs.isNotEmpty) {
      final data = lastMsg.docs.first.data();
      await _firestore.collection('chats').doc(_chatId).update({
        'lastMessage': data['text'] ?? '',
        'lastMessageTime': data['timestamp'],
      });
    } else {
      await _firestore.collection('chats').doc(_chatId).update({
        'lastMessage': '',
        'lastMessageTime': null,
      });
    }
  }

  void _showMessageOptions(String messageId, String text, String senderId) {
    final isMyMessage = senderId == _currentUser!.uid;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMyMessage)
              ListTile(
                leading: const Icon(Icons.edit, color: AppColors.primary),
                title: const Text('Chỉnh sửa'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _isEditing = true;
                    _editingMessageId = messageId;
                    _messageController.text = text;
                  });
                },
              ),
            if (isMyMessage)
              ListTile(
                leading: const Icon(Icons.delete, color: AppColors.error),
                title: const Text('Xóa tin nhắn'),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirm(messageId);
                },
              ),
            ListTile(
              leading: const Icon(Icons.copy, color: AppColors.textSecondary),
              title: const Text('Sao chép'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: text));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã sao chép'), duration: Duration(seconds: 1)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirm(String messageId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa tin nhắn'),
        content: const Text('Bạn có chắc muốn xóa tin nhắn này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMessage(messageId);
            },
            child: const Text('Xóa', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _updateTypingStatus(bool isTyping) {
    _firestore.collection('chats').doc(_chatId).update({
      'typingUser': isTyping ? _currentUser!.uid : '',
    });
  }

  void _showClearChatConfirm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa lịch sử chat'),
        content: const Text('Tất cả tin nhắn sẽ bị xóa. Bạn có chắc?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final messages = await _firestore
                  .collection('chats')
                  .doc(_chatId)
                  .collection('messages')
                  .get();
              for (final doc in messages.docs) {
                await doc.reference.delete();
              }
              await _firestore.collection('chats').doc(_chatId).update({
                'lastMessage': '',
                'lastMessageTime': null,
              });
            },
            child: const Text('Xóa', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _editingMessageId = null;
      _messageController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(
                _chatName.isNotEmpty ? _chatName[0].toUpperCase() : '?',
                style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _chatName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  StreamBuilder<DocumentSnapshot>(
                    stream: _firestore.collection('chats').doc(_chatId).snapshots(),
                    builder: (context, snap) {
                      if (snap.hasData && snap.data!.exists) {
                        final data = snap.data!.data() as Map<String, dynamic>;
                        final typingUser = data['typingUser'] ?? '';
                        if (typingUser.isNotEmpty && typingUser != _currentUser!.uid) {
                          return const Text('đang nhập...', style: TextStyle(fontSize: 12, color: AppColors.primary, fontStyle: FontStyle.italic));
                        }
                      }
                      return const Text('Online', style: TextStyle(fontSize: 12, color: AppColors.success));
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_outlined),
            onPressed: () {},
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'group_settings':
                  Navigator.pushNamed(context, '/group-settings', arguments: {'chatId': _chatId});
                  break;
                case 'clear_chat':
                  _showClearChatConfirm();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'group_settings', child: Text('Cài đặt nhóm')),
              const PopupMenuItem(value: 'clear_chat', child: Text('Xóa lịch sử chat')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'Hãy gửi tin nhắn đầu tiên!',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        final messages = snapshot.data!.docs;
        return ListView.builder(
          controller: _scrollController,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final msg = messages[index].data() as Map<String, dynamic>;
            final messageId = messages[index].id;
            final isMe = msg['senderId'] == _currentUser!.uid;

            return MessageBubble(
              text: msg['text'] ?? '',
              isMe: isMe,
              senderName: msg['senderName'] ?? '',
              timestamp: msg['timestamp'] as Timestamp?,
              isEdited: msg['isEdited'] ?? false,
              type: msg['type'] ?? 'text',
              imageUrl: msg['imageUrl'],
              imageBase64: msg['imageBase64'],
              onLongPress: () => _showMessageOptions(
                messageId,
                msg['text'] ?? '',
                msg['senderId'] ?? '',
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_isEditing)
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.error),
                onPressed: _cancelEditing,
              )
            else
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                onPressed: _showImageSourcePicker,
              ),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: _isEditing ? 'Chỉnh sửa tin nhắn...' : 'Message...',
                  border: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: null,
                onChanged: (value) => _updateTypingStatus(value.trim().isNotEmpty),
              ),
            ),
            IconButton(
              icon: Icon(
                _isEditing ? Icons.check_circle : Icons.send,
                color: AppColors.primary,
              ),
              onPressed: _isEditing ? _updateMessage : _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}
