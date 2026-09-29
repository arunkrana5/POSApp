import 'dart:html' as html;
import 'package:flutter/foundation.dart';

class ApiConfig {
  static String? _customBaseUrl;

  static String get baseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }
    if (kIsWeb) {
      try {
        final origin = html.window.location.origin;
        if (origin.isNotEmpty && !origin.startsWith('file:')) {
          return '$origin/api';
        }
      } catch (_) {}
    }
    return 'http://185.100.212.57:5000/api';
  }

  static set baseUrl(String value) {
    _customBaseUrl = value;
  }

  static List<String> get candidateUrls {
    final list = <String>[];
    if (kIsWeb) {
      try {
        final origin = html.window.location.origin;
        if (origin.isNotEmpty && !origin.startsWith('file:')) {
          list.add('$origin/api');
        }
      } catch (_) {}
    }
    list.addAll([
      'http://localhost:5000/api',
      'http://185.100.212.57:5000/api',
      'https://villageshop-api.onrender.com/api',
    ]);
    return list.toSet().toList();
  }
}
