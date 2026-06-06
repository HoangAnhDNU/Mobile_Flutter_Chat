import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../widgets/message_bubble.dart';

class ChatDetailScreen extends StatefulWidget {
  const ChatDetailScreen({super.key});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _messageController = TextEditingController();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  List<dynamic> _messages = [];
  bool _isLoading = false;
  bool _isSearching = false;

  String? _editingMessageId;
  bool _isEditing = false;

  // Reply state
  Map<String, dynamic>? _replyingTo;

  late int _chatId;
  late String _chatName;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _chatId = args?['chatId'] ?? 0;
      _chatName = args?['chatName'] ?? 'Chat';
      _loadMessages();
    }
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      _messages = await ApiService.getMessages(_chatId);
    } catch (e) {
      debugPrint('Error loading messages: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.uid == null) return;

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    if (_replyingTo != null) {
      await ApiService.sendReplyMessage(
        chatId: _chatId,
        senderUid: authProvider.uid!,
        senderName: authProvider.displayName ?? 'Unknown',
        text: text,
        replyToId: _replyingTo!['id'],
        replyToText: _replyingTo!['text'] ?? '',
        replyToSender: _replyingTo!['sender_name'] ?? '',
      );
      setState(() => _replyingTo = null);
    } else {
      await ApiService.sendMessage(
        chatId: _chatId,
        senderUid: authProvider.uid!,
        senderName: authProvider.displayName ?? 'Unknown',
        text: text,
        messageType: 'text',
      );
    }

    await _loadMessages();
  }

  Future<void> _searchMessages(String query) async {
    if (query.isEmpty) {
      await _loadMessages();
      return;
    }
    try {
      _messages = await ApiService.searchMessages(_chatId, query);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Search error: $e');
    }
  }

  void _setReply(Map<String, dynamic> message) {
    setState(() => _replyingTo = message);
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
  }

  Future<void> _sendImage(ImageSource source) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.uid == null) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 30, maxWidth: 800);
    if (pickedFile == null) return;

    try {
      final file = File(pickedFile.path);
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      await ApiService.sendMessage(
        chatId: _chatId,
        senderUid: authProvider.uid!,
        senderName: authProvider.displayName ?? 'Unknown',
        text: '',
        messageType: 'image',
        imageBase64: base64Image,
      );

      await _loadMessages();
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
      // image send complete
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

    await ApiService.updateMessage(int.parse(_editingMessageId!), text);

    setState(() {
      _isEditing = false;
      _editingMessageId = null;
    });

    await _loadMessages();
  }


  void _showMessageOptions(Map<String, dynamic> msg) {
    final authProvider = context.read<AuthProvider>();
    final messageId = msg['id'].toString();
    final text = msg['text'] ?? '';
    final senderId = msg['sender_uid'] ?? '';
    final isMyMessage = senderId == authProvider.uid;
    final isPinned = msg['is_pinned'] == true || msg['is_pinned'] == 1;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply, color: AppColors.primary),
              title: const Text('Trả lời'),
              onTap: () {
                Navigator.pop(context);
                _setReply(msg);
              },
            ),
            ListTile(
              leading: const Icon(Icons.emoji_emotions_outlined, color: Colors.orange),
              title: const Text('Thả cảm xúc'),
              onTap: () {
                Navigator.pop(context);
                _showReactionPicker(int.parse(messageId));
              },
            ),
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
            ListTile(
              leading: Icon(Icons.push_pin, color: isPinned ? AppColors.error : AppColors.primary),
              title: Text(isPinned ? 'Bỏ ghim' : 'Ghim tin nhắn'),
              onTap: () {
                Navigator.pop(context);
                ApiService.pinMessage(int.parse(messageId), !isPinned).then((_) => _loadMessages());
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
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.textSecondary),
              title: const Text('Xóa cho mình'),
              onTap: () {
                Navigator.pop(context);
                ApiService.deleteForMe(int.parse(messageId)).then((_) => _loadMessages());
              },
            ),
            if (isMyMessage)
              ListTile(
                leading: const Icon(Icons.delete_forever, color: AppColors.error),
                title: const Text('Xóa cho tất cả'),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteForEveryoneConfirm(messageId);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showDeleteForEveryoneConfirm(String messageId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa cho tất cả'),
        content: const Text('Tin nhắn sẽ bị xóa cho tất cả mọi người.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ApiService.deleteForEveryone(int.parse(messageId)).then((_) => _loadMessages());
            },
            child: const Text('Xóa', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showReactionPicker(int messageId) {
    final emojis = ['❤️', '😂', '😮', '😢', '😡', '👍'];
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: emojis.map((emoji) {
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  ApiService.addReaction(messageId, emoji).then((_) => _loadMessages());
                },
                child: Text(emoji, style: const TextStyle(fontSize: 32)),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }


  void _updateTypingStatus(bool isTyping) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.uid != null) {
      await ApiService.updateTypingStatus(_chatId, authProvider.uid!, isTyping);
    }
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
              await ApiService.clearChat(_chatId);
              await _loadMessages();
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
                  FutureBuilder<Map<String, dynamic>>(
                    future: ApiService.getTypingUser(_chatId),
                    builder: (context, snap) {
                      if (snap.hasData) {
                        final typingUser = snap.data!['typingUser'] ?? '';
                        final authProvider = context.read<AuthProvider>();
                        if (typingUser.isNotEmpty && typingUser != authProvider.uid) {
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
            icon: const Icon(Icons.search),
            onPressed: () => setState(() => _isSearching = !_isSearching),
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
                case 'mute':
                  ApiService.muteChat(_chatId, true);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã tắt thông báo')));
                  break;
                case 'unmute':
                  ApiService.muteChat(_chatId, false);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã bật thông báo')));
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'group_settings', child: Text('Cài đặt nhóm')),
              const PopupMenuItem(value: 'mute', child: Text('Tắt thông báo')),
              const PopupMenuItem(value: 'unmute', child: Text('Bật thông báo')),
              const PopupMenuItem(value: 'clear_chat', child: Text('Xóa lịch sử chat')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isSearching)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              color: Theme.of(context).cardColor,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm tin nhắn...',
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _isSearching = false);
                      _loadMessages();
                    },
                  ),
                ),
                onChanged: _searchMessages,
              ),
            ),
          Expanded(child: _buildMessageList()),
          if (_replyingTo != null) _buildReplyPreview(),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_messages.isEmpty) {
      return const Center(
        child: Text(
          'Hãy gửi tin nhắn đầu tiên!',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final authProvider = context.read<AuthProvider>();
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index] as Map<String, dynamic>;
        final isMe = msg['sender_uid'] == authProvider.uid;
        final reactions = (msg['reactions'] as List<dynamic>?)?.map((r) => r as Map<String, dynamic>).toList() ?? [];

        return MessageBubble(
          text: msg['text'] ?? '',
          isMe: isMe,
          senderName: msg['sender_name'] ?? '',
          timestamp: msg['created_at'] != null ? DateTime.parse(msg['created_at']) : null,
          isEdited: msg['is_edited'] == true || msg['is_edited'] == 1,
          type: msg['message_type'] ?? 'text',
          imageUrl: msg['imageUrl'],
          imageBase64: msg['image_base64'],
          deliveryStatus: msg['delivery_status'] ?? 'sent',
          replyToText: msg['reply_to_text'],
          replyToSender: msg['reply_to_sender'],
          reactions: reactions,
          isPinned: msg['is_pinned'] == true || msg['is_pinned'] == 1,
          onLongPress: () => _showMessageOptions(msg),
          onSwipeReply: () => _setReply(msg),
        );
      },
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: AppColors.primary.withValues(alpha: 0.05),
      child: Row(
        children: [
          Container(width: 3, height: 36, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _replyingTo!['sender_name'] ?? '',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                Text(
                  _replyingTo!['text'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: _cancelReply,
          ),
        ],
      ),
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
