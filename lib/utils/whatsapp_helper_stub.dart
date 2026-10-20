import 'package:url_launcher/url_launcher.dart';

void openWhatsAppUrlPlatform(String url) async {
  try {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}
