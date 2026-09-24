import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/post_response.dart';

class AuthProvider with ChangeNotifier {
  String? _accessToken;
  String? _tenantName;
  String? _tenantCode;
  int? _tenantId;
  String? _username;
  bool _isLoading = false;

  String? get accessToken => _accessToken;
  String? get tenantName => _tenantName;
  String? get tenantCode => _tenantCode;
  int? get tenantId => _tenantId;
  String? get username => _username;
  bool get isAuthenticated => _accessToken != null;
  bool get isLoading => _isLoading;

  Future<PostResponse> login(String tenantCode, String username, String password) async {
    _isLoading = true;
    notifyListeners();

    List<String> candidateUrls = [
      'https://villageshop-api.onrender.com/api',
      ApiConfig.baseUrl,
      ...ApiConfig.candidateUrls,
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
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          final postResp = PostResponse.fromJson(json);

          if (postResp.status) {
            final tokenData = jsonDecode(postResp.additionalMessage);
            _accessToken = tokenData['accessToken'];
            _tenantName = tokenData['tenantName'];
            _tenantCode = tokenData['tenantCode'] ?? tenantCode;
            _tenantId = tokenData['tenantId'];
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
      message: 'Connection Error: Unable to reach Cloud backend. Please check internet connection or Server API URL.',
      redirectURL: '',
      id: 0,
      additionalMessage: '',
    );
  }

  void logout() {
    _accessToken = null;
    _tenantName = null;
    _tenantCode = null;
    _tenantId = null;
    _username = null;
    notifyListeners();
  }
}
