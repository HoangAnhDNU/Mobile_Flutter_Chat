// Triển khai tải file cho web bằng thẻ <a download>.
import 'package:web/web.dart' as web;

void downloadDataUriImpl(String dataUri, String filename) {
  final anchor = web.HTMLAnchorElement()
    ..href = dataUri
    ..download = filename
    ..style.display = 'none';
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
}
