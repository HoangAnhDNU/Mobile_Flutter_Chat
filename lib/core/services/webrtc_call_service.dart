import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'socket_service.dart';

enum CallState { idle, offering, ringing, connected, ended, rejected, failed }

class WebRTCCallService {
  static WebRTCCallService? _instance;
  static WebRTCCallService get instance {
    _instance ??= WebRTCCallService._();
    return _instance!;
  }

  WebRTCCallService._();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  String? _targetUid;
  bool _isVideo = false;
  bool _isCaller = false;

  final _stateController = StreamController<CallState>.broadcast();
  final _localStreamController = StreamController<MediaStream?>.broadcast();
  final _remoteStreamController = StreamController<MediaStream?>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();

  Stream<CallState> get onStateChange => _stateController.stream;
  Stream<MediaStream?> get onLocalStream => _localStreamController.stream;
  Stream<MediaStream?> get onRemoteStream => _remoteStreamController.stream;
  Stream<Duration> get onDurationChange => _durationController.stream;

  CallState _state = CallState.idle;
  CallState get state => _state;
  bool get isVideo => _isVideo;
  bool get isCaller => _isCaller;
  String? get targetUid => _targetUid;

  Timer? _durationTimer;
  DateTime? _callStartTime;

  void _setState(CallState s) {
    _state = s;
    _stateController.add(s);
    debugPrint('[WebRTC] State: $s');
  }

  Future<void> initCall({
    required String myUid,
    required String targetUid,
    required bool isVideo,
    required String callerName,
    String? callerAvatar,
  }) async {
    debugPrint('[WebRTC] initCall: myUid=$myUid targetUid=$targetUid isVideo=$isVideo');
    // Clean up any previous call state
    _cleanup();
    _targetUid = targetUid;
    _isVideo = isVideo;
    _isCaller = true;

    await _setupPeerConnection();
    debugPrint('[WebRTC] Peer connection setup done');
    await _createLocalStream();
    debugPrint('[WebRTC] Local stream created, creating offer...');

    // Create offer
    final offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': isVideo,
    });
    await _peerConnection!.setLocalDescription(offer);
    debugPrint('[WebRTC] Offer created and set as local description');

    _setState(CallState.offering);

    // Send offer via signaling
    SocketService.instance.sendCallOffer(
      targetUid,
      isVideo,
      callerName,
      offer.toMap(),
      callerAvatar,
    );
  }

  Future<void> acceptCall({
    required String myUid,
    required String callerUid,
    required bool isVideo,
    required Map<String, dynamic> sdp,
  }) async {
    // acceptCall
    _cleanup();
    _targetUid = callerUid;
    _isVideo = isVideo;
    _isCaller = false;

    await _setupPeerConnection();
    await _createLocalStream();

    // Set remote description (the offer)
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(sdp['sdp'] ?? '', sdp['type'] ?? 'offer'),
    );

    // Create answer
    final answer = await _peerConnection!.createAnswer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': isVideo,
    });
    await _peerConnection!.setLocalDescription(answer);

    // Send answer via signaling
    SocketService.instance.sendCallAnswer(callerUid, answer.toMap());
  }

  Future<void> _setupPeerConnection() async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
    };

    _peerConnection = await createPeerConnection(config, {});

    _peerConnection!.onIceCandidate = (candidate) {
      if (_targetUid != null) {
        SocketService.instance.sendCallIceCandidate(_targetUid!, candidate.toMap());
      }
    };

    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        _remoteStreamController.add(_remoteStream);
        _setState(CallState.connected);
        _startDurationTimer();
      }
    };

    _peerConnection!.onConnectionState = (state) {
      debugPrint('[WebRTC] Connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _setState(CallState.failed);
        endCall();
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateClosed && _state == CallState.connected) {
        _setState(CallState.ended);
      }
    };
  }

  Future<void> _createLocalStream() async {
    final mediaConstraints = {
      'audio': true,
      'video': _isVideo
          ? {
              'mandatory': {
                'minWidth': '640',
                'minHeight': '480',
                'minFrameRate': '30',
              },
              'facingMode': 'user',
              'optional': [],
            }
          : false,
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      _localStreamController.add(_localStream);

      // Add tracks to peer connection
      for (final track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }
    } catch (e) {
      debugPrint('[WebRTC] Error getting user media: $e');
      _setState(CallState.failed);
    }
  }

  void handleRemoteAnswer(Map<String, dynamic> data) {
    if (_peerConnection == null) return;
    final sdp = data['sdp'];
    final type = data['type'] ?? 'answer';
    _peerConnection!.setRemoteDescription(
      RTCSessionDescription(sdp ?? '', type),
    );
  }

  void handleRemoteIceCandidate(Map<String, dynamic> data) {
    if (_peerConnection == null) return;
    final candidate = data['candidate'];
    if (candidate != null) {
      final c = candidate as Map;
      _peerConnection!.addCandidate(
        RTCIceCandidate(
          c['candidate'] ?? '',
          c['sdpMid'] ?? '',
          c['sdpMLineIndex'] ?? 0,
        ),
      );
    }
  }

  void toggleMute(bool muted) {
    if (_localStream != null) {
      for (final track in _localStream!.getAudioTracks()) {
        track.enabled = !muted;
      }
    }
  }

  void toggleCamera(bool enabled) {
    if (_localStream != null) {
      for (final track in _localStream!.getVideoTracks()) {
        track.enabled = enabled;
      }
    }
  }

  void _startDurationTimer() {
    _callStartTime = DateTime.now();
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_callStartTime != null) {
        _durationController.add(DateTime.now().difference(_callStartTime!));
      }
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _callStartTime = null;
  }

  void endCall() {
    // endCall
    if (_targetUid != null) {
      SocketService.instance.sendCallEnd(_targetUid!);
    }
    _cleanup();
    _setState(CallState.ended);
  }

  void rejectCall() {
    if (_targetUid != null) {
      SocketService.instance.sendCallReject(_targetUid!);
    }
    _cleanup();
    _setState(CallState.rejected);
  }

  void handleCallEnded() {
    _cleanup();
    _setState(CallState.ended);
  }

  void handleCallRejected() {
    _cleanup();
    _setState(CallState.rejected);
  }

  void _cleanup() {
    _stopDurationTimer();
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        track.stop();
      }
      _localStream!.dispose();
      _localStream = null;
    }
    if (_peerConnection != null) {
      _peerConnection!.close();
      _peerConnection = null;
    }
    _remoteStream = null;
    _targetUid = null;
    _localStreamController.add(null);
    _remoteStreamController.add(null);
  }

  void dispose() {
    _cleanup();
    _stateController.close();
    _localStreamController.close();
    _remoteStreamController.close();
    _durationController.close();
    _instance = null;
  }
}
