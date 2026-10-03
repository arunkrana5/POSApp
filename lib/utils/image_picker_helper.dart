import 'package:flutter/foundation.dart';
import 'image_picker_helper_stub.dart'
    if (dart.library.html) 'image_picker_helper_web.dart';

class ImagePickerHelper {
  /// Picks image from file dialog on Web/Mobile and returns base64 data URL
  static Future<String?> pickProductImage() async {
    if (kIsWeb) {
      return await pickProductImageWeb();
    }
    return null;
  }
}
