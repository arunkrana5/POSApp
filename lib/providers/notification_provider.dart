import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class AppNotificationItem {
  final int id;
  final String source;
  final String title;
  final String message;
  final String category;
  final String gotoUrl;
  final int priority;
  final bool isRead;
  final String createdDate;
  final int tableId;
  final int tenantId;

  AppNotificationItem({
    required this.id,
    required this.source,
    required this.title,
    required this.message,
    required this.category,
    required this.gotoUrl,
    required this.priority,
    required this.isRead,
    required this.createdDate,
    required this.tableId,
    required this.tenantId,
  });

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) {
    return AppNotificationItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      source: json['source']?.toString() ?? 'SYSTEM',
      title: json['title']?.toString() ?? 'Notification',
      message: json['message']?.toString() ?? '',
      category: json['category']?.toString() ?? 'GENERAL',
      gotoUrl: json['gotoUrl']?.toString() ?? '',
      priority: (json['priority'] as num?)?.toInt() ?? 1,
      isRead: json['isRead'] == true,
      createdDate: json['createdDate']?.toString() ?? '',
      tableId: (json['tableId'] as num?)?.toInt() ?? 0,
      tenantId: (json['tenantId'] as num?)?.toInt() ?? 1,
    );
  }
}

class NotificationProvider with ChangeNotifier {
  List<AppNotificationItem> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;

  Map<String, String> _fcmConfig = {
    'fcmApiKey': 'AIzaSyD4Ke1oq7cAUM47eaHOdCYSWB7WY8aqjGg',
    'fcmAuthDomain': 'uatweb-52210.firebaseapp.com',
    'fcmProjectId': 'uatweb-52210',
    'fcmStorageBucket': 'uatweb-52210.firebasestorage.app',
    'fcmMessagingSenderId': '292445139375',
    'fcmAppId': '1:292445139375:web:13ef000481be4897d53f5',
    'measurementId': 'G-N5JDJ61BW3',
    'fcmVapidKey': 'BJqD_-Lk8oW0DIrftlgsId4JsWJks288xq-tV72KnwXTJ3rWMy6Zs6hjIU8fcjxgVSfLT4laSibnpPsJzSM4gZw',
  };

  List<AppNotificationItem> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  Map<String, String> get fcmConfig => _fcmConfig;

  Future<void> fetchNotifications({int tenantId = 1, String? tenantCode, String? token}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        if (tenantId > 0) 'X-Tenant-Id': tenantId.toString(),
        if (tenantCode != null && tenantCode.isNotEmpty) 'X-Tenant-Code': tenantCode,
      };

      final qStr = tenantId > 0 ? '?tenantId=$tenantId' : '';
      final baseUrl = ApiConfig.baseUrl.isNotEmpty ? ApiConfig.baseUrl : 'https://villageshop-api.onrender.com/api';

      final res = await http.get(Uri.parse('$baseUrl/notifications$qStr'), headers: headers)
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        _notifications = list.map((j) => AppNotificationItem.fromJson(Map<String, dynamic>.from(j))).toList();
        _unreadCount = _notifications.where((n) => !n.isRead).length;
      }
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  Future<void> markAsRead(int id, {int tenantId = 1, String? token}) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      final old = _notifications[index];
      _notifications[index] = AppNotificationItem(
        id: old.id,
        source: old.source,
        title: old.title,
        message: old.message,
        category: old.category,
        gotoUrl: old.gotoUrl,
        priority: old.priority,
        isRead: true,
        createdDate: old.createdDate,
        tableId: old.tableId,
        tenantId: old.tenantId,
      );
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      notifyListeners();
    }

    try {
      final baseUrl = ApiConfig.baseUrl.isNotEmpty ? ApiConfig.baseUrl : 'https://villageshop-api.onrender.com/api';
      await http.put(
        Uri.parse('$baseUrl/notifications/$id/read'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  Future<void> markAllAsRead({int tenantId = 1, String? token}) async {
    for (var i = 0; i < _notifications.length; i++) {
      final old = _notifications[i];
      _notifications[i] = AppNotificationItem(
        id: old.id,
        source: old.source,
        title: old.title,
        message: old.message,
        category: old.category,
        gotoUrl: old.gotoUrl,
        priority: old.priority,
        isRead: true,
        createdDate: old.createdDate,
        tableId: old.tableId,
        tenantId: old.tenantId,
      );
    }
    _unreadCount = 0;
    notifyListeners();
  }

  Future<void> deleteNotification(int id, {int tenantId = 1, String? token}) async {
    _notifications.removeWhere((n) => n.id == id);
    _unreadCount = _notifications.where((n) => !n.isRead).length;
    notifyListeners();

    try {
      final baseUrl = ApiConfig.baseUrl.isNotEmpty ? ApiConfig.baseUrl : 'https://villageshop-api.onrender.com/api';
      await http.delete(
        Uri.parse('$baseUrl/notifications/$id'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  void updateFcmConfig(Map<String, String> newConfig) {
    _fcmConfig = {..._fcmConfig, ...newConfig};
    notifyListeners();
  }
}
