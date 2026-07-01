import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../utils/app_localizations.dart';
import '../constants/app_colors.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/chat/screens/call_screen.dart';

/// Wraps the app to listen for incoming calls on any screen.
class CallHandler extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;
  const CallHandler({super.key, required this.child, this.navigatorKey});

  @override
  State<CallHandler> createState() => _CallHandlerState();
}

class _CallHandlerState extends State<CallHandler> with WidgetsBindingObserver {
  StreamSubscription<Map<String, dynamic>>? _callOfferSub;
  StreamSubscription<Map<String, dynamic>>? _callEndSub;
  StreamSubscription<Map<String, dynamic>>? _callRejectSub;
  StreamSubscription<Map<String, dynamic>>? _messageSub;
  bool _dialogShown = false;
  String? _pendingCallerUid;
  OverlayEntry? _notificationOverlay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupCallListener();
  }

  void _setupCallListener() {
    final myUid = context.read<AuthProvider>().uid;
    _messageSub = SocketService.instance.onMessage.listen((event) async {
      final chatId = event['chatId'];
      final senderUid = event['senderUid']?.toString();
      if (senderUid == null || senderUid == myUid) return;
      if (SocketService.instance.currentChatId?.toString() == chatId?.toString()) return;
      final blockStatus = await ApiService.checkBlockStatus(senderUid);
      if (blockStatus['i_blocked_them'] == true) return;
      _showMessageNotification(event);
    });

    _callOfferSub = SocketService.instance.onCallOffer.listen((data) async {
      if (_dialogShown) return;
      final fromUid = data['fromUid']?.toString();
      if (fromUid == null || fromUid == myUid) return;
      final blockStatus = await ApiService.checkBlockStatus(fromUid);
      if (blockStatus['i_blocked_them'] == true) return;
      _pendingCallerUid = fromUid;
      _showIncomingCallDialog(data);
    });

    _callEndSub = SocketService.instance.onCallEnd.listen((data) {
      final fromUid = data['fromUid']?.toString();
      if (_dialogShown && fromUid == _pendingCallerUid) {
        _dismissDialog();
      }
    });

    _callRejectSub = SocketService.instance.onCallReject.listen((data) {
      final fromUid = data['fromUid']?.toString();
      if (_dialogShown && fromUid == _pendingCallerUid) {
        _dismissDialog();
      }
    });
  }

  void _dismissDialog() {
    _dialogShown = false;
    _pendingCallerUid = null;
    final navContext = widget.navigatorKey?.currentContext;
    if (navContext != null && Navigator.canPop(navContext)) {
      Navigator.pop(navContext);
    }
  }

  void _showIncomingCallDialog(Map<String, dynamic> data) {
    _dialogShown = true;
    final navContext = widget.navigatorKey?.currentContext ?? context;
    final isVideo = data['isVideo'] == true;
    final callerName = data['callerName']?.toString() ?? 'Unknown';
    final callerAvatar = data['callerAvatar']?.toString();
    final sdp = data['sdp'] as Map<String, dynamic>?;
    final fromUid = data['fromUid']?.toString();
    final myUid = context.read<AuthProvider>().uid;

    showDialog(
      context: navContext,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(isVideo
            ? AppLocalizations.of(navContext).translate('incoming_video_call')
            : AppLocalizations.of(navContext).translate('incoming_voice_call')),
        content: Text(AppLocalizations.of(navContext).tr('calling_you', params: {'name': callerName})),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _dialogShown = false;
              if (fromUid != null) {
                SocketService.instance.sendCallReject(fromUid);
              }
            },
            child: Text(AppLocalizations.of(navContext).translate('decline'),
                style: const TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _dialogShown = false;
              if (myUid != null && fromUid != null && sdp != null) {
                widget.navigatorKey?.currentState?.push(
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => CallScreen(
                      myUid: myUid,
                      peerUid: fromUid,
                      peerName: callerName,
                      peerAvatar: callerAvatar,
                      isVideo: isVideo,
                      isCaller: false,
                      incomingSdp: sdp,
                    ),
                  ),
                );
              }
            },
            child: Text(AppLocalizations.of(navContext).translate('accept'),
                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ).then((_) => _dialogShown = false);
  }

  void _showMessageNotification(Map<String, dynamic> event) {
    _notificationOverlay?.remove();
    final msgData = event['message'] as Map<String, dynamic>?;
    final senderName = event['senderName']?.toString() ?? '';
    final text = msgData?['content']?.toString() ?? event['text']?.toString() ?? '';
    final messageType = msgData?['type']?.toString() ?? event['messageType']?.toString() ?? 'text';
    final chatId = event['chatId']?.toString() ?? '';

    String preview;
    if (messageType == 'image') {
      preview = '[Hình ảnh]';
    } else if (messageType == 'voice') {
      preview = '[Tin nhắn thoại]';
    } else if (messageType == 'call') {
      preview = text;
    } else {
      preview = text;
    }

    final isInChat = SocketService.instance.currentChatId?.toString() == chatId;

    _notificationOverlay = OverlayEntry(
      builder: (context) => _MessageNotification(
        senderName: senderName,
        preview: preview,
        compact: isInChat,
        onTap: () {
          _notificationOverlay?.remove();
          _notificationOverlay = null;
          if (!isInChat) {
            final navContext = widget.navigatorKey?.currentContext ?? context;
            Navigator.of(navContext).pushNamed(
              '/chat_detail',
              arguments: {
                'chatId': int.tryParse(chatId) ?? 0,
                'chatName': senderName,
              },
            );
          }
        },
      ),
    );
    final navContext = widget.navigatorKey?.currentContext ?? context;
    try {
      Overlay.of(navContext).insert(_notificationOverlay!);
    } catch (_) {
      _notificationOverlay = null;
    }

    Future.delayed(const Duration(seconds: 4), () {
      _notificationOverlay?.remove();
      _notificationOverlay = null;
    });
  }

  @override
  void dispose() {
    _callOfferSub?.cancel();
    _callEndSub?.cancel();
    _callRejectSub?.cancel();
    _messageSub?.cancel();
    _notificationOverlay?.remove();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _MessageNotification extends StatefulWidget {
  final String senderName;
  final String preview;
  final VoidCallback onTap;
  final bool compact;

  const _MessageNotification({
    required this.senderName,
    required this.preview,
    required this.onTap,
    this.compact = false,
  });

  @override
  State<_MessageNotification> createState() => _MessageNotificationState();
}

class _MessageNotificationState extends State<_MessageNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _offsetAnim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topPadding + 8,
      left: widget.compact ? 16 : 12,
      right: widget.compact ? 16 : 12,
      child: SlideTransition(
        position: _offsetAnim,
        child: Material(
          elevation: widget.compact ? 4 : 8,
          borderRadius: BorderRadius.circular(widget.compact ? 8 : 12),
          color: Colors.white,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(widget.compact ? 8 : 12),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 10 : 14,
                vertical: widget.compact ? 6 : 10,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.compact ? 8 : 12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: widget.compact
                  ? Row(
                      children: [
                        const Icon(Icons.message, color: AppColors.primary, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: RichText(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              children: [
                                TextSpan(
                                  text: '${widget.senderName}: ',
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                ),
                                TextSpan(text: widget.preview),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.message, color: AppColors.primary, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.senderName,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
