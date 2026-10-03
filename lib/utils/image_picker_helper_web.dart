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
          // Auto-compress using HTML5 Canvas to keep image under 20 KB (150px max dimension, 0.6 quality)
          final img = html.ImageElement();
          img.src = result;
          img.onLoad.listen((_) {
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
            completer.complete(compressedBase64);
          });
          img.onError.listen((_) {
            completer.complete(result);
          });
        } else {
          completer.complete(null);
        }
      });
      reader.onError.listen((_) {
        completer.complete(null);
      });
    } else {
      completer.complete(null);
    }
  });

  return completer.future;
}
