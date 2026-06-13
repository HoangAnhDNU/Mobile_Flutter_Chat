import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:file_picker/file_picker.dart';  // Temporarily disabled
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_config.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/socket_service.dart';
import '../../../core/utils/app_localizations.dart';
import '../../auth/providers/auth_provider.dart';
import '../widgets/message_bubble.dart';
import 'camera_capture_screen.dart';

class ChatDetailScreen extends StatefulWidget {
  final int chatId;
  final String chatName;
  final bool isGroup;
  
  const ChatDetailScreen({
    super.key,
    required this.chatId,
    required this.chatName,
    required this.isGroup,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> with SingleTickerProviderStateMixin {
  final _messageController = TextEditingController();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  List<dynamic> _messages = [];
  List<dynamic> _pinnedMessages = [];
  bool _isLoading = false;
  bool _isSearching = false;
  bool _showMoreActions = false;

  String? _editingMessageId;
  bool _isEditing = false;

  // Reply state
  Map<String, dynamic>? _replyingTo;

  late int _chatId;
  late String _chatName;
  String? _chatAvatar;
  ImageProvider? _cachedAvatarProvider;
  bool _initialized = false;
  bool _isMuted = false;
  bool _isPeerTyping = false;
  String? _typingUid;
  String _typingName = '';
  String? _myUid;
  Timer? _typingClearTimer;
  late final AnimationController _typingController;
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<Map<String, dynamic>>? _typingSubscription;
  StreamSubscription<Map<String, dynamic>>? _reactionSubscription;
  StreamSubscription<Map<String, dynamic>>? _deleteSubscription;
  StreamSubscription<Map<String, dynamic>>? _pinSubscription;

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
    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _chatId = args?['chatId'] ?? 0;
      _chatName = args?['chatName'] ?? 'Chat';
      _chatAvatar = args?['chatAvatar'];
      if (_chatAvatar != null && _chatAvatar!.isNotEmpty) {
        _cachedAvatarProvider = _getImageProvider(_chatAvatar!);
      }
      _connectRealtime();
      _loadMessages();
      _loadPinned();
      _loadMuteStatus();
    }
  }

  void _connectRealtime() {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.uid == null) return;
    _myUid = authProvider.uid;

    SocketService.instance.connect(authProvider.uid!);
    SocketService.instance.joinChat(_chatId);

    _messageSubscription ??= SocketService.instance.onMessage.listen((event) async {
      if (!mounted) return;
      if (event['chatId'] == _chatId) {
        await _loadMessages(silent: true);
        _scrollToLatest();

        final isFromOther = event['senderUid'] != authProvider.uid;
        if (isFromOther) {
          SystemSound.play(SystemSoundType.alert);
          _showRealtimeNotice(event['senderName']?.toString());
        }
      }
    });

    _typingSubscription ??= SocketService.instance.onTyping.listen((event) {
      if (!mounted) return;
      if (event['chatId'] == _chatId) {
        final uid = event['uid']?.toString();
        final isTyping = event['isTyping'] == true;
        if (uid != null && uid != authProvider.uid) {
          setState(() {
            _isPeerTyping = isTyping;
            _typingUid = isTyping ? uid : null;
            if (!isTyping) {
              _typingName = '';
            }
          });
          // Hủy timer cũ; nếu đang typing thì đặt timer tự xóa sau 6 giây
          // (phòng khi sự kiện typing-stop bị mất do mất kết nối đột ngột).
          _typingClearTimer?.cancel();
          if (isTyping) {
            _typingClearTimer = Timer(const Duration(seconds: 6), () {
              if (!mounted) return;
              setState(() {
                _isPeerTyping = false;
                _typingUid = null;
                _typingName = '';
              });
            });
            _resolveTypingName();
          }
        }
      }
    });

    // Reaction thay đổi realtime -> nạp lại tin nhắn (im lặng, không nhấp nháy).
    _reactionSubscription ??= SocketService.instance.onReaction.listen((event) {
      if (!mounted) return;
      if (event['chatId'] == _chatId) _loadMessages(silent: true);
    });

    // Tin nhắn bị thu hồi realtime -> nạp lại + cập nhật ghim.
    _deleteSubscription ??= SocketService.instance.onDelete.listen((event) {
      if (!mounted) return;
      if (event['chatId'] == _chatId) {
        _loadMessages(silent: true);
        _loadPinned();
      }
    });

    // Ghim/bỏ ghim realtime -> cập nhật banner ghim + tin nhắn.
    _pinSubscription ??= SocketService.instance.onPin.listen((event) {
      if (!mounted) return;
      if (event['chatId'] == _chatId) {
        _loadMessages(silent: true);
        _loadPinned();
      }
    });
  }

