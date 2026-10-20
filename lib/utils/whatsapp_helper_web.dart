import 'dart:js_interop';

@JS('window.open')
external void _windowOpen(JSString url, JSString target);

void openWhatsAppUrlPlatform(String url) {
  try {
    _windowOpen(url.toJS, '_blank'.toJS);
  } catch (_) {}
}
