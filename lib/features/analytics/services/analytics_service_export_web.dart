// Web implementation — uses dart:html to trigger browser download
import 'dart:html' as html;

void downloadBytes(List<int> bytes, String fileName) {
  final blob    = html.Blob([bytes]);
  final urlBlob = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: urlBlob)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(urlBlob);
}
