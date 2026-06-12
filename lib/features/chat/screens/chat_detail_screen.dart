import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/socket_service.dart';
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
  bool _isMuted = false;

  // Socket
  final _socketService = SocketService.instance;
  StreamSubscription? _messageSub;
  StreamSubscription? _connectionSub;
  bool _socketConnected = true;

  // Speech-to-Text
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isTranscribing = false;
  String? _recordingPath;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _chatId = args?['chatId'] ?? 0;
      _chatName = args?['chatName'] ?? 'Chat';
      _loadMessages();
      _loadMuteStatus();
      _setupSocket();
    }
  }

  void _setupSocket() {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.uid != null && !_socketService.isConnected) {
      _socketService.connect(authProvider.uid!);
    }
    _socketService.joinChat(_chatId);

    _messageSub = _socketService.onMessage.listen((data) {
      final msgChatId = data['chat_id'];
      if (msgChatId == _chatId || msgChatId == _chatId.toString()) {
        if (mounted) {
          setState(() {
            _messages.insert(0, data);
          });
        }
      }
    });

    _connectionSub = _socketService.onConnectionChange.listen((connected) {
      if (mounted) setState(() => _socketConnected = connected);
    });
  }

  Future<void> _loadMuteStatus() async {
    // Mute status is managed locally for now
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
    _messageSub?.cancel();
    _connectionSub?.cancel();
    _socketService.leaveChat(_chatId);
    _messageController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecordingAndTranscribe();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cần cấp quyền micro để ghi âm'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      final dir = await getTemporaryDirectory();
      _recordingPath = '${dir.path}/stt_${DateTime.now().millisecondsSinceEpoch}.wav';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: _recordingPath!,
      );

      setState(() => _isRecording = true);
    } catch (e) {
      debugPrint('Recording error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi ghi âm: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _stopRecordingAndTranscribe() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _isTranscribing = true;
      });

      if (path == null) {
        setState(() => _isTranscribing = false);
        return;
      }

      final result = await ApiService.transcribeAudio(path);
      final text = (result['text'] as String?)?.trim() ?? '';

      if (text.isNotEmpty) {
        _messageController.text = _messageController.text.isEmpty
            ? text
            : '${_messageController.text} $text';
        _messageController.selection = TextSelection.fromPosition(
          TextPosition(offset: _messageController.text.length),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không nhận diện được giọng nói')),
        );
      }

      // Xóa file tạm
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('Transcribe error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi nhận diện: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isTranscribing = false);
    }
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

  void _showPinnedMessages() async {
    try {
      final pinned = await ApiService.getPinnedMessages(_chatId);
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.push_pin, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text('Tin nhắn ghim (${pinned.length})',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: pinned.isEmpty
                    ? const Center(child: Text('Chưa có tin nhắn ghim'))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: pinned.length,
                        itemBuilder: (context, index) {
                          final msg = pinned[index] as Map<String, dynamic>;
                          return ListTile(
                            leading: const Icon(Icons.push_pin, size: 18, color: AppColors.primary),
                            title: Text(msg['text'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                            subtitle: Text(msg['sender_name'] ?? '',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            trailing: IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () async {
                                await ApiService.pinMessage(msg['id'], false);
                                if (!context.mounted) return;
                                Navigator.pop(context);
                                _loadMessages();
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error loading pinned messages: $e');
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
                case 'toggle_mute':
                  final newMuted = !_isMuted;
                  ApiService.muteChat(_chatId, newMuted);
                  setState(() => _isMuted = newMuted);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(newMuted ? 'Đã tắt thông báo' : 'Đã bật thông báo')),
                  );
                  break;
                case 'pinned':
                  _showPinnedMessages();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'group_settings', child: Text('Cài đặt nhóm')),
              PopupMenuItem(value: 'toggle_mute', child: Text(_isMuted ? 'Bật thông báo' : 'Tắt thông báo')),
              const PopupMenuItem(value: 'pinned', child: Text('Xem tin nhắn ghim')),
              const PopupMenuItem(value: 'clear_chat', child: Text('Xóa lịch sử chat')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_socketConnected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              color: Colors.orange,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                  SizedBox(width: 8),
                  Text('Đang kết nối lại...', style: TextStyle(color: Colors.white, fontSize: 13)),
                ],
              ),
            ),
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
                  hintText: _isRecording
                      ? 'Đang ghi âm...'
                      : _isTranscribing
                          ? 'Đang nhận diện giọng nói...'
                          : _isEditing
                              ? 'Chỉnh sửa tin nhắn...'
                              : 'Message...',
                  border: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: null,
                enabled: !_isRecording && !_isTranscribing,
                onChanged: (value) => _updateTypingStatus(value.trim().isNotEmpty),
              ),
            ),
            if (_isTranscribing)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (!_isEditing)
              IconButton(
                icon: Icon(
                  _isRecording ? Icons.stop_circle : Icons.mic,
                  color: _isRecording ? AppColors.error : AppColors.textSecondary,
                  size: _isRecording ? 28 : 24,
                ),
                onPressed: _toggleRecording,
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
