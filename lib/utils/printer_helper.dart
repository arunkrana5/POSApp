import 'printer_helper_stub.dart'
    if (dart.library.js_interop) 'printer_helper_web.dart';

class PrinterHelper {
  static void printHtml(String htmlContent) {
    printHtmlWeb(htmlContent);
  }
}
