import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_config.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/socket_service.dart';
import '../../../core/utils/app_localizations.dart';
import '../../auth/providers/auth_provider.dart';
import '../widgets/message_bubble.dart';
import 'camera_capture_screen.dart';
import 'call_screen.dart';

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
  int _currentPage = 1;
  bool _hasMoreMessages = true;
  bool _isLoadingMore = false;
  final Set<String> _newMessageIds = {};

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
  bool _isGroup = false;
  bool _peerOnline = false;
  String? _peerUid;
  bool _peerBlocked = false;
  bool _theyBlockedMe = false;
  int? _autoDeleteDays;
  StreamSubscription<Map<String, dynamic>>? _presenceSubscription;
  Timer? _typingClearTimer;
  late final AnimationController _typingController;
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<Map<String, dynamic>>? _typingSubscription;
  StreamSubscription<Map<String, dynamic>>? _reactionSubscription;
  StreamSubscription<Map<String, dynamic>>? _deleteSubscription;
  StreamSubscription<Map<String, dynamic>>? _pinSubscription;
  StreamSubscription<void>? _connectSubscription;
  StreamSubscription<Map<String, dynamic>>? _mentionSubscription;

  // Voice recording
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordPath;
  Timer? _recordTimer;
  int _recordDuration = 0;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  final List<double> _amplitudes = [];

  final GlobalKey _attachButtonKey = GlobalKey();

  // Mention state
  List<Map<String, dynamic>> _groupParticipants = [];
  bool _showMentionList = false;
  String _mentionQuery = '';
  final List<String> _mentionedUids = [];

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
      _isGroup = args?['isGroup'] == true;
      if (_chatAvatar != null && _chatAvatar!.isNotEmpty) {
        _cachedAvatarProvider = _getImageProvider(_chatAvatar!);
      }
      _connectRealtime();
      _loadMessages();
      _loadPinned();
      _loadMuteStatus();
      _loadChatInfo();
      _scrollController.addListener(() {
        if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
            !_isLoadingMore && _hasMoreMessages) {
          _loadMoreMessages();
        }
      });
    }
  }

  void _connectRealtime() {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.uid == null) return;
    _myUid = authProvider.uid;

    SocketService.instance.connect(authProvider.uid!);
    SocketService.instance.joinChat(_chatId);

    _messageSubscription ??= SocketService.instance.onMessage.listen((event) {
      if (!mounted) return;
      if (event['chatId']?.toString() == _chatId.toString()) {
        final senderUid = event['senderUid']?.toString();
        final isFromOther = senderUid != authProvider.uid;

        final msgData = event['message'] as Map<String, dynamic>?;
        final msgId = (msgData?['id'] ?? event['id'] ?? DateTime.now().millisecondsSinceEpoch).toString();

        final newMsg = <String, dynamic>{
          'id': msgData?['id'] ?? event['id'] ?? DateTime.now().millisecondsSinceEpoch,
          'text': msgData?['content'] ?? event['text'] ?? '',
          'sender_uid': senderUid ?? '',
          'sender_name': event['senderName'] ?? msgData?['sender_name'] ?? '',
          'sender_avatar': msgData?['sender_avatar'] ?? event['senderAvatar'],
          'created_at': msgData?['created_at'] ?? event['createdAt'] ?? DateTime.now().toIso8601String(),
          'is_edited': msgData?['edited_at'] != null,
          'message_type': msgData?['type'] ?? event['messageType'] ?? 'text',
          'imageUrl': msgData?['media_url'] ?? (event['imageBase64'] != null
              ? (event['imageBase64'].toString().startsWith('data:')
                  ? event['imageBase64']
                  : 'data:image/png;base64,${event['imageBase64']}')
              : null),
          'image_base64': event['imageBase64'],
          'voice_duration': msgData?['voice_duration'] ?? event['voiceDuration'] ?? 0,
          'delivery_status': msgData?['status'] ?? 'sent',
          'reply_to_text': msgData?['reply_to_text'],
          'reply_to_sender': msgData?['reply_to_sender'],
          'is_pinned': msgData?['is_pinned'] == true,
          'is_deleted': msgData?['is_deleted'] == true,
          'forwarded': msgData?['forwarded'] == true,
          'image_label': msgData?['image_label'],
          'fake_news_label': msgData?['fake_news_label'],
          'mentions': (msgData?['mentions'] as List?)?.map((e) => e.toString()).toList() ?? [],
          'reactions': (msgData?['reactions'] as List?)
              ?.map((r) => Map<String, dynamic>.from(r as Map))
              .toList() ?? [],
        };

        final exists = _messages.any((m) {
          final existing = m as Map<String, dynamic>;
          return existing['id'].toString() == msgId;
        });

        if (!exists) {
          _newMessageIds.add(msgId);
          setState(() {
            _messages.insert(0, newMsg);
          });
          _scrollToLatest();
        }

        if (isFromOther) {
          SystemSound.play(SystemSoundType.alert);
        }
      }
    });

    _typingSubscription ??= SocketService.instance.onTyping.listen((event) {
      if (!mounted) return;
      if (event['chatId']?.toString() == _chatId.toString()) {
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

    // Reaction thay đổi realtime -> cập nhật trực tiếp tin nhắn.
    _reactionSubscription ??= SocketService.instance.onReaction.listen((event) {
      if (!mounted) return;
      if (event['chatId']?.toString() == _chatId.toString()) {
        final msgData = event['message'] as Map<String, dynamic>?;
        final msgId = msgData?['id']?.toString();
        if (msgId == null) return;
        setState(() {
          final idx = _messages.indexWhere((m) {
            final msg = m as Map<String, dynamic>;
            return msg['id'].toString() == msgId;
          });
          if (idx != -1) {
            final msg = Map<String, dynamic>.from(_messages[idx] as Map);
            msg['reactions'] = (msgData!['reactions'] as List?)
                ?.map((r) => Map<String, dynamic>.from(r as Map))
                .toList() ?? msg['reactions'];
            _messages[idx] = msg;
          }
        });
      }
    });

    // Tin nhắn bị thu hồi realtime -> cập nhật trực tiếp + cập nhật ghim.
    _deleteSubscription ??= SocketService.instance.onDelete.listen((event) {
      if (!mounted) return;
      if (event['chatId']?.toString() == _chatId.toString()) {
        final messageId = event['messageId']?.toString();
        if (messageId == null) return;
        setState(() {
          final idx = _messages.indexWhere((m) {
            final msg = m as Map<String, dynamic>;
            return msg['id'].toString() == messageId;
          });
          if (idx != -1) {
            final msg = Map<String, dynamic>.from(_messages[idx] as Map);
            msg['is_deleted'] = true;
            msg['text'] = '';
            msg['imageUrl'] = null;
            msg['image_base64'] = null;
            msg['image_label'] = null;
            msg['fake_news_label'] = null;
            _messages[idx] = msg;
          }
        });
        _loadPinned();
      }
    });

    // Ghim/bỏ ghim realtime -> cập nhật trực tiếp + cập nhật banner ghim.
    _pinSubscription ??= SocketService.instance.onPin.listen((event) {
      if (!mounted) return;
      if (event['chatId']?.toString() == _chatId.toString()) {
        final messageId = event['messageId']?.toString();
        final isPinned = event['isPinned'] == true;
        if (messageId == null) return;
        setState(() {
          final idx = _messages.indexWhere((m) {
            final msg = m as Map<String, dynamic>;
            return msg['id'].toString() == messageId;
          });
          if (idx != -1) {
            final msg = Map<String, dynamic>.from(_messages[idx] as Map);
            msg['is_pinned'] = isPinned;
            _messages[idx] = msg;
          }
        });
        _loadPinned();
      }
    });

    _presenceSubscription ??= SocketService.instance.onPresence.listen((event) {
      if (!mounted) return;
      final uid = event['uid']?.toString();
      final isOnline = event['is_online'] == true;
      if (uid != null && uid == _peerUid) {
        setState(() => _peerOnline = isOnline);
      }
    });

    _connectSubscription ??= SocketService.instance.onConnect.listen((_) {
      if (!mounted) return;
      _loadChatInfo();
    });

    _mentionSubscription ??= SocketService.instance.onMention.listen((event) {
      if (!mounted) return;
      if (event['chatId']?.toString() == _chatId.toString()) {
        final senderName = event['senderName']?.toString() ?? '';
        final msgData = event['message'] as Map<String, dynamic>?;
        final content = msgData?['content']?.toString() ?? '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$senderName đã nhắc đến bạn: $content'),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  Future<void> _loadChatInfo() async {
    try {
      final info = await ApiService.getChatInfo(_chatId);
      if (!mounted) return;
      final participants = info['participants'] as List? ?? [];
      final myUid = _myUid;
      final peer = participants.where((p) {
        final m = p as Map<String, dynamic>;
        return m['id']?.toString() != myUid;
      }).toList();
      setState(() {
        _isGroup = info['is_group'] == true;
        if (_isGroup) {
          _groupParticipants = participants.map((p) => Map<String, dynamic>.from(p as Map)).toList();
        }
        if (peer.isNotEmpty) {
          final p = peer.first as Map<String, dynamic>;
          _peerUid = p['id']?.toString();
          final apiOnline = p['is_online'] == true;
          final cachedOnline = _peerUid != null ? SocketService.instance.presenceCache[_peerUid] : null;
          if (cachedOnline == true) {
            _peerOnline = true;
          } else if (apiOnline || !_peerOnline) {
            _peerOnline = apiOnline;
          }
          if (!_isGroup) {
            final peerAvatar = p['avatar_url']?.toString() ?? '';
            final peerName = p['display_name']?.toString() ?? '';
            if (peerAvatar.isNotEmpty) {
              _chatAvatar = peerAvatar;
              _cachedAvatarProvider = _getImageProvider(peerAvatar);
            }
            if (peerName.isNotEmpty) {
              _chatName = peerName;
            }
          }
        }
      });
      // Chạy song song block status + auto-delete
      final results = await Future.wait([
        _peerUid != null ? ApiService.checkBlockStatus(_peerUid!) : Future.value({'i_blocked_them': false, 'they_blocked_me': false}),
        ApiService.getAutoDelete(_chatId),
      ]);
      if (!mounted) return;
      final blockStatus = results[0] as Map<String, dynamic>;
      final autoDelete = results[1] as int;
      setState(() {
        _peerBlocked = blockStatus['i_blocked_them'] == true;
        _theyBlockedMe = blockStatus['they_blocked_me'] == true;
        _autoDeleteDays = autoDelete;
      });
    } catch (_) {}
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
    _currentPage = 1;
    _hasMoreMessages = true;
    try {
      final messages = await ApiService.getMessages(_chatId, page: 1, limit: 30);
      if (mounted) {
        setState(() {
          _messages = messages;
          if (messages.length < 30) _hasMoreMessages = false;
        });
      }
    } catch (_) {}
    if (mounted && !silent) setState(() => _isLoading = false);
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages) return;
    _isLoadingMore = true;

    final oldCount = _messages.length;
    final oldMaxScroll = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;

    try {
      final nextPage = _currentPage + 1;
      final olderMessages = await ApiService.getMessages(_chatId, page: nextPage, limit: 30);
      if (mounted && olderMessages.isNotEmpty) {
        setState(() {
          _messages.addAll(olderMessages);
          _currentPage = nextPage;
          if (olderMessages.length < 30) _hasMoreMessages = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients && oldCount > 0) {
            final newMaxScroll = _scrollController.position.maxScrollExtent;
            _scrollController.jumpTo(newMaxScroll - oldMaxScroll);
          }
        });
      } else {
        _hasMoreMessages = false;
      }
    } catch (_) {}
    _isLoadingMore = false;
  }

  Future<void> _loadPinned() async {
    try {
      final pinned = await ApiService.getPinnedMessages(_chatId);
      if (mounted) setState(() => _pinnedMessages = pinned);
    } catch (_) {}
  }

  @override
  void dispose() {
    // Báo cho đối phương biết đã ngừng soạn tin trước khi rời màn hình.
    if (_myUid != null) {
      SocketService.instance.sendTyping(_chatId, false);
    }
    SocketService.instance.leaveChat(_chatId);
    _typingClearTimer?.cancel();
    _recordTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _messageSubscription?.cancel();
    _typingSubscription?.cancel();
    _reactionSubscription?.cancel();
    _deleteSubscription?.cancel();
    _pinSubscription?.cancel();
    _presenceSubscription?.cancel();
    _connectSubscription?.cancel();
    _mentionSubscription?.cancel();
    _typingController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.uid == null) return;

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final mentionsToSend = List<String>.from(_mentionedUids);
    _messageController.clear();
    _mentionedUids.clear();
    _showMentionList = false;

    try {
      if (_replyingTo != null) {
        final sentMsg = await ApiService.sendReplyMessage(
          chatId: _chatId,
          senderUid: authProvider.uid!,
          senderName: authProvider.displayName ?? 'Unknown',
          text: text,
          replyToId: _replyingTo!['id'],
          replyToText: _replyingTo!['text'] ?? '',
          replyToSender: _replyingTo!['sender_name'] ?? '',
          mentions: mentionsToSend.isNotEmpty ? mentionsToSend : null,
        );
        setState(() {
          _replyingTo = null;
          if (sentMsg.isNotEmpty) {
            _messages.insert(0, sentMsg);
            _newMessageIds.add(sentMsg['id'].toString());
          }
        });
        _scrollToLatest();
      } else {
        final sentMsg = await ApiService.sendMessage(
          chatId: _chatId,
          senderUid: authProvider.uid!,
          senderName: authProvider.displayName ?? 'Unknown',
          text: text,
          messageType: 'text',
          mentions: mentionsToSend.isNotEmpty ? mentionsToSend : null,
        );
        setState(() {
          if (sentMsg.isNotEmpty) {
            _messages.insert(0, sentMsg);
            _newMessageIds.add(sentMsg['id'].toString());
          }
        });
        _scrollToLatest();
      }
    } catch (e) {
      if (!mounted) return;
      final errorStr = e.toString();
      if (errorStr.contains('403') || errorStr.contains('blocked') || errorStr.contains('chặn')) {
        if (errorStr.contains('đã chặn người nhận') || errorStr.contains('blocked the receiver')) {
          setState(() => _peerBlocked = true);
        } else {
          setState(() => _theyBlockedMe = true);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('blocked_cannot_send')),
            backgroundColor: AppColors.error,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).tr('send_failed', params: {'error': e})),
            backgroundColor: AppColors.error,
          ),
        );
      }
      _messageController.text = text;
      _mentionedUids.addAll(mentionsToSend);
      return;
    }
  }

  Future<void> _searchMessages(String query) async {
    if (query.isEmpty) {
      await _loadMessages(silent: true);
      return;
    }
    try {
      _messages = await ApiService.searchMessages(_chatId, query);
      if (mounted) setState(() {});
    } catch (_) {}
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

      final sentMsg = await ApiService.sendMessage(
        chatId: _chatId,
        senderUid: authProvider.uid!,
        senderName: authProvider.displayName ?? 'Unknown',
        text: '',
        messageType: 'image',
        imageBase64: base64Image,
      );

      if (mounted && sentMsg.isNotEmpty) {
        setState(() {
          _newMessageIds.add(sentMsg['id'].toString());
          _messages.insert(0, sentMsg);
        });
        _scrollToLatest();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).tr('send_image_failed', params: {'error': e.toString().length > 80 ? e.toString().substring(0, 80) : e.toString()})),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _toggleAttachMenu() {
    final RenderBox? box = _attachButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final Offset position = box.localToGlobal(Offset.zero);
    final Size size = box.size;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy - 180,
        position.dx + size.width + 120,
        position.dy,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'gallery',
          child: Row(
            children: [
              const Icon(Icons.photo_library_outlined, size: 20, color: AppColors.primary),
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context).translate('from_gallery')),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'camera',
          child: Row(
            children: [
              const Icon(Icons.photo_camera_outlined, size: 20, color: AppColors.primary),
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context).translate('take_photo')),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'record',
          child: Row(
            children: [
              const Icon(Icons.mic_none, size: 20, color: AppColors.primary),
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context).translate('record')),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'gallery') {
        _sendImage(ImageSource.gallery);
      } else if (value == 'camera') {
        _captureFromCamera();
      } else if (value == 'record') {
        _startRecording();
      }
    });
  }

  Future<void> _startRecording() async {
    try {
      if (!(await _recorder.hasPermission())) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).translate('mic_permission_denied'))),
        );
        return;
      }
      _recordDuration = 0;
      _amplitudes.clear();

      if (kIsWeb) {
        await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: '');
      } else {
        final dir = await getTemporaryDirectory();
        _recordPath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: _recordPath!);
      }

      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordDuration++);
      });
      try {
        _amplitudeSubscription = _recorder.onAmplitudeChanged(const Duration(milliseconds: 100)).listen((amp) {
          if (mounted) {
            final normalized = ((amp.current + 60) / 60).clamp(0.0, 1.0);
            _amplitudes.add(normalized);
            if (_amplitudes.length > 100) _amplitudes.removeAt(0);
            setState(() {});
          }
        });
      } catch (_) {
        // Amplitude not supported on this platform, recording still works
      }
      setState(() => _isRecording = true);
    } catch (e) {
      debugPrint('Recording error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).tr('recording_failed', params: {'error': e}))),
      );
    }
  }

  Future<void> _stopRecordingAndSend() async {
    _recordTimer?.cancel();
    await _amplitudeSubscription?.cancel();

    String voiceBase64;
    if (kIsWeb) {
      final blobUrl = await _recorder.stop();
      if (blobUrl == null || blobUrl.isEmpty) {
        setState(() => _isRecording = false);
        return;
      }
      // Fetch bytes from blob URL
      final response = await http.get(Uri.parse(blobUrl));
      voiceBase64 = base64Encode(response.bodyBytes);
      setState(() => _isRecording = false);
    } else {
      final path = await _recorder.stop();
      setState(() => _isRecording = false);
      if (path == null || path.isEmpty) return;
      final file = File(path);
      if (!await file.exists()) return;
      final bytes = await file.readAsBytes();
      voiceBase64 = base64Encode(bytes);
      await file.delete();
    }

    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();
    if (authProvider.uid == null) return;

    final audioDataUri = 'data:audio/m4a;base64,$voiceBase64';

    await ApiService.sendMessage(
      chatId: _chatId,
      senderUid: authProvider.uid!,
      senderName: authProvider.displayName ?? 'Unknown',
      text: '',
      messageType: 'voice',
      voiceBase64: voiceBase64,
      voiceDuration: _recordDuration * 1000,
    );

    final tempId = DateTime.now().millisecondsSinceEpoch;

    final newMsg = <String, dynamic>{
      'id': tempId,
      'text': '',
      'sender_uid': authProvider.uid!,
      'sender_name': authProvider.displayName ?? 'Unknown',
      'sender_avatar': authProvider.avatarUrl,
      'created_at': DateTime.now().toIso8601String(),
      'is_edited': false,
      'message_type': 'voice',
      'imageUrl': audioDataUri,
      'image_base64': null,
      'voice_duration': _recordDuration * 1000,
      'delivery_status': 'sent',
      'reply_to_text': null,
      'reply_to_sender': null,
      'is_pinned': false,
      'is_deleted': false,
      'forwarded': false,
      'image_label': null,
      'fake_news_label': null,
      'reactions': [],
    };
    if (mounted) {
      setState(() {
        _messages.insert(0, newMsg);
      });
      _scrollToLatest();
    }
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    await _amplitudeSubscription?.cancel();
    try {
      await _recorder.stop();
    } catch (_) {}
    _amplitudes.clear();
    _recordPath = null;
    if (mounted) setState(() => _isRecording = false);
  }

  Future<void> _updateMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _editingMessageId == null) return;

    _messageController.clear();

    await ApiService.updateMessage(int.parse(_editingMessageId!), text);

    final editingId = _editingMessageId!;
    setState(() {
      _isEditing = false;
      _editingMessageId = null;
      final idx = _messages.indexWhere((m) {
        final msg = m as Map<String, dynamic>;
        return msg['id'].toString() == editingId;
      });
      if (idx != -1) {
        final msg = Map<String, dynamic>.from(_messages[idx] as Map);
        msg['text'] = text;
        msg['is_edited'] = true;
        _messages[idx] = msg;
      }
    });
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
            title: Text(AppLocalizations.of(context).translate('delete_for_me')),
            onTap: () {
              Navigator.pop(context);
              ApiService.deleteForMe(int.parse(messageId)).then((_) {
                setState(() {
                  _messages.removeWhere((m) {
                    final msg = m as Map<String, dynamic>;
                    return msg['id'].toString() == messageId;
                  });
                });
              });
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
                title: Text(AppLocalizations.of(context).translate('reply')),
                onTap: () {
                  Navigator.pop(context);
                  _setReply(msg);
                },
              ),
              ListTile(
                leading: const Icon(Icons.emoji_emotions_outlined, color: Colors.orange),
                title: Text(AppLocalizations.of(context).translate('react')),
                onTap: () {
                  Navigator.pop(context);
                  _showReactionPicker(int.parse(messageId));
                },
              ),
              if (isMyMessage)
                ListTile(
                  leading: const Icon(Icons.edit, color: AppColors.primary),
                  title: Text(AppLocalizations.of(context).translate('edit')),
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
                title: Text(isPinned ? AppLocalizations.of(context).translate('unpin') : AppLocalizations.of(context).translate('pin_message')),
                onTap: () async {
                  Navigator.pop(context);
                  final res = await ApiService.pinMessage(_chatId, int.parse(messageId));
                  if (!mounted) return;
                  if (res['ok'] == true) {
                    setState(() {
                      final idx = _messages.indexWhere((m) {
                        final msg = m as Map<String, dynamic>;
                        return msg['id'].toString() == messageId;
                      });
                      if (idx != -1) {
                        final msg = Map<String, dynamic>.from(_messages[idx] as Map);
                        msg['is_pinned'] = !(msg['is_pinned'] == true);
                        _messages[idx] = msg;
                      }
                    });
                    await _loadPinned();
                    if (!mounted) return;
                  } else {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(content: Text(res['error']?.toString() ?? AppLocalizations.of(this.context).translate('pin_failed')), backgroundColor: AppColors.error),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.forward, color: AppColors.primary),
                title: Text(AppLocalizations.of(context).translate('forward')),
                onTap: () {
                  Navigator.pop(context);
                  _showForwardDialog(int.parse(messageId));
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy, color: AppColors.textSecondary),
                title: Text(AppLocalizations.of(context).translate('copy')),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: text));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context).translate('copied')), duration: const Duration(seconds: 1)),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.textSecondary),
                title: Text(AppLocalizations.of(context).translate('delete_for_me')),
                onTap: () {
                  Navigator.pop(context);
                  ApiService.deleteForMe(int.parse(messageId)).then((_) {
                setState(() {
                  _messages.removeWhere((m) {
                    final msg = m as Map<String, dynamic>;
                    return msg['id'].toString() == messageId;
                  });
                });
              });
                },
              ),
              if (isMyMessage)
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: AppColors.error),
                  title: Text(AppLocalizations.of(context).translate('delete_for_everyone')),
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
        title: Text(AppLocalizations.of(context).translate('delete_for_everyone')),
        content: Text(AppLocalizations.of(context).translate('delete_for_everyone_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppLocalizations.of(context).translate('cancel'))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ApiService.deleteForEveryone(int.parse(messageId)).then((_) {
                setState(() {
                  final idx = _messages.indexWhere((m) {
                    final msg = m as Map<String, dynamic>;
                    return msg['id'].toString() == messageId;
                  });
                  if (idx != -1) {
                    final msg = Map<String, dynamic>.from(_messages[idx] as Map);
                    msg['is_deleted'] = true;
                    _messages[idx] = msg;
                  }
                });
                _loadPinned();
              });
            },
            child: Text(AppLocalizations.of(context).translate('delete'), style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showForwardDialog(int messageId) async {
    // Load user's chats to pick target
    final chats = await ApiService.getChats();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(AppLocalizations.of(context).translate('forward_to'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ...chats.where((c) => c['id'] != _chatId).take(10).map((chat) {
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.chat)),
                title: Text(chat['chat_name']?.toString() ?? 'Chat'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await ApiService.forwardMessage(messageId, chat['id'] as int);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppLocalizations.of(context).translate('forwarded'))),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppLocalizations.of(context).tr('error_msg', params: {'error': e})), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
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
                  ApiService.addReaction(messageId, emoji).then((res) {
                    final msgData = res?['message'] as Map<String, dynamic>?;
                    if (msgData != null) {
                      setState(() {
                        final idx = _messages.indexWhere((m) {
                          final msg = m as Map<String, dynamic>;
                          return msg['id'].toString() == msgData['id'].toString();
                        });
                        if (idx != -1) {
                          final msg = Map<String, dynamic>.from(_messages[idx] as Map);
                          msg['reactions'] = (msgData['reactions'] as List?)
                              ?.map((r) => Map<String, dynamic>.from(r as Map))
                              .toList() ?? msg['reactions'];
                          _messages[idx] = msg;
                        }
                      });
                    }
                  });
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
                    Text(AppLocalizations.of(context).tr('pinned_messages', params: {'count': pinned.length}),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: pinned.isEmpty
                    ? Center(child: Text(AppLocalizations.of(context).translate('no_pinned')))
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
                                setState(() {
                                  final idx = _messages.indexWhere((m) {
                                    final item = m as Map<String, dynamic>;
                                    return item['id'].toString() == msg['id'].toString();
                                  });
                                  if (idx != -1) {
                                    final updated = Map<String, dynamic>.from(_messages[idx] as Map);
                                    updated['is_pinned'] = false;
                                    _messages[idx] = updated;
                                  }
                                });
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
    } catch (_) {}
  }

  void _confirmBlockUser() {
    String? reportReason;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).translate('block_user')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppLocalizations.of(context).tr('block_confirm', params: {'name': _chatName})),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).translate('report_reason_hint'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              maxLines: 2,
              onChanged: (value) => reportReason = value.trim().isEmpty ? null : value.trim(),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context).translate('cancel'))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (_peerUid == null) return;
              try {
                await ApiService.blockUser(_peerUid!, reportReason: reportReason);
                if (!mounted) return;
                setState(() => _peerBlocked = true);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(context).translate('blocked'))),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(context).tr('block_failed', params: {'error': e}))),
                );
              }
            },
            child: Text(AppLocalizations.of(context).translate('block'), style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _unblockUser() async {
    if (_peerUid == null) return;
    try {
      await ApiService.unblockUser(_peerUid!);
      if (!mounted) return;
      setState(() {
        _peerBlocked = false;
        _theyBlockedMe = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).translate('unblocked'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).tr('unblock_failed', params: {'error': e}))),
      );
    }
  }

  void _showAutoDeleteDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) {
        int? selected = _autoDeleteDays;
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(l10n.translate('auto_delete_messages')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.translate('auto_delete_desc'),
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 12),
                ...[null, 1, 7, 14].map((days) {
                  final label = days == null
                      ? l10n.translate('off')
                      : l10n.tr('auto_delete_days_option', params: {'days': days});
                  final isSelected = selected == days;
                  return ListTile(
                    dense: true,
                    title: Text(
                      label,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppColors.primary : null,
                      ),
                    ),
                    trailing: isSelected ? const Icon(Icons.check, color: AppColors.primary) : null,
                    onTap: () => setDialogState(() => selected = days),
                  );
                }),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l10n.translate('cancel')),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  try {
                    await ApiService.setAutoDelete(_chatId, selected ?? 0);
                    if (!mounted) return;
                    setState(() => _autoDeleteDays = selected);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.translate('auto_delete_saved'))),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.tr('save_error', params: {'error': e}))),
                    );
                  }
                },
                child: Text(l10n.translate('save')),
              ),
            ],
          );
        });
      },
    );
  }

  void _showClearChatConfirm() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context).translate('delete_chat')),
        content: Text(AppLocalizations.of(context).translate('clear_chat_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context).translate('cancel')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await ApiService.deleteChat(_chatId);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(context).translate('chat_deleted'))),
                );
                Navigator.of(context).pushNamedAndRemoveUntil(
                  AppRoutes.chatList,
                  (route) => route.isFirst,
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(context).tr('delete_failed', params: {'error': e}))),
                );
              }
            },
            child: Text(AppLocalizations.of(context).translate('delete'), style: const TextStyle(color: AppColors.error)),
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

  void _onInputChanged(String value) {
    _updateTypingStatus(value.trim().isNotEmpty);
    if (!_isGroup) return;
    final cursorPos = _messageController.selection.baseOffset;
    if (cursorPos < 0) return;
    final textBeforeCursor = value.substring(0, cursorPos);
    final atIndex = textBeforeCursor.lastIndexOf('@');
    if (atIndex == -1) {
      if (_showMentionList) setState(() => _showMentionList = false);
      return;
    }
    final afterAt = textBeforeCursor.substring(atIndex + 1);
    if (afterAt.contains(' ') || afterAt.contains('\n')) {
      if (_showMentionList) setState(() => _showMentionList = false);
      return;
    }
    setState(() {
      _showMentionList = true;
      _mentionQuery = afterAt.toLowerCase();
    });
  }

  List<String> _resolveMentionNames(dynamic mentions) {
    final mentionList = (mentions as List?)?.map((e) => e.toString()).toList() ?? [];
    if (mentionList.isEmpty) return [];
    final names = <String>[];
    for (final m in mentionList) {
      if (m == 'all') {
        names.add('all');
        continue;
      }
      final participant = _groupParticipants.where((p) => p['id']?.toString() == m).firstOrNull;
      if (participant != null) {
        names.add(participant['display_name']?.toString() ?? '');
      }
    }
    return names.where((n) => n.isNotEmpty).toList();
  }

  void _selectMention(Map<String, dynamic> participant) {
    final name = participant['display_name']?.toString() ?? 'User';
    final uid = participant['id']?.toString() ?? '';
    final cursorPos = _messageController.selection.baseOffset;
    final text = _messageController.text;
    final textBeforeCursor = text.substring(0, cursorPos < 0 ? 0 : cursorPos);
    final atIndex = textBeforeCursor.lastIndexOf('@');
    if (atIndex == -1) return;
    final newText = '${text.substring(0, atIndex)}@$name ${text.substring(cursorPos < 0 ? 0 : cursorPos)}';
    _messageController.text = newText;
    final newCursorPos = atIndex + name.length + 2;
    _messageController.selection = TextSelection.collapsed(offset: newCursorPos);
    if (!_mentionedUids.contains(uid)) {
      _mentionedUids.add(uid);
    }
    setState(() {
      _showMentionList = false;
      _mentionQuery = '';
    });
  }

  void _selectMentionAll() {
    final cursorPos = _messageController.selection.baseOffset;
    final text = _messageController.text;
    final textBeforeCursor = text.substring(0, cursorPos < 0 ? 0 : cursorPos);
    final atIndex = textBeforeCursor.lastIndexOf('@');
    if (atIndex == -1) return;
    final newText = '${text.substring(0, atIndex)}@all ${text.substring(cursorPos < 0 ? 0 : cursorPos)}';
    _messageController.text = newText;
    final newCursorPos = atIndex + 5;
    _messageController.selection = TextSelection.collapsed(offset: newCursorPos);
    if (!_mentionedUids.contains('all')) {
      _mentionedUids.add('all');
    }
    setState(() {
      _showMentionList = false;
      _mentionQuery = '';
    });
  }

  Widget _buildMentionList() {
    final myUid = _myUid;
    final filtered = _groupParticipants.where((p) {
      final pid = p['id']?.toString() ?? '';
      if (pid == myUid) return false;
      final name = (p['display_name']?.toString() ?? '').toLowerCase();
      return _mentionQuery.isEmpty || name.contains(_mentionQuery);
    }).toList();

    final showAll = _mentionQuery.isEmpty || 'all'.contains(_mentionQuery);

    return Material(
      elevation: 4,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 250),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            if (showAll)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: const Icon(Icons.group, color: AppColors.primary, size: 20),
                ),
                title: const Text('@all', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Nhắc đến tất cả thành viên'),
                onTap: _selectMentionAll,
              ),
            ...filtered.map((p) => ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                backgroundImage: (p['avatar_url']?.toString().isNotEmpty == true)
                    ? _getImageProvider(p['avatar_url'])
                    : null,
                child: (p['avatar_url']?.toString().isNotEmpty != true)
                    ? Text(
                        (p['display_name']?.toString().isNotEmpty == true)
                            ? p['display_name'][0].toUpperCase()
                            : '?',
                        style: const TextStyle(color: AppColors.primary, fontSize: 16),
                      )
                    : null,
              ),
              title: Text(p['display_name']?.toString() ?? 'User'),
              onTap: () => _selectMention(p),
            )),
            if (filtered.isEmpty && !showAll)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Không tìm thấy thành viên', style: TextStyle(color: AppColors.textSecondary)),
              ),
          ],
        ),
      ),
    );
  }

  void _startCall({required bool isVideo}) {
    if (_peerUid == null || _myUid == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          myUid: _myUid!,
          peerUid: _peerUid!,
          peerName: _chatName,
          peerAvatar: _chatAvatar,
          isVideo: isVideo,
          isCaller: true,
          chatId: _chatId,
        ),
      ),
    );
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
                        ? '${_typingName.isNotEmpty ? _typingName : AppLocalizations.of(context).translate('someone')} ${AppLocalizations.of(context).translate('typing')}'
                        : _isGroup
                            ? AppLocalizations.of(context).translate('group')
                            : _peerOnline
                                ? AppLocalizations.of(context).translate('online')
                                : AppLocalizations.of(context).translate('offline'),
                    style: TextStyle(
                      fontSize: 12,
                      color: _isPeerTyping || _peerOnline ? AppColors.success : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (!_isGroup) ...[
            IconButton(
              icon: const Icon(Icons.call),
              tooltip: AppLocalizations.of(context).translate('voice_call'),
              onPressed: () => _startCall(isVideo: false),
            ),
            IconButton(
              icon: const Icon(Icons.videocam),
              tooltip: AppLocalizations.of(context).translate('video_call'),
              onPressed: () => _startCall(isVideo: true),
            ),
          ],
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'search':
                  setState(() => _isSearching = !_isSearching);
                  break;
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
                    SnackBar(content: Text(newMuted ? AppLocalizations.of(context).translate('muted') : AppLocalizations.of(context).translate('unmuted'))),
                  );
                  break;
                case 'pinned':
                  _showPinnedMessages();
                  break;
                case 'block_user':
                  _confirmBlockUser();
                  break;
                case 'unblock_user':
                  _unblockUser();
                  break;
                case 'auto_delete':
                  _showAutoDeleteDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'search', child: Text(AppLocalizations.of(context).translate('search_messages').replaceAll('...', ''))),
              if (_isGroup) PopupMenuItem(value: 'group_settings', child: Text(AppLocalizations.of(context).translate('group_settings'))),
              PopupMenuItem(value: 'toggle_mute', child: Text(_isMuted ? AppLocalizations.of(context).translate('unmute') : AppLocalizations.of(context).translate('mute'))),
              PopupMenuItem(value: 'pinned', child: Text(AppLocalizations.of(context).translate('view_pinned'))),
              PopupMenuItem(value: 'clear_chat', child: Text(AppLocalizations.of(context).translate('delete_chat'))),
              if (!_isGroup) PopupMenuItem(value: 'auto_delete', child: Text(AppLocalizations.of(context).translate('auto_delete_messages'))),
              if (!_isGroup && _peerUid != null && !_peerBlocked) ...[
                PopupMenuItem(
                  value: 'block_user',
                  child: Text(AppLocalizations.of(context).translate('block_user'), style: const TextStyle(color: AppColors.error)),
                ),
              ],
              if (!_isGroup && _peerBlocked) ...[
                PopupMenuItem(
                  value: 'unblock_user',
                  child: Text(AppLocalizations.of(context).translate('unblock_user'), style: const TextStyle(color: AppColors.success)),
                ),
              ],
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
                      _loadMessages(silent: true);
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
          if (_showMentionList) _buildMentionList(),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    final displayName = _typingName.isNotEmpty ? _typingName : AppLocalizations.of(context).translate('someone');
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
                AppLocalizations.of(context).tr('typing_with_name', params: {'name': displayName}),
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
                    AppLocalizations.of(context).tr('pinned_messages', params: {'count': _pinnedMessages.length}),
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
      return Center(
        child: Text(
          AppLocalizations.of(context).translate('first_message'),
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final authProvider = context.read<AuthProvider>();
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _messages.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final msg = _messages[index] as Map<String, dynamic>;
        final isMe = msg['sender_uid'] == authProvider.uid;
        final reactions = (msg['reactions'] as List<dynamic>?)?.map((r) => r as Map<String, dynamic>).toList() ?? [];
        final msgId = msg['id'].toString();
        final isNew = _newMessageIds.contains(msgId);

        final bubble = MessageBubble(
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
          forwarded: msg['forwarded'] == true,
          imageLabel: msg['image_label'],
          fakeNewsLabel: msg['fake_news_label'],
          mentions: (msg['mentions'] as List?)?.map((e) => e.toString()).toList() ?? [],
          mentionNames: _resolveMentionNames(msg['mentions']),
          onLongPress: () => _showMessageOptions(msg),
          onSwipeReply: () => _setReply(msg),
        );

        if (isNew) {
          return _SlideInMessage(
            key: ValueKey('anim_$msgId'),
            isMe: isMe,
            onAnimationComplete: () => _newMessageIds.remove(msgId),
            child: bubble,
          );
        }
        return bubble;
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
    if (!_isGroup && _peerBlocked) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              const Icon(Icons.block, color: AppColors.textSecondary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).translate('you_blocked_user'),
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
              ),
              TextButton(
                onPressed: _unblockUser,
                child: Text(AppLocalizations.of(context).translate('unblock')),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isGroup && _theyBlockedMe) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              const Icon(Icons.block, color: AppColors.textSecondary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).translate('they_blocked_you'),
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      );
    }

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
            const SizedBox(height: 8),
            if (_isRecording)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10, height: 10,
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_recordDuration ~/ 60}:${(_recordDuration % 60).toString().padLeft(2, '0')}',
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: CustomPaint(
                          painter: _WaveformPainter(_amplitudes),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.error),
                      onPressed: _cancelRecording,
                      tooltip: AppLocalizations.of(context).translate('cancel'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, color: AppColors.primary),
                      onPressed: _stopRecordingAndSend,
                      tooltip: AppLocalizations.of(context).translate('send'),
                    ),
                  ],
                ),
              )
            else
              Row(
                children: [
                  if (_isEditing)
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.error),
                      onPressed: _cancelEditing,
                    ),
                  if (!_isEditing)
                    IconButton(
                      key: _attachButtonKey,
                      icon: Icon(
                        Icons.add_circle_outline,
                        color: AppColors.primary,
                      ),
                      onPressed: _toggleAttachMenu,
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
                      onChanged: _onInputChanged,
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

class _SlideInMessage extends StatefulWidget {
  final bool isMe;
  final VoidCallback onAnimationComplete;
  final Widget child;

  const _SlideInMessage({
    super.key,
    required this.isMe,
    required this.onAnimationComplete,
    required this.child,
  });

  @override
  State<_SlideInMessage> createState() => _SlideInMessageState();
}

class _SlideInMessageState extends State<_SlideInMessage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    final direction = widget.isMe ? const Offset(0.3, 0) : const Offset(-0.3, 0);
    _slideAnimation = Tween<Offset>(
      begin: direction,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _controller.forward().then((_) {
      if (mounted) widget.onAnimationComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  _WaveformPainter(this.amplitudes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final barWidth = 3.0;
    final gap = 2.0;
    final totalSpace = barWidth + gap;
    final maxBars = (size.width / totalSpace).floor();
    final startY = size.height / 2;

    final data = amplitudes.length > maxBars
        ? amplitudes.sublist(amplitudes.length - maxBars)
        : amplitudes;

    for (var i = 0; i < data.length; i++) {
      final x = i * totalSpace;
      final amp = data[i];
      final barHeight = (amp * size.height * 0.8).clamp(2.0, size.height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, startY), width: barWidth, height: barHeight),
          const Radius.circular(1.5),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) => true;
}
