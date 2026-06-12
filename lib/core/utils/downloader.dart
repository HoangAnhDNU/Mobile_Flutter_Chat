// Helper tải media (data URI base64) về máy.
// Dùng conditional import: web dùng dart:html, nền tảng khác dùng stub.
import 'downloader_stub.dart'
    if (dart.library.html) 'downloader_web.dart';

/// Tải một data URI (vd: data:image/png;base64,....) về máy với tên gợi ý.
void downloadDataUri(String dataUri, String filename) {
  downloadDataUriImpl(dataUri, filename);
}
