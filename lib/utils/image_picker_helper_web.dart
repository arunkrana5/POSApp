import 'dart:async';
import 'dart:html' as html;

Future<String?> pickProductImageWeb() async {
  final Completer<String?> completer = Completer<String?>();
  final html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
  uploadInput.accept = 'image/*';
  uploadInput.style.display = 'none';

  // Must append to document body for cross-browser DOM file dialog permission
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
      reader.readAsDataUrl(file);
      reader.onLoadEnd.listen((e) {
        final result = reader.result;
        if (result is String) {
          try {
            final img = html.ImageElement();
            img.onLoad.listen((_) {
              try {
                final canvas = html.CanvasElement();
                int maxDim = 150;
                int w = img.width ?? maxDim;
                int h = img.height ?? maxDim;
                if (w > h) {
                  if (w > maxDim) {
                    h = ((h * maxDim) / w).round();
                    w = maxDim;
                  }
                } else {
                  if (h > maxDim) {
                    w = ((w * maxDim) / h).round();
                    h = maxDim;
                  }
                }
                canvas.width = w;
                canvas.height = h;
                final ctx = canvas.context2D;
                ctx.drawImageScaled(img, 0, 0, w, h);
                final compressedBase64 = canvas.toDataUrl('image/jpeg', 0.6);
                cleanup();
                if (!completer.isCompleted) completer.complete(compressedBase64);
              } catch (_) {
                cleanup();
                if (!completer.isCompleted) completer.complete(result);
              }
            });
            img.onError.listen((_) {
              cleanup();
              if (!completer.isCompleted) completer.complete(result);
            });
            img.src = result;

            Future.delayed(const Duration(milliseconds: 800), () {
              cleanup();
              if (!completer.isCompleted) {
                completer.complete(result);
              }
            });
          } catch (_) {
            cleanup();
            if (!completer.isCompleted) completer.complete(result);
          }
        } else {
          cleanup();
          if (!completer.isCompleted) completer.complete(null);
        }
      });
      reader.onError.listen((_) {
        cleanup();
        if (!completer.isCompleted) completer.complete(null);
      });
    } else {
      cleanup();
      if (!completer.isCompleted) completer.complete(null);
    }
  });

  // Trigger file picker dialog
  uploadInput.click();

  return completer.future;
}
