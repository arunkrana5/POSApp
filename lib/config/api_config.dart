import 'package:flutter/foundation.dart';

class ApiConfig {
  static String? _customBaseUrl;

  static String get baseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }
    if (kIsWeb) {
      try {
        final origin = Uri.base.origin;
        if (origin.contains('localhost') || origin.contains('127.0.0.1')) {
          return 'http://localhost:5000/api';
        }
        if (origin.contains('185.100.212.57')) {
          return 'http://185.100.212.57:5000/api';
        }
        return 'https://villageshop-api.onrender.com/api';
      } catch (_) {}
    }
    return 'https://villageshop-api.onrender.com/api';
  }

  static set baseUrl(String value) {
    _customBaseUrl = value;
  }

  static List<String> get candidateUrls {
    final list = <String>[];
    list.add('https://villageshop-api.onrender.com/api');
    if (kIsWeb) {
      try {
        final origin = Uri.base.origin;
        if (origin.contains('localhost') || origin.contains('127.0.0.1')) {
          list.insert(0, 'http://localhost:5000/api');
        } else if (origin.contains('185.100.212.57')) {
          list.insert(0, 'http://185.100.212.57:5000/api');
        }
      } catch (_) {}
    }
    list.addAll([
      'https://villageshop-api.onrender.com/api',
      'http://localhost:5000/api',
      'http://185.100.212.57:5000/api',
    ]);
    return list.toSet().toList();
  }
}
