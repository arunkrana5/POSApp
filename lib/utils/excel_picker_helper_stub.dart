import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'excel_picker_helper.dart';

Future<PlatformExcelFile?> pickExcelFileNative() async {
  FilePickerResult? result;
  try {
    result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: false,
    );
  } catch (_) {
    result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: false,
    );
  }

  if (result != null && result.files.isNotEmpty) {
    final file = result.files.first;
    if (file.path != null && file.path!.isNotEmpty) {
      final ioFile = File(file.path!);
      final size = await ioFile.length();
      return PlatformExcelFile(
        name: file.name,
        size: size,
        path: file.path,
      );
    } else if (file.bytes != null) {
      return PlatformExcelFile(
        name: file.name,
        size: file.bytes!.length,
        bytes: file.bytes,
      );
    }
  }
  return null;
}
