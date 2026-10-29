import 'dart:typed_data';
import 'file_download_helper_stub.dart'
    if (dart.library.html) 'file_download_helper_web.dart';

class FileDownloadHelper {
  static Future<void> downloadFile({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    await saveAndOpenFileNative(bytes, fileName, mimeType: mimeType);
  }
}
