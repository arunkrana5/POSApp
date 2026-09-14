import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/post_response.dart';

class AuthProvider with ChangeNotifier {
  String? _accessToken;
  String? _tenantName;
  String? _username;
  bool _isLoading = false;

  String? get accessToken => _accessToken;
  String? get tenantName => _tenantName;
  String? get username => _username;
  bool get isAuthenticated => _accessToken != null;
  bool get isLoading => _isLoading;

  Future<PostResponse> login(String tenantCode, String username, String password) async {
    _isLoading = true;
    notifyListeners();

    List<String> candidateUrls = [
      ApiConfig.baseUrl,
      ...ApiConfig.candidateUrls,
      'http://192.168.0.208:5000/api',
      'http://192.168.137.1:5000/api',
      'http://127.0.0.1:5000/api',
    ];
    candidateUrls = candidateUrls.toSet().toList();

    for (String base in candidateUrls) {
      try {
        final url = Uri.parse('$base/auth/login');
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'tenantCode': tenantCode,
            'username': username,
            'password': password,
          }),
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          final postResp = PostResponse.fromJson(json);

          if (postResp.status) {
            final tokenData = jsonDecode(postResp.additionalMessage);
            _accessToken = tokenData['accessToken'];
            _tenantName = tokenData['tenantName'];
            _username = tokenData['username'];
            ApiConfig.baseUrl = base;
          }

          _isLoading = false;
          notifyListeners();
          return postResp;
        }
      } catch (_) {
        // Fallback to next candidate IP
      }
    }

    _isLoading = false;
    notifyListeners();
    return PostResponse(
      viewAsString: '',
      status: false,
      statusCode: 500,
      message: 'Connection Error: Make sure phone is on same Wi-Fi as PC (http://192.168.1.34:5000) or check server connection settings.',
      redirectURL: '',
      id: 0,
      additionalMessage: '',
    );
  }

  void logout() {
    _accessToken = null;
    _tenantName = null;
    _username = null;
    notifyListeners();
  }
}
