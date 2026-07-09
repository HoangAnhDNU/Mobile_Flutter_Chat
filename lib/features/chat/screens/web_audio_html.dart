// File nay CHI duoc load tren web (kIsWeb == true).
// Su dung dart:html va dart:js_util de doc blob URL (package:http khong xu ly duoc).
// Su dung conditional import tu chat_detail_screen.dart:
//   import 'web_audio_stub.dart' if (dart.library.html) 'web_audio_html.dart'
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:typed_data';
import 'dart:html' as html;

/// Đọc bytes từ blob URL trên web.
///
/// `package:http` không xử lý được scheme `blob:` nên không thể dùng
/// `http.get(Uri.parse(blobUrl))`. Hàm này dùng `fetch` thông qua
/// `dart:html` để lấy bytes trực tiếp từ Blob.
Future<Uint8List> readBlobBytes(String blobUrl) async {
  final completer = Completer<Uint8List>();
  try {
    final response = await html.window.fetch(blobUrl);
    final buffer = await response.arrayBuffer();
    final bytes = Uint8List.view(buffer as ByteBuffer);
    completer.complete(bytes);
  } catch (e) {
    completer.completeError(e);
  }
  return completer.future;
}