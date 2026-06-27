import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_config.dart';
import '../../../core/services/socket_service.dart';
import '../../../core/services/webrtc_call_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/app_localizations.dart';
import '../../auth/providers/auth_provider.dart';

class CallScreen extends StatefulWidget {
  final String myUid;
  final String peerUid;
  final String peerName;
  final String? peerAvatar;
  final bool isVideo;
  final bool isCaller;
  final Map<String, dynamic>? incomingSdp;
  final int? chatId;

  const CallScreen({
    super.key,
    required this.myUid,
    required this.peerUid,
    required this.peerName,
    this.peerAvatar,
    required this.isVideo,
    required this.isCaller,
    this.incomingSdp,
    this.chatId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _webrtc = WebRTCCallService.instance;
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();

  StreamSubscription<CallState>? _stateSub;
  StreamSubscription<MediaStream?>? _localStreamSub;
  StreamSubscription<MediaStream?>? _remoteStreamSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<Map<String, dynamic>>? _answerSub;
  StreamSubscription<Map<String, dynamic>>? _iceSub;
  StreamSubscription<Map<String, dynamic>>? _endSub;
  StreamSubscription<Map<String, dynamic>>? _rejectSub;

  CallState _callState = CallState.idle;
  Duration _duration = Duration.zero;
  bool _muted = false;
  bool _cameraOff = false;
  bool _speakerOn = true;

  @override
  void initState() {
    super.initState();
    _localRenderer.initialize();
    _remoteRenderer.initialize();

    _setupListeners();

    if (widget.isCaller) {
      final authProvider = context.read<AuthProvider>();
      _webrtc.initCall(
        myUid: widget.myUid,
        targetUid: widget.peerUid,
        isVideo: widget.isVideo,
        callerName: authProvider.displayName ?? 'Unknown',
        callerAvatar: authProvider.avatarUrl,
      );
    } else if (widget.incomingSdp != null) {
      _webrtc.acceptCall(
        myUid: widget.myUid,
        callerUid: widget.peerUid,
        isVideo: widget.isVideo,
        sdp: widget.incomingSdp!,
      );
    }
  }

  void _setupListeners() {
    _stateSub = _webrtc.onStateChange.listen((state) {
      if (mounted) setState(() => _callState = state);
      if (state == CallState.ended || state == CallState.rejected || state == CallState.failed) {
        _finishCall();
      }
    });

    _localStreamSub = _webrtc.onLocalStream.listen((stream) {
      if (stream != null && widget.isVideo) {
        _localRenderer.srcObject = stream;
      }
    });

    _remoteStreamSub = _webrtc.onRemoteStream.listen((stream) {
      if (stream != null) {
        _remoteRenderer.srcObject = stream;
      }
    });

    _durationSub = _webrtc.onDurationChange.listen((d) {
      if (mounted) setState(() => _duration = d);
    });

    final socket = SocketService.instance;
    _answerSub = socket.onCallAnswer.listen((data) {
      if (data['fromUid'] == widget.peerUid) {
        _webrtc.handleRemoteAnswer(data['sdp'] is Map ? data['sdp'] : data);
      }
    });

    _iceSub = socket.onCallIce.listen((data) {
      if (data['fromUid'] == widget.peerUid) {
        _webrtc.handleRemoteIceCandidate(data);
      }
    });

    _endSub = socket.onCallEnd.listen((data) {
      final fromUid = data['fromUid']?.toString();
      if (fromUid == widget.peerUid && _callState != CallState.ended && _callState != CallState.rejected) {
        _webrtc.handleCallEnded();
      }
    });

    _rejectSub = socket.onCallReject.listen((data) {
      final fromUid = data['fromUid']?.toString();
      if (fromUid == widget.peerUid && _callState != CallState.ended && _callState != CallState.rejected) {
        _webrtc.handleCallRejected();
      }
    });
  }

  bool _isFinishing = false;

  void _sendCallMessage(String callType) {
    if (widget.chatId == null) return;
    final authProvider = context.read<AuthProvider>();
    final senderName = authProvider.displayName ?? 'Unknown';
    final isVideo = widget.isVideo ? 'video' : 'voice';
    final content = callType == 'missed'
        ? isVideo == 'video' ? 'Cuộc gọi video nhỡ' : 'Cuộc gọi nhỡ'
        : callType == 'rejected'
            ? isVideo == 'video' ? 'Cuộc gọi video bị từ chối' : 'Cuộc gọi bị từ chối'
            : callType == 'cancelled'
                ? isVideo == 'video' ? 'Cuộc gọi video đã hủy' : 'Cuộc gọi đã hủy'
                : isVideo == 'video'
                    ? 'Cuộc gọi video · ${_formatDuration(_duration)}'
                    : 'Cuộc gọi · ${_formatDuration(_duration)}';

    try {
      ApiService.sendMessage(
        chatId: widget.chatId!,
        senderUid: widget.myUid,
        senderName: senderName,
        text: content,
        messageType: 'call',
      );
      final tempId = DateTime.now().millisecondsSinceEpoch;
      SocketService.instance.injectMessage({
        'chatId': widget.chatId,
        'senderUid': widget.myUid,
        'senderName': senderName,
        'text': content,
        'messageType': 'call',
        'id': tempId,
        'createdAt': DateTime.now().toIso8601String(),
        'senderAvatar': authProvider.avatarUrl,
      });
    } catch (_) {}
  }

  void _finishCall() {
    if (_isFinishing) return;
    _isFinishing = true;

    final state = _callState;
    if (state == CallState.connected) {
      _sendCallMessage('completed');
    } else if (state == CallState.rejected) {
      _sendCallMessage('rejected');
    } else if (state == CallState.offering || state == CallState.ringing) {
      _sendCallMessage(widget.isCaller ? 'cancelled' : 'missed');
    }

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    });
  }

