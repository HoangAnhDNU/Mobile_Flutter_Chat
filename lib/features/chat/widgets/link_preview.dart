import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';

class LinkPreview extends StatefulWidget {
  final String url;
  final bool isMe;

  const LinkPreview({
    super.key,
    required this.url,
    required this.isMe,
  });

  @override
  State<LinkPreview> createState() => _LinkPreviewState();
}

class _LinkPreviewState extends State<LinkPreview>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _metadata;
  bool _loading = true;
  bool _failed = false;

  static final _cache = <String, Map<String, dynamic>?>{};

  @override
  void initState() {
    super.initState();
    _fetchPreview();
  }

  Future<void> _fetchPreview() async {
    if (_cache.containsKey(widget.url)) {
      final cached = _cache[widget.url];
      if (cached == null) {
        if (mounted) setState(() { _loading = false; _failed = true; });
        return;
      }
      if (mounted) setState(() { _metadata = cached; _loading = false; });
      return;
    }

    final data = await ApiService.getLinkPreview(widget.url);
    _cache[widget.url] = data;
    if (mounted) {
      setState(() {
        _metadata = data;
        _loading = false;
        _failed = data == null || (data['title'] == null && data['image'] == null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _buildSkeleton();
    }
    if (_failed || _metadata == null) {
      return const SizedBox.shrink();
    }

    final title = _metadata!['title']?.toString() ?? '';
    final description = _metadata!['description']?.toString() ?? '';
    final image = _metadata!['image']?.toString();
    final siteName = _metadata!['siteName']?.toString() ?? '';

    if (title.isEmpty && image == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.isMe
              ? Colors.white.withValues(alpha: 0.3)
              : AppColors.textSecondary.withValues(alpha: 0.2),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (image != null && image.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: CachedNetworkImage(
                imageUrl: image,
                width: 200,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 120,
                  color: widget.isMe
                      ? Colors.white.withValues(alpha: 0.1)
                      : AppColors.textSecondary.withValues(alpha: 0.1),
                ),
                errorWidget: (context, url, error) => const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: widget.isMe ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.isMe
                          ? Colors.white.withValues(alpha: 0.8)
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
                if (siteName.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.link,
                        size: 12,
                        color: widget.isMe
                            ? Colors.white.withValues(alpha: 0.6)
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          siteName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: widget.isMe
                                ? Colors.white.withValues(alpha: 0.6)
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return const SizedBox.shrink();
  }
}
