import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'excel_picker_helper.dart';

Future<PlatformExcelFile?> pickExcelFileNative() async {
  final completer = Completer<PlatformExcelFile?>();
  final uploadInput = html.FileUploadInputElement();
  uploadInput.accept = '.xlsx,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  uploadInput.style.display = 'none';

  html.document.body?.children.add(uploadInput);

  void cleanup() {
    try {
      uploadInput.remove();
    } catch (_) {}
  }

  uploadInput.onChange.listen((e) {
    final files = uploadInput.files;
    if (files != null && files.isNotEmpty) {
      final file = files[0];
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      reader.onLoadEnd.listen((_) {
        try {
          final result = reader.result;
          if (result is Uint8List) {
            completer.complete(PlatformExcelFile(
              name: file.name,
              size: file.size,
              bytes: result,
            ));
          } else if (result is ByteBuffer) {
            completer.complete(PlatformExcelFile(
              name: file.name,
              size: file.size,
              bytes: Uint8List.view(result),
            ));
          } else {
            completer.complete(null);
          }
        } catch (err) {
          completer.completeError(err);
        } finally {
          cleanup();
        }
      });
      reader.onError.listen((err) {
        cleanup();
        completer.completeError(err);
      });
    } else {
      cleanup();
      completer.complete(null);
    }
  });

  // Handle focus return when dialog is closed or cancelled
  void onFocus(html.Event event) {
    html.window.removeEventListener('focus', onFocus);
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!completer.isCompleted) {
        cleanup();
        completer.complete(null);
      }
    });
  }

  html.window.addEventListener('focus', onFocus);

  uploadInput.click();
  return completer.future;
}
