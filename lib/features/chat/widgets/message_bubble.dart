import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_config.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/utils/time_utils.dart';
import '../../../core/utils/downloader.dart';
import '../../../core/utils/web_opener.dart' if (dart.library.html) '../../../core/utils/web_opener_web.dart';
import '../screens/image_viewer_screen.dart';
import '../screens/pdf_viewer_screen.dart';

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
  final String? fileName;
  final VoidCallback? onLongPress;
  final String deliveryStatus;
  final String? replyToText;
  final String? replyToSender;
  final List<Map<String, dynamic>> reactions;
  final bool isPinned;
  final bool isDeleted;
  final bool forwarded;
  final int? voiceDuration;
  final VoidCallback? onSwipeReply;
  final String? imageLabel;
  final String? fakeNewsLabel;
  final List<String> mentions;
  final List<String> mentionNames;

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
    this.fileName,
    this.onLongPress,
    this.deliveryStatus = 'sent',
    this.replyToText,
    this.replyToSender,
    this.reactions = const [],
    this.isPinned = false,
    this.isDeleted = false,
    this.forwarded = false,
    this.voiceDuration,
    this.onSwipeReply,
    this.imageLabel,
    this.fakeNewsLabel,
    this.mentions = const [],
    this.mentionNames = const [],
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
    
    final isEdited = widget.isEdited;
    final imageUrl = widget.imageUrl;
    final imageBase64 = widget.imageBase64;
    final type = widget.type;
    final onLongPress = widget.onLongPress;
    final replyToText = widget.replyToText;
    final replyToSender = widget.replyToSender;
    final reactions = widget.reactions;
    final isPinned = widget.isPinned;
    final isDeleted = widget.isDeleted;
    final forwarded = widget.forwarded;
    final voiceDuration = widget.voiceDuration;
    final onSwipeReply = widget.onSwipeReply;
    Widget bubbleContent = Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (forwarded)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shortcut, size: 12, color: AppColors.textSecondary),
                const SizedBox(width: 2),
                Text('Tin nhắn chuyển tiếp', style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        if (isPinned)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.push_pin, size: 12, color: AppColors.textSecondary),
                const SizedBox(width: 2),
                Text(AppLocalizations.of(context).translate('pinned'), style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              ],
            ),
          ),
        Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
          ),
          margin: EdgeInsets.zero,
          padding: EdgeInsets.symmetric(
            horizontal: isDeleted ? 10 : 14,
            vertical: isDeleted ? 6 : 10,
          ),
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
              mainAxisSize: MainAxisSize.min,
              children: [
              if (!isDeleted && replyToText != null && replyToText.isNotEmpty)
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
                        replyToText,
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.block, size: 15, color: isMe ? Colors.white70 : AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      AppLocalizations.of(context).translate('message_recalled'),
                      style: TextStyle(
                        color: isMe ? Colors.white70 : AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
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
                        final src = (imageBase64 != null && imageBase64.isNotEmpty)
                            ? (imageBase64.startsWith('data:') ? imageBase64 : 'data:image/png;base64,$imageBase64')
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
                    if (widget.fakeNewsLabel != null && widget.fakeNewsLabel!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.fakeNewsLabel == 'True'
                                  ? Icons.verified_rounded
                                  : Icons.warning_amber_rounded,
                              size: 14,
                              color: widget.fakeNewsLabel == 'True'
                                  ? (isMe ? Colors.white70 : Colors.green)
                                  : Colors.orangeAccent,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Fake news: ${widget.fakeNewsLabel!}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: widget.fakeNewsLabel == 'True'
                                      ? (isMe ? Colors.white70 : Colors.green)
                                      : Colors.orangeAccent,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                )
              else if (type == 'voice')
                VoiceMessagePlayer(
                  source: (imageUrl != null && imageUrl.isNotEmpty) ? imageUrl : '',
                  isMe: isMe,
                  durationMs: voiceDuration,
                )
              else if (type == 'file' && (imageUrl != null || imageBase64 != null))
                _buildPdfAttachment(imageUrl ?? '', imageBase64, isMe)
              else if (type == 'call')
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      text.contains('nhỡ') ? Icons.call_missed
                          : text.contains('từ chối') ? Icons.call_end
                          : text.contains('hủy') ? Icons.call_end
                          : text.contains('video') ? Icons.videocam
                          : Icons.call,
                      size: 16,
                      color: text.contains('nhỡ') || text.contains('từ chối') || text.contains('hủy')
                          ? Colors.red
                          : (isMe ? Colors.white70 : AppColors.primary),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        text,
                        style: TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: isMe ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                )
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextWithLinks(text, isMe),
                  ],
                ),
              if (!isDeleted)
                const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isEdited && !isDeleted)
                    Text(
                      AppLocalizations.of(context).translate('edited'),
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
            margin: EdgeInsets.zero,
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
            // Flexible/flex=1 để bubble tự co lại khi còn người gửi khác.
            Flexible(flex: 1, child: messageWithAvatarWrap(bubbleContent)),
          ] else
            Flexible(flex: 1, child: messageWithAvatarWrap(bubbleContent)),
        ],
      ),
    );

    if (onSwipeReply != null) {
      return Dismissible(
        key: UniqueKey(),
        direction: isMe ? DismissDirection.endToStart : DismissDirection.startToEnd,
        confirmDismiss: (direction) async {
          onSwipeReply.call();
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

  void _openInNewTab(String url) {
    if (kIsWeb) {
      openInNewTab(url);
    }
  }

  Widget _buildTextWithLinks(String text, bool isMe) {
    final urlRegex = RegExp(r'https?://[^\s]+');
    final urlMatches = urlRegex.allMatches(text);

    // Find mention positions by searching for @name for each known mention name
    final mentionPositions = <_MatchPos>[];
    for (final name in widget.mentionNames) {
      final searchStr = '@$name';
      int start = 0;
      while (true) {
        final idx = text.indexOf(searchStr, start);
        if (idx == -1) break;
        mentionPositions.add(_MatchPos(idx, idx + searchStr.length));
        start = idx + searchStr.length;
      }
    }

    if (urlMatches.isEmpty && mentionPositions.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          color: isMe ? Colors.white : AppColors.textPrimary,
          fontSize: 15,
        ),
      );
    }

    final spans = <TextSpan>[];
    int lastEnd = 0;

    final allMatches = <_MatchPos>[
      ...urlMatches.map((m) => _MatchPos(m.start, m.end)),
      ...mentionPositions,
    ];
    allMatches.sort((a, b) => a.start.compareTo(b.start));

    for (final match in allMatches) {
      if (match.start < lastEnd) continue;
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: TextStyle(
            color: isMe ? Colors.white : AppColors.textPrimary,
            fontSize: 15,
          ),
        ));
      }
      final matched = text.substring(match.start, match.end);
      final isUrl = matched.startsWith('http');
      if (isUrl) {
        spans.add(TextSpan(
          text: matched,
          style: TextStyle(
            color: isMe ? Colors.lightBlueAccent : AppColors.primary,
            fontSize: 15,
            decoration: TextDecoration.underline,
            decorationColor: isMe ? Colors.lightBlueAccent : AppColors.primary,
            decorationThickness: 0.5,
            height: 1.4,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              final uri = Uri.parse(matched);
              String? code;
              if (uri.queryParameters['code'] != null) {
                code = uri.queryParameters['code'];
              } else if (uri.fragment.contains('code=')) {
                final fragQuery = uri.fragment.substring(uri.fragment.indexOf('?') + 1);
                code = Uri.splitQueryString(fragQuery)['code'];
              }
              if (code != null && code.isNotEmpty && uri.fragment.contains('join-group')) {
                Navigator.pushNamed(
                  context,
                  AppRoutes.joinGroup,
                  arguments: {'code': code},
                );
              } else {
                String openUrl = matched;
                if (uri.host.contains('youtube.com') && uri.queryParameters['v'] != null) {
                  openUrl = 'https://www.youtube.com/embed/${uri.queryParameters['v']}';
                } else if (uri.host.contains('youtu.be')) {
                  final videoId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
                  if (videoId.isNotEmpty) {
                    openUrl = 'https://www.youtube.com/embed/$videoId';
                  }
                }
                if (kIsWeb) {
                  _openInNewTab(openUrl);
                }
              }
            },
        ));
      } else {
        spans.add(TextSpan(
          text: matched,
          style: TextStyle(
            color: isMe ? const Color(0xFFBBDEFB) : AppColors.primary,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ));
      }
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: TextStyle(
          color: isMe ? Colors.white : AppColors.textPrimary,
          fontSize: 15,
        ),
      ));
    }

    return Text.rich(
      TextSpan(children: spans),
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

  Widget _buildPdfAttachment(String pdfUrl, String? pdfBase64, bool isMe) {
    final src = (pdfBase64 != null && pdfBase64.isNotEmpty)
        ? pdfBase64
        : pdfUrl;
    // Extract filename from widget.fileName or widget.text
    final fileName = widget.fileName ?? (widget.text.isNotEmpty && widget.text.length < 200
        ? widget.text
        : 'document.pdf');
    
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfViewerScreen(
              pdfSource: src,
              fileName: fileName,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 240),
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.picture_as_pdf,
                  color: isMe ? Colors.white : Colors.red,
                  size: 32,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isMe ? Colors.white : AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'PDF',
                        style: TextStyle(
                          fontSize: 12,
                          color: isMe ? Colors.white70 : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.visibility,
                  size: 16,
                  color: isMe ? Colors.white70 : AppColors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Tap de xem',
                  style: TextStyle(
                    fontSize: 12,
                    color: isMe ? Colors.white70 : AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
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
      SnackBar(content: Text(AppLocalizations.of(context).translate('downloading_audio'))),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '$m:${s.toString().padLeft(2, '0')}';
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
        Text(
          _formatDuration(total),
          style: TextStyle(
            fontSize: 12,
            color: widget.isMe ? Colors.white70 : AppColors.textSecondary,
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

class _MatchPos {
  final int start;
  final int end;
  _MatchPos(this.start, this.end);
}
