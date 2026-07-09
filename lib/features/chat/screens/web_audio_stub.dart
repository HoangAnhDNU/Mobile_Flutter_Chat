import 'dart:typed_data';

/// Stub cho mobile/desktop — `_stopRecordingAndSend` chỉ gọi hàm này
/// trên web, các nền tảng khác dùng nhánh đọc file riêng.
Future<Uint8List> readBlobBytes(String blobUrl) async => Uint8List(0);