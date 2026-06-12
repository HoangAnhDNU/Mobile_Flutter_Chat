import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';

class MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final String senderName;
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
  final VoidCallback? onSwipeReply;

  const MessageBubble({
    super.key,
    required this.text,
    required this.isMe,
    required this.senderName,
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
    this.onSwipeReply,
  });

  @override
  Widget build(BuildContext context) {
    Widget bubble = Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
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
              maxWidth: MediaQuery.of(context).size.width * 0.75,
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
                if (replyToText != null && replyToText!.isNotEmpty)
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
                if (type == 'image' && imageBase64 != null)
                  GestureDetector(
                    onTap: () => _openFullScreenImage(context, MemoryImage(base64Decode(imageBase64!))),
                    child: Hero(
                      tag: 'img_${imageBase64.hashCode}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          base64Decode(imageBase64!),
                          width: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                  )
                else if (type == 'image' && imageUrl != null)
                  GestureDetector(
                    onTap: () => _openFullScreenImage(context, CachedNetworkImageProvider(imageUrl!)),
                    child: Hero(
                      tag: 'img_${imageUrl.hashCode}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl!,
                          width: 200,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const SizedBox(
                            width: 200,
                            height: 150,
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                          errorWidget: (context, url, error) => const Icon(Icons.error),
                        ),
                      ),
                    ),
                  )
                else if (type == 'voice')
                  _buildVoiceBubble()
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
                    if (isEdited)
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
          if (reactions.isNotEmpty)
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
        child: GestureDetector(onLongPress: onLongPress, child: bubble),
      );
    }

    return GestureDetector(onLongPress: onLongPress, child: bubble);
  }

  Widget _buildDeliveryIcon() {
    switch (deliveryStatus) {
      case 'read':
        return const Icon(Icons.done_all, size: 14, color: Colors.lightBlueAccent);
      case 'delivered':
        return Icon(Icons.done_all, size: 14, color: Colors.white70);
      default:
        return Icon(Icons.done, size: 14, color: Colors.white70);
    }
  }

  Widget _buildVoiceBubble() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.play_arrow, color: isMe ? Colors.white : AppColors.primary),
        const SizedBox(width: 8),
        Container(
          width: 120,
          height: 4,
          decoration: BoxDecoration(
            color: isMe ? Colors.white30 : Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.mic, size: 16, color: isMe ? Colors.white70 : AppColors.textSecondary),
      ],
    );
  }

  bool _containsUrl(String text) {
    final urlRegex = RegExp(r'https?://[^\s]+');
    return urlRegex.hasMatch(text);
  }

  Widget _buildLinkPreview() {
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
    for (final r in reactions) {
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
    if (timestamp == null) return '';
    return '${timestamp!.hour.toString().padLeft(2, '0')}:${timestamp!.minute.toString().padLeft(2, '0')}';
  }

  void _openFullScreenImage(BuildContext context, ImageProvider imageProvider) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenImageView(imageProvider: imageProvider),
      ),
    );
  }
}

class _FullScreenImageView extends StatelessWidget {
  final ImageProvider imageProvider;

  const _FullScreenImageView({required this.imageProvider});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image(image: imageProvider, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
