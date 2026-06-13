import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_config.dart';
import '../../../core/utils/time_utils.dart';
import '../../../core/utils/downloader.dart';
import '../screens/image_viewer_screen.dart';

class MessageBubble extends StatefulWidget {
  final String text;
  final bool isMe;
  final String senderName;
  final String? senderAvatar;
  final DateTime? timestamp;
  final bool isEdited;
  final String? imageUrl;
  final String? imageBase64;
  final String type;
  final VoidCallback? onLongPress;
  final String deliveryStatus;
  final String? replyToText;
  final String? replyToSender;
  final List<Map<String, dynamic>> reactions;
  final bool isPinned;
  final bool isDeleted;
  final int? voiceDuration;
  final VoidCallback? onSwipeReply;
  final String? imageLabel;

  const MessageBubble({
    super.key,
    required this.text,
    required this.isMe,
    required this.senderName,
    this.senderAvatar,
    this.timestamp,
    this.isEdited = false,
    this.imageUrl,
    this.imageBase64,
    this.type = 'text',
    this.onLongPress,
    this.deliveryStatus = 'sent',
    this.replyToText,
    this.replyToSender,
    this.reactions = const [],
    this.isPinned = false,
    this.isDeleted = false,
    this.voiceDuration,
    this.onSwipeReply,
    this.imageLabel,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  ImageProvider? _avatarProvider;
  ImageProvider? _imageProvider;

  static ImageProvider _buildProvider(String url) {
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
    _initProviders();
  }

  @override
  void didUpdateWidget(covariant MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.senderAvatar != widget.senderAvatar ||
        oldWidget.imageBase64 != widget.imageBase64 ||
        oldWidget.imageUrl != widget.imageUrl) {
      _initProviders();
    }
  }

  void _initProviders() {
    _avatarProvider = (widget.senderAvatar != null && widget.senderAvatar!.isNotEmpty)
        ? _buildProvider(widget.senderAvatar!)
        : null;
    final imgSrc = (widget.imageBase64 != null && widget.imageBase64!.isNotEmpty)
        ? widget.imageBase64!
        : widget.imageUrl;
    _imageProvider = (imgSrc != null && imgSrc.isNotEmpty) ? _buildProvider(imgSrc) : null;
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    final isMe = widget.isMe;
    final senderName = widget.senderName;
    final senderAvatar = widget.senderAvatar;
    final timestamp = widget.timestamp;
    final isEdited = widget.isEdited;
    final imageUrl = widget.imageUrl;
    final imageBase64 = widget.imageBase64;
    final type = widget.type;
    final onLongPress = widget.onLongPress;
    final deliveryStatus = widget.deliveryStatus;
    final replyToText = widget.replyToText;
    final replyToSender = widget.replyToSender;
    final reactions = widget.reactions;
    final isPinned = widget.isPinned;
    final isDeleted = widget.isDeleted;
    final voiceDuration = widget.voiceDuration;
    final onSwipeReply = widget.onSwipeReply;
    Widget bubbleContent = Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (isPinned)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.push_pin, size: 12, color: AppColors.textSecondary),
                const SizedBox(width: 2),
                Text('Đã ghim', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              ],
            ),
          ),
        Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
          ),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMe ? AppColors.primary : const Color(0xFFEEEEEE),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
              bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
            ),
          ),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isDeleted && replyToText != null && replyToText!.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                      left: BorderSide(color: isMe ? Colors.white70 : AppColors.primary, width: 3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        replyToSender ?? '',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isMe ? Colors.white70 : AppColors.primary,
                        ),
                      ),
                      Text(
                        replyToText!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isMe ? Colors.white60 : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              if (isDeleted)
                Row(
                  children: [
                    Icon(Icons.block, size: 15, color: isMe ? Colors.white70 : AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Tin nhắn đã được thu hồi',
                        style: TextStyle(
                          color: isMe ? Colors.white70 : AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                )
              else if (type == 'image' && (imageBase64 != null || imageUrl != null))
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        final src = (imageBase64 != null && imageBase64!.isNotEmpty)
                            ? (imageBase64!.startsWith('data:') ? imageBase64! : 'data:image/png;base64,$imageBase64')
                            : imageUrl!;
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ImageViewerScreen(imageSource: src)),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image(
                          image: _imageProvider!,
                          width: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                    if (widget.imageLabel != null && widget.imageLabel!.isNotEmpty && ['classroom', 'computerroom', 'library', 'corridor', 'office'].contains(widget.imageLabel))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          widget.imageLabel!,
                          style: TextStyle(
                            fontSize: 11,
                            color: isMe ? Colors.white70 : AppColors.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                )
              else if (type == 'voice')
                VoiceMessagePlayer(
                  source: (imageUrl != null && imageUrl!.isNotEmpty) ? imageUrl! : '',
                  isMe: isMe,
                  durationMs: voiceDuration,
                )
              else if (_containsUrl(text))
                _buildLinkPreview()
              else
                Text(
                  text,
                  style: TextStyle(
                    color: isMe ? Colors.white : AppColors.textPrimary,
                    fontSize: 15,
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isEdited && !isDeleted)
                    Text(
                      '(đã chỉnh sửa) ',
                      style: TextStyle(
                        fontSize: 10,
                        color: isMe ? Colors.white70 : AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  Text(
                    _formatTimestamp(),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe ? Colors.white70 : AppColors.textSecondary,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    _buildDeliveryIcon(),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (reactions.isNotEmpty && !isDeleted)
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: _buildReactionChips(),
            ),
          ),
      ],
    );

    Widget messageWithAvatar = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              backgroundImage: _avatarProvider,
              child: _avatarProvider == null
                  ? Text(
                      senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                      style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          messageWithAvatarWrap(bubbleContent),
        ],
      ),
    );

    if (onSwipeReply != null) {
      return Dismissible(
        key: UniqueKey(),
        direction: isMe ? DismissDirection.endToStart : DismissDirection.startToEnd,
        confirmDismiss: (direction) async {
          onSwipeReply?.call();
          return false;
        },
        background: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Icon(Icons.reply, color: AppColors.textSecondary),
          ),
        ),
        child: GestureDetector(onLongPress: onLongPress, child: messageWithAvatar),
      );
    }

    return GestureDetector(onLongPress: onLongPress, child: messageWithAvatar);
  }

  Widget messageWithAvatarWrap(Widget child) {
    return child;
  }

  Widget _buildDeliveryIcon() {
    switch (widget.deliveryStatus) {
      case 'read':
        return const Icon(Icons.done_all, size: 14, color: Colors.lightBlueAccent);
      case 'delivered':
        return Icon(Icons.done_all, size: 14, color: Colors.white70);
      default:
        return Icon(Icons.done, size: 14, color: Colors.white70);
    }
  }

  bool _containsUrl(String text) {
    final urlRegex = RegExp(r'https?://[^\s]+');
    return urlRegex.hasMatch(text);
  }

  Widget _buildLinkPreview() {
    final isMe = widget.isMe;
    final text = widget.text;
    final urlRegex = RegExp(r'https?://[^\s]+');
    final match = urlRegex.firstMatch(text);
    final url = match?.group(0) ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: TextStyle(
            color: isMe ? Colors.white : AppColors.textPrimary,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isMe ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link, size: 16, color: isMe ? Colors.white70 : AppColors.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isMe ? Colors.white70 : AppColors.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildReactionChips() {
    final Map<String, int> emojiCounts = {};
    for (final r in widget.reactions) {
      final emoji = r['emoji'] as String? ?? '';
      emojiCounts[emoji] = (emojiCounts[emoji] ?? 0) + 1;
    }
    return emojiCounts.entries.map((e) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Text('${e.key} ${e.value > 1 ? e.value : ''}', style: const TextStyle(fontSize: 14)),
      );
    }).toList();
  }

  String _formatTimestamp() {
    if (widget.timestamp == null) return '';
    return TimeUtils.formatTime(widget.timestamp!);
  }
}

