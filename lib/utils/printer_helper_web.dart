import 'dart:js_interop';

@JS('printHtml')
external void _printHtmlJS(JSString content);

Future<void> printHtmlWeb(String htmlContent) async {
  try {
    _printHtmlJS(htmlContent.toJS);
  } catch (e) {
    // If JS function printHtml is missing, fallback safely
  }
}
