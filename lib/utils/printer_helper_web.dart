import 'dart:js_interop';

@JS('printHtml')
external void _printHtmlJS(JSString content);

void printHtmlWeb(String htmlContent) {
  try {
    _printHtmlJS(htmlContent.toJS);
  } catch (e) {
    // If JS function printHtml is missing, fallback safely
  }
}