/// Trình phát tin nhắn thoại: phát/tạm dừng ngay trong ứng dụng + tải về.
class VoiceMessagePlayer extends StatefulWidget {
  final String source; // data URI audio hoặc URL
  final bool isMe;
  final int? durationMs;

  const VoiceMessagePlayer({
    super.key,
    required this.source,
    required this.isMe,
    this.durationMs,
  });

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _total = d);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (widget.source.isEmpty) return;
    if (_isPlaying) {
      await _player.pause();
    } else {
      final src = widget.source;
      if (src.startsWith('data:')) {
        await _player.play(BytesSource(base64Decode(src.split(',').last)));
      } else {
        await _player.play(UrlSource(AppConfig.resolveMediaUrl(src)));
      }
    }
  }

  void _download() {
    if (widget.source.isEmpty) return;
    final ts = DateTime.now().millisecondsSinceEpoch;
    downloadDataUri(widget.source, 'amthanh_$ts.m4a');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đang tải âm thanh về máy...')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.isMe ? Colors.white : AppColors.primary;
    final total = _total.inMilliseconds > 0
        ? _total
        : Duration(milliseconds: widget.durationMs ?? 0);
    final progress = (total.inMilliseconds > 0)
        ? (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _toggle,
          child: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: fg, size: 30),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 110,
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: widget.isMe ? Colors.white30 : Colors.grey[300],
            valueColor: AlwaysStoppedAnimation(fg),
            minHeight: 3,
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _download,
          child: Icon(Icons.download, size: 18, color: widget.isMe ? Colors.white70 : AppColors.textSecondary),
        ),
      ],
    );
  }
}
