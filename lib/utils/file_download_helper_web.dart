import 'dart:html' as html;
import 'dart:typed_data';

Future<void> saveAndOpenFileNative(Uint8List bytes, String fileName, {String? mimeType}) async {
  final type = mimeType ?? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  final blob = html.Blob([bytes], type);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
