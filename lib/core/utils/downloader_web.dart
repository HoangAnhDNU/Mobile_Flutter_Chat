// Triển khai tải file cho web bằng thẻ <a download>.
import 'dart:html' as html;

void downloadDataUriImpl(String dataUri, String filename) {
  final anchor = html.AnchorElement(href: dataUri)
    ..download = filename
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}
