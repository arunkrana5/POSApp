import 'dart:async';
import 'dart:html' as html;

Future<String?> pickProductImageWeb() async {
  final Completer<String?> completer = Completer<String?>();
  final html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
  uploadInput.accept = 'image/*';
  uploadInput.click();

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
            // Attach listeners BEFORE setting img.src to avoid race condition
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
                if (!completer.isCompleted) completer.complete(compressedBase64);
              } catch (_) {
                if (!completer.isCompleted) completer.complete(result);
              }
            });
            img.onError.listen((_) {
              if (!completer.isCompleted) completer.complete(result);
            });
            img.src = result;

            // Fallback: if img.onLoad doesn't fire within 800ms, complete with result
            Future.delayed(const Duration(milliseconds: 800), () {
              if (!completer.isCompleted) {
                completer.complete(result);
              }
            });
          } catch (_) {
            if (!completer.isCompleted) completer.complete(result);
          }
        } else {
          if (!completer.isCompleted) completer.complete(null);
        }
      });
      reader.onError.listen((_) {
        if (!completer.isCompleted) completer.complete(null);
      });
    } else {
      if (!completer.isCompleted) completer.complete(null);
    }
  });

  return completer.future;
}
