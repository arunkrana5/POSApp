import 'dart:typed_data';
import 'excel_picker_helper_stub.dart'
    if (dart.library.html) 'excel_picker_helper_web.dart';

class PlatformExcelFile {
  final String name;
  final int size;
  final Uint8List? bytes;
  final String? path;

  PlatformExcelFile({
    required this.name,
    required this.size,
    this.bytes,
    this.path,
  });
}

class ExcelPickerHelper {
  static Future<PlatformExcelFile?> pickExcelFile() async {
    return await pickExcelFileNative();
  }
}