  Future<void> _resolveTypingName() async {
    if (_typingUid == null || _typingUid!.isEmpty) return;
    try {
      final user = await ApiService.getUser(_typingUid!);
      if (!mounted) return;
      setState(() {
        _typingName = (user['display_name'] ?? '').toString();
      });
    } catch (_) {
      // Ignore typing name lookup failures and keep generic label.
    }
  }

  void _showRealtimeNotice(String? senderName) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    final topOffset = MediaQuery.of(context).padding.top + kToolbarHeight + 8;
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(12, topOffset, 12, 0),
        backgroundColor: const Color(0xFFF1F8E9),
        content: Row(
          children: [
            const Icon(Icons.notifications_active_outlined, color: AppColors.success),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tin nhắn mới${(senderName != null && senderName.isNotEmpty) ? ' từ $senderName' : ''}',
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _scrollToLatest() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _loadMuteStatus() async {
    // Mute status is managed locally for now
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final messages = await ApiService.getMessages(_chatId);
      if (mounted) setState(() => _messages = messages);
    } catch (e) {
      debugPrint('Error loading messages: $e');
    }
    if (mounted && !silent) setState(() => _isLoading = false);
  }

  Future<void> _loadPinned() async {
    try {
      final pinned = await ApiService.getPinnedMessages(_chatId);
      if (mounted) setState(() => _pinnedMessages = pinned);
    } catch (e) {
      debugPrint('Error loading pinned: $e');
    }
  }

  @override
  void dispose() {
    // Báo cho đối phương biết đã ngừng soạn tin trước khi rời màn hình.
    if (_myUid != null) {
      SocketService.instance.sendTyping(_chatId, false);
    }
    SocketService.instance.leaveChat(_chatId);
    _typingClearTimer?.cancel();
    _messageSubscription?.cancel();
    _typingSubscription?.cancel();
    _reactionSubscription?.cancel();
    _deleteSubscription?.cancel();
    _pinSubscription?.cancel();
    _typingController.dispose();
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

    SocketService.instance.sendMessage({
      'chatId': _chatId,
      'senderUid': authProvider.uid!,
      'senderName': authProvider.displayName ?? 'Unknown',
      'text': text,
      'messageType': 'text',
    });

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
    final bytes = await pickedFile.readAsBytes();
    await _sendImageBytes(bytes);
  }

  /// Mở màn camera để chụp ảnh trực tiếp rồi gửi.
  Future<void> _captureFromCamera() async {
    final bytes = await Navigator.push<Uint8List?>(
      context,
      MaterialPageRoute(builder: (_) => const CameraCaptureScreen()),
    );
    if (bytes == null || bytes.isEmpty) return;
    await _sendImageBytes(bytes);
  }

  Future<void> _sendImageBytes(List<int> bytes) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.uid == null) return;
    try {
      final base64Image = base64Encode(bytes);

      await ApiService.sendMessage(
        chatId: _chatId,
        senderUid: authProvider.uid!,
        senderName: authProvider.displayName ?? 'Unknown',
        text: '',
        messageType: 'image',
        imageBase64: base64Image,
      );

      SocketService.instance.sendMessage({
        'chatId': _chatId,
        'senderUid': authProvider.uid!,
        'senderName': authProvider.displayName ?? 'Unknown',
        'text': '',
        'messageType': 'image',
        'imageBase64': base64Image,
      });

      await _loadMessages(silent: true);
      _scrollToLatest();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gửi ảnh thất bại: ${e.toString().length > 80 ? e.toString().substring(0, 80) : e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _showImageSourcePicker() {
    setState(() => _showMoreActions = !_showMoreActions);
  }

  // Temporarily disabled due to file_picker dependency conflict
  /*
  Future<void> _sendVoiceMessage() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.uid == null) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        withData: true,
        allowedExtensions: const ['m4a', 'mp3', 'wav', 'webm', 'ogg', 'aac'],
      );

      if (result == null || result.files.isEmpty) return;
      final picked = result.files.first;
      final bytes = picked.bytes;

      if (bytes == null || bytes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không đọc được dữ liệu voice message.')),
        );
        return;
      }

      final voiceBase64 = base64Encode(bytes);

      await ApiService.sendMessage(
        chatId: _chatId,
        senderUid: authProvider.uid!,
        senderName: authProvider.displayName ?? 'Unknown',
        text: '',
        messageType: 'voice',
        voiceBase64: voiceBase64,
        voiceDuration: 0,
      );

      SocketService.instance.sendMessage({
        'chatId': _chatId,
        'senderUid': authProvider.uid!,
        'senderName': authProvider.displayName ?? 'Unknown',
        'text': '',
        'messageType': 'voice',
      });

      await _loadMessages();
      _scrollToLatest();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi voice message.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gửi voice message thất bại: $e')),
      );
    }
  }
  */

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
    final isDeleted = msg['is_deleted'] == true || msg['is_deleted'] == 1;

    // Tin đã thu hồi: chỉ cho phép xóa khỏi màn hình của mình.
    if (isDeleted) {
      showModalBottomSheet(
        context: context,
        builder: (context) => SafeArea(
          child: ListTile(
            leading: const Icon(Icons.delete_outline, color: AppColors.textSecondary),
            title: const Text('Xóa cho mình'),
            onTap: () {
              Navigator.pop(context);
              ApiService.deleteForMe(int.parse(messageId)).then((_) => _loadMessages(silent: true));
            },
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
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
                onTap: () async {
                  Navigator.pop(context);
                  final res = await ApiService.pinMessage(_chatId, int.parse(messageId));
                  if (!mounted) return;
                  if (res['ok'] == true) {
                    await _loadMessages(silent: true);
                    await _loadPinned();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(res['error']?.toString() ?? 'Ghim thất bại'), backgroundColor: AppColors.error),
                    );
                  }
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
                  ApiService.deleteForMe(int.parse(messageId)).then((_) => _loadMessages(silent: true));
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
              ApiService.deleteForEveryone(int.parse(messageId)).then((_) {
                _loadMessages(silent: true);
                _loadPinned();
              });
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
                  ApiService.addReaction(messageId, emoji).then((_) => _loadMessages(silent: true));
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
      SocketService.instance.sendTyping(_chatId, isTyping);
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
                                await ApiService.pinMessage(_chatId, msg['id']);
                                if (!context.mounted) return;
                                Navigator.pop(context);
                                _loadMessages();
                                _loadPinned();
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
              final ok = await ApiService.clearChat(_chatId);
              await _loadMessages(silent: true);
              await _loadPinned();
              if (mounted && ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã xóa lịch sử trò chuyện')),
                );
              }
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
              backgroundImage: _cachedAvatarProvider,
              child: (_cachedAvatarProvider == null)
                  ? Text(
                      _chatName.isNotEmpty ? _chatName[0].toUpperCase() : '?',
                      style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.bold),
                    )
                  : null,
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
                  Text(
                    _isPeerTyping
                        ? '${_typingName.isNotEmpty ? _typingName : 'Ai đó'} ${AppLocalizations.of(context).translate('typing')}'
                        : AppLocalizations.of(context).translate('online'),
                    style: const TextStyle(fontSize: 12, color: AppColors.success),
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
          if (_isSearching)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              color: Theme.of(context).cardColor,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context).translate('search_messages'),
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
          if (_pinnedMessages.isNotEmpty) _buildPinnedBanner(),
          Expanded(child: _buildMessageList()),
          if (_isPeerTyping) _buildTypingIndicator(),
          if (_replyingTo != null) _buildReplyPreview(),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    final displayName = _typingName.isNotEmpty ? _typingName : 'Ai đó';
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _typingController,
                builder: (context, _) {
                  final opacity = 0.3 + (_typingController.value * 0.7);
                  return Icon(
                    Icons.more_horiz,
                    size: 18,
                    color: AppColors.primary.withValues(alpha: opacity),
                  );
                },
              ),
              const SizedBox(width: 6),
              Text(
                '$displayName đang soạn tin...',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinnedBanner() {
    return InkWell(
      onTap: _showPinnedMessages,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: AppColors.primary.withValues(alpha: 0.08),
        child: Row(
          children: [
            const Icon(Icons.push_pin, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tin nhắn đã ghim (${_pinnedMessages.length})',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  Text(
                    (_pinnedMessages.first as Map<String, dynamic>)['text']?.toString() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
          ],
        ),
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
          senderAvatar: msg['sender_avatar'],
          timestamp: msg['created_at'] != null ? DateTime.parse(msg['created_at']) : null,
          isEdited: msg['is_edited'] == true || msg['is_edited'] == 1,
          type: msg['message_type'] ?? 'text',
          imageUrl: msg['imageUrl'],
          imageBase64: msg['image_base64'],
          voiceDuration: msg['voice_duration'],
          deliveryStatus: msg['delivery_status'] ?? 'sent',
          replyToText: msg['reply_to_text'],
          replyToSender: msg['reply_to_sender'],
          reactions: reactions,
          isPinned: msg['is_pinned'] == true || msg['is_pinned'] == 1,
          isDeleted: msg['is_deleted'] == true || msg['is_deleted'] == 1,
          imageLabel: msg['image_label'],
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _isEditing ? _cancelEditing : () => _sendImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined, size: 18),
                        label: const Text('Chọn từ thư viện'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _isEditing ? _cancelEditing : _captureFromCamera,
                        icon: const Icon(Icons.photo_camera_outlined, size: 18),
                        label: const Text('Chụp ảnh'),
                      ),
                      // Temporarily disabled due to file_picker dependency conflict
                      /*
                      FilledButton.tonalIcon(
                        onPressed: _isEditing ? _cancelEditing : _sendVoiceMessage,
                        icon: const Icon(Icons.mic_none, size: 18),
                        label: const Text('Voice'),
                      ),
                      */
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _showMoreActions ? Icons.expand_less : Icons.more_horiz,
                    color: AppColors.primary,
                  ),
                  onPressed: _showImageSourcePicker,
                ),
              ],
            ),
            if (_showMoreActions)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Tính năng bổ sung sẽ hiển thị ở đây, không mở lớp nền tối.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.8)),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (_isEditing)
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.error),
                    onPressed: _cancelEditing,
                  ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: _isEditing 
                          ? AppLocalizations.of(context).translate('edit_message') 
                          : AppLocalizations.of(context).translate('type_message'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    textInputAction: TextInputAction.send,
                    keyboardType: TextInputType.text,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (value) => _updateTypingStatus(value.trim().isNotEmpty),
                    onSubmitted: (_) => _isEditing ? _updateMessage() : _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    _isEditing ? Icons.check_circle : Icons.send,
                    color: AppColors.primary,
                  ),
                  onPressed: _isEditing ? _updateMessage : _sendMessage,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
