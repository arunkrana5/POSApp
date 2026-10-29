import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';

Future<void> saveAndOpenFileNative(Uint8List bytes, String fileName, {String? mimeType}) async {
  try {
    // Printing.sharePdf works with arbitrary byte arrays on Android/iOS/Desktop
    // and launches the native share/save dialogue with the exact filename.
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  } catch (e) {
    debugPrint('Error sharing/saving file: $e');
    rethrow;
  }
}
