import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/constants/app_config.dart';
import '../../../core/utils/downloader.dart';

/// Màn xem ảnh phóng to (zoom) kèm nút tải về.
class ImageViewerScreen extends StatelessWidget {
  final String imageSource; // data URI hoặc URL http

  const ImageViewerScreen({super.key, required this.imageSource});

  bool get _isDataUri => imageSource.startsWith('data:');

  @override
  Widget build(BuildContext context) {
    final resolved = AppConfig.resolveMediaUrl(imageSource);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Hình ảnh'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Tải về',
            onPressed: () {
              final uri = _isDataUri ? imageSource : resolved;
              final ts = DateTime.now().millisecondsSinceEpoch;
              downloadDataUri(uri, 'anh_$ts.png');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đang tải ảnh về máy...')),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: _isDataUri
              ? Image.memory(base64Decode(imageSource.split(',').last))
              : Image.network(resolved),
        ),
      ),
    );
  }
}