  void _hangUp() {
    _webrtc.endCall();
    _finishCall();
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _webrtc.toggleMute(_muted);
  }

  void _toggleCamera() {
    setState(() => _cameraOff = !_cameraOff);
    _webrtc.toggleCamera(!_cameraOff);
  }

  void _toggleSpeaker() {
    setState(() => _speakerOn = !_speakerOn);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _stateText() {
    final l10n = AppLocalizations.of(context);
    switch (_callState) {
      case CallState.offering:
        return l10n.translate('calling');
      case CallState.ringing:
        return l10n.translate('ringing');
      case CallState.connected:
        return _formatDuration(_duration);
      case CallState.ended:
        return l10n.translate('call_ended');
      case CallState.rejected:
        return l10n.translate('call_rejected');
      case CallState.failed:
        return l10n.translate('call_failed');
      default:
        return l10n.translate('connecting');
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _localStreamSub?.cancel();
    _remoteStreamSub?.cancel();
    _durationSub?.cancel();
    _answerSub?.cancel();
    _iceSub?.cancel();
    _endSub?.cancel();
    _rejectSub?.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _webrtc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: widget.isVideo ? _buildVideoCallUI(l10n) : _buildVoiceCallUI(l10n),
    );
  }

  // =================== VIDEO CALL UI ===================
  Widget _buildVideoCallUI(AppLocalizations l10n) {
    return Stack(
      children: [
        // Remote video (full screen)
        Positioned.fill(
          child: RTCVideoView(
            _remoteRenderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            mirror: false,
          ),
        ),
        // Local video (picture-in-picture)
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          right: 16,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 120,
              height: 180,
              child: RTCVideoView(
                _localRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                mirror: true,
              ),
            ),
          ),
        ),
        // Top info
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.peerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _stateText(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        // Bottom controls
        Positioned(
          bottom: MediaQuery.of(context).padding.bottom + 32,
          left: 0,
          right: 0,
          child: _buildControls(l10n),
        ),
      ],
    );
  }

  // =================== VOICE CALL UI ===================
  Widget _buildVoiceCallUI(AppLocalizations l10n) {
    return SafeArea(
      child: Column(
        children: [
          const Spacer(flex: 2),
          // Avatar
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.2),
            ),
            child: ClipOval(
              child: widget.peerAvatar != null && widget.peerAvatar!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: AppConfig.resolveMediaUrl(widget.peerAvatar!),
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Center(
                        child: Text(
                          widget.peerName.isNotEmpty
                              ? widget.peerName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Center(
                        child: Text(
                          widget.peerName.isNotEmpty
                              ? widget.peerName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        widget.peerName.isNotEmpty
                            ? widget.peerName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 24),
          // Name
          Text(
            widget.peerName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          // State / duration
          Text(
            _stateText(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
          const Spacer(flex: 3),
          // Controls
          _buildControls(l10n),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // =================== SHARED CONTROLS ===================
  Widget _buildControls(AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Mute
        _buildControlButton(
          icon: _muted ? Icons.mic_off : Icons.mic,
          label: l10n.translate('microphone'),
          active: _muted,
          onTap: _toggleMute,
        ),
        // Camera toggle (video only)
        if (widget.isVideo)
          _buildControlButton(
            icon: _cameraOff ? Icons.videocam_off : Icons.videocam,
            label: l10n.translate('camera'),
            active: _cameraOff,
            onTap: _toggleCamera,
          ),
        // Speaker
        _buildControlButton(
          icon: _speakerOn ? Icons.volume_up : Icons.volume_off,
          label: l10n.translate('speaker'),
          active: _speakerOn,
          onTap: _toggleSpeaker,
        ),
        // Hang up
        GestureDetector(
          onTap: _hangUp,
          child: Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red,
            ),
            child: const Icon(
              Icons.call_end,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? Colors.white : Colors.white.withValues(alpha: 0.2),
            ),
            child: Icon(
              icon,
              color: active ? Colors.black : Colors.white,
              size: 24,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
