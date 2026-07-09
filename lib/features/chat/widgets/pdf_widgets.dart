import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class PdfAttachmentPreview extends StatelessWidget {
  final String pdfDataUri; // data URI base64 của PDF
  final String fileName;
  final String fileSize;
  final VoidCallback? onRemove;
  final Function(String dataUri, String name)? onConfirm;
  final bool isMe;

  const PdfAttachmentPreview({
    super.key,
    required this.pdfDataUri,
    required this.fileName,
    required this.fileSize,
    this.onRemove,
    this.onConfirm,
    this.isMe = false,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = isMe ? Colors.white : AppColors.primary;
    final bgColor = isMe ? AppColors.primary : const Color(0xFFEEEEEE);
    final textColor = isMe ? Colors.white : AppColors.textPrimary;

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.65,
      ),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        fileSize,
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
          ),
          if (onConfirm != null)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isMe ? Colors.white24 : Colors.grey.shade300,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  if (onRemove != null)
                    Expanded(
                      child: TextButton.icon(
                        onPressed: onRemove,
                        icon: Icon(Icons.close, size: 18, color: isMe ? Colors.white70 : AppColors.textSecondary),
                        label: Text(
                          'Hủy',
                          style: TextStyle(color: isMe ? Colors.white70 : AppColors.textSecondary, fontSize: 13),
                        ),
                      ),
                    ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => onConfirm?.call(pdfDataUri, fileName),
                      icon: Icon(Icons.send, size: 18, color: primaryColor),
                      label: Text(
                        'Gửi',
                        style: TextStyle(color: primaryColor, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class PdfAttachmentTile extends StatelessWidget {
  final String fileName;
  final String fileSize;
  final VoidCallback? onTap;
  final VoidCallback? onDownload;
  final bool isMe;

  const PdfAttachmentTile({
    super.key,
    required this.fileName,
    required this.fileSize,
    this.onTap,
    this.onDownload,
    this.isMe = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary.withValues(alpha: 0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fileName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    fileSize,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (onDownload != null) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.download, size: 20),
                onPressed: onDownload,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Tải về',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
