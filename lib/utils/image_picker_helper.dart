import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'image_picker_helper_stub.dart'
    if (dart.library.html) 'image_picker_helper_web.dart';

class ImagePickerHelper {
  static final ImagePicker _picker = ImagePicker();

  /// Picks image from file dialog on Web/Mobile and returns compressed base64 data URL (< 20 KB)
  static Future<String?> pickProductImage() async {
    if (kIsWeb) {
      return await pickProductImageWeb();
    }
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 200,
        maxHeight: 200,
        imageQuality: 60,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        final base64Str = base64Encode(bytes);
        return 'data:image/jpeg;base64,$base64Str';
      }
    } catch (_) {}
    return null;
  }
}
