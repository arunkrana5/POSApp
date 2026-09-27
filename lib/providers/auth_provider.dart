import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/post_response.dart';

class AuthProvider with ChangeNotifier {
  String? _accessToken;
  String? _tenantName;
  String? _tenantCode;
  int? _tenantId;
  String? _username;
  bool _isLoading = false;
  bool _isInitialized = false;

  String? get accessToken => _accessToken;
  String? get tenantName => _tenantName;
  String? get tenantCode => _tenantCode;
  int? get tenantId => _tenantId;
  String? get username => _username;
  bool get isAuthenticated => _accessToken != null && _accessToken!.isNotEmpty;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString('auth_token');
      _tenantName = prefs.getString('tenant_name');
      _tenantCode = prefs.getString('tenant_code');
      _tenantId = prefs.getInt('tenant_id');
      _username = prefs.getString('username');
    } catch (_) {}
    _isInitialized = true;
    notifyListeners();
  }

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
            final Map<String, dynamic> tokenData = jsonDecode(postResp.additionalMessage);
            _accessToken = tokenData['accessToken'] ?? tokenData['AccessToken'];
            _tenantName = tokenData['tenantName'] ?? tokenData['TenantName'] ?? tokenData['name'] ?? tokenData['Name'];
            _tenantCode = tokenData['tenantCode'] ?? tokenData['TenantCode'] ?? tenantCode;

            final rawId = tokenData['tenantId'] ?? tokenData['TenantId'] ?? tokenData['id'] ?? tokenData['Id'];
            if (rawId != null) {
              try { _tenantId = int.parse(rawId.toString()); } catch (_) {}
            }

            _username = tokenData['username'] ?? tokenData['Username'];
            ApiConfig.baseUrl = base;

            try {
              final prefs = await SharedPreferences.getInstance();
              if (_accessToken != null) await prefs.setString('auth_token', _accessToken!);
              if (_tenantName != null) await prefs.setString('tenant_name', _tenantName!);
              if (_tenantCode != null) await prefs.setString('tenant_code', _tenantCode!);
              if (_tenantId != null) await prefs.setInt('tenant_id', _tenantId!);
              if (_username != null) await prefs.setString('username', _username!);
            } catch (_) {}
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

  Future<void> logout() async {
    _accessToken = null;
    _tenantName = null;
    _tenantCode = null;
    _tenantId = null;
    _username = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (_) {}
    notifyListeners();
  }
}
