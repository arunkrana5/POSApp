import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../database/sqlite_helper.dart';
import '../models/product.dart';
import '../models/post_response.dart';

class SyncEngine {
  final String apiBaseUrl;

  SyncEngine({String? baseUrl}) : apiBaseUrl = baseUrl ?? ApiConfig.baseUrl;

  Future<Map<String, String>> _getTenantHeaders([String token = '']) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    try {
      final prefs = await SharedPreferences.getInstance();
      final tId = prefs.getInt('tenant_id');
      final tCode = prefs.getString('tenant_code');
      final savedToken = prefs.getString('auth_token');

      final tokenToUse = token.isNotEmpty ? token : (savedToken ?? '');
      if (tokenToUse.isNotEmpty) headers['Authorization'] = 'Bearer $tokenToUse';
      if (tId != null && tId > 0) headers['X-Tenant-Id'] = tId.toString();
      if (tCode != null && tCode.isNotEmpty) headers['X-Tenant-Code'] = tCode;
    } catch (_) {}
    return headers;
  }

  Future<int> getPendingCount() async {
    if (kIsWeb) return 0;
    try {
      final pendingItems = await SQLiteHelper.instance.getPendingSyncItems();
      return pendingItems.length;
    } catch (_) {
      return 0;
    }
  }

  // Fetch live products from backend API for logged-in tenant
  Future<List<Product>> fetchAndCacheProducts([String token = '']) async {
    try {
      final headers = await _getTenantHeaders(token);
      final prefs = await SharedPreferences.getInstance();
      final tCode = prefs.getString('tenant_code');
      final tId = prefs.getInt('tenant_id');
      
      final queryParams = <String>[];
      if (tId != null && tId > 0) queryParams.add('tenantId=$tId');
      if (tCode != null && tCode.isNotEmpty) queryParams.add('tenantCode=$tCode');
      final qStr = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';

      final response = await http.get(
        Uri.parse('$apiBaseUrl/stock$qStr'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        final List<Product> products = jsonList.map((j) => Product.fromJson(j as Map<String, dynamic>)).toList();
        if (products.isNotEmpty && !kIsWeb) {
          try {
            await SQLiteHelper.instance.saveProducts(products);
          } catch (_) {}
        }
        return products;
      }
    } catch (_) {}

    if (!kIsWeb) {
      try {
        return await SQLiteHelper.instance.getProducts();
      } catch (_) {}
    }
    return [];
  }

  // Fetch live customers from backend API for logged-in tenant
  Future<List<Map<String, dynamic>>> fetchAndCacheCustomers([String token = '']) async {
    try {
      final headers = await _getTenantHeaders(token);
      final prefs = await SharedPreferences.getInstance();
      final tCode = prefs.getString('tenant_code');
      final tId = prefs.getInt('tenant_id');

      final queryParams = <String>[];
      if (tId != null && tId > 0) queryParams.add('tenantId=$tId');
      if (tCode != null && tCode.isNotEmpty) queryParams.add('tenantCode=$tCode');
      final qStr = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';

      final response = await http.get(
        Uri.parse('$apiBaseUrl/customers$qStr'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        final List<Map<String, dynamic>> customers = jsonList.map((j) => Map<String, dynamic>.from(j as Map)).toList();
        if (customers.isNotEmpty && !kIsWeb) {
          try {
            for (var c in customers) {
              await SQLiteHelper.instance.saveCustomer({
                'id': c['id']?.toString() ?? '0',
                'name': c['name'] ?? '',
                'phone': c['phone'] ?? '',
                'udhaar': (c['udhaar'] as num?)?.toDouble() ?? 0.0,
                'lastTx': c['lastTx'] ?? 'Registered',
              });
            }
          } catch (_) {}
        }
        return customers;
      }
    } catch (_) {}

    if (!kIsWeb) {
      try {
        return await SQLiteHelper.instance.getCustomers();
      } catch (_) {}
    }
    return [];
  }

  Future<void> saveProductOffline(Map<String, dynamic> productData) async {
    final Map<String, dynamic> payload = Map<String, dynamic>.from(productData);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (payload['tenantId'] == null) payload['tenantId'] = prefs.getInt('tenant_id');
      if (payload['tenantCode'] == null) payload['tenantCode'] = prefs.getString('tenant_code');
    } catch (_) {}

    if (payload['sellingPrice'] == null && payload['price'] != null) {
      payload['sellingPrice'] = (payload['price'] as num).toDouble();
    }
    if (payload['currentStock'] == null && payload['stock'] != null) {
      payload['currentStock'] = (payload['stock'] as num).toDouble();
    }
    if (payload['openingStock'] == null && payload['stock'] != null) {
      payload['openingStock'] = (payload['stock'] as num).toDouble();
    }
    if (payload['expiryDate'] != null && payload['expiryDate'].toString().trim().isEmpty) {
      payload['expiryDate'] = null;
    }

    // 1. Direct API call to backend first
    try {
      final headers = await _getTenantHeaders();
      await http.post(
        Uri.parse('$apiBaseUrl/stock'),
        headers: headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 8));
    } catch (_) {}

    // 2. Save locally if non-web SQLite is available
    if (!kIsWeb) {
      try {
        final clientTxId = 'PROD-${DateTime.now().millisecondsSinceEpoch}';
        final payloadJson = jsonEncode(payload);
        await SQLiteHelper.instance.saveProductRecord(payload);
        await SQLiteHelper.instance.addToSyncQueue(clientTxId, 'PRODUCT', payloadJson);
      } catch (_) {}
    }
  }

  Future<void> saveSaleOffline(Map<String, dynamic> saleData) async {
    final clientTxId = saleData['clientTransactionId'] ?? 'TX-${DateTime.now().millisecondsSinceEpoch}';

    try {
      final prefs = await SharedPreferences.getInstance();
      if (saleData['tenantId'] == null) saleData['tenantId'] = prefs.getInt('tenant_id');
      if (saleData['tenantCode'] == null) saleData['tenantCode'] = prefs.getString('tenant_code');
    } catch (_) {}

    // Direct API call
    try {
      final headers = await _getTenantHeaders();
      await http.post(
        Uri.parse('$apiBaseUrl/sales'),
        headers: headers,
        body: jsonEncode(saleData),
      ).timeout(const Duration(seconds: 8));
    } catch (_) {}

    if (!kIsWeb) {
      try {
        final items = saleData['items'] as List<dynamic>? ?? [];
        for (var item in items) {
          if (item is Map) {
            final name = (item['name'] ?? item['productName'])?.toString() ?? '';
            final qty = (item['qty'] ?? item['quantity'] as num?)?.toDouble() ?? 1.0;
            if (name.isNotEmpty) {
              await SQLiteHelper.instance.deductProductStock(name, qty);
            }
          }
        }

        final payloadJson = jsonEncode(saleData);
        await SQLiteHelper.instance.addToSyncQueue(clientTxId, 'SALE', payloadJson);
      } catch (_) {}
    }
  }

  Future<void> saveCustomerOffline(String name, String phone) async {
    final clientTxId = 'CUST-${DateTime.now().millisecondsSinceEpoch}';
    final payloadMap = <String, dynamic>{'name': name, 'phone': phone};

    try {
      final prefs = await SharedPreferences.getInstance();
      payloadMap['tenantId'] = prefs.getInt('tenant_id');
      payloadMap['tenantCode'] = prefs.getString('tenant_code');
    } catch (_) {}

    try {
      final headers = await _getTenantHeaders();
      await http.post(
        Uri.parse('$apiBaseUrl/customers'),
        headers: headers,
        body: jsonEncode(payloadMap),
      ).timeout(const Duration(seconds: 8));
    } catch (_) {}

    if (!kIsWeb) {
      try {
        await SQLiteHelper.instance.saveCustomer({
          'name': name,
          'phone': phone,
          'udhaar': 0.0,
          'lastTx': 'Registered Today',
        });
        await SQLiteHelper.instance.addToSyncQueue(clientTxId, 'CUSTOMER', jsonEncode(payloadMap));
      } catch (_) {}
    }
  }

  Future<void> saveCustomerPaymentOffline(String customerName, double amountPaid, double remainingUdhaar) async {
    final clientTxId = 'PAY-${DateTime.now().millisecondsSinceEpoch}';
    final payloadMap = <String, dynamic>{
      'customerName': customerName,
      'amountPaid': amountPaid,
      'remainingUdhaar': remainingUdhaar,
      'paidAt': DateTime.now().toIso8601String(),
    };

    try {
      final prefs = await SharedPreferences.getInstance();
      payloadMap['tenantId'] = prefs.getInt('tenant_id');
      payloadMap['tenantCode'] = prefs.getString('tenant_code');
    } catch (_) {}

    try {
      final headers = await _getTenantHeaders();
      await http.post(
        Uri.parse('$apiBaseUrl/customers/payment'),
        headers: headers,
        body: jsonEncode(payloadMap),
      ).timeout(const Duration(seconds: 8));
    } catch (_) {}

    if (!kIsWeb) {
      try {
        await SQLiteHelper.instance.updateCustomerUdhaar(customerName, remainingUdhaar);
        await SQLiteHelper.instance.addToSyncQueue(clientTxId, 'PAYMENT', jsonEncode(payloadMap));
      } catch (_) {}
    }
  }

  Future<int> syncPendingTransactions([String token = '']) async {
    if (kIsWeb) return 0;
    return await processPendingQueue(token);
  }

  Future<int> processPendingQueue(String token) async {
    if (kIsWeb) return 0;
    try {
      final pendingItems = await SQLiteHelper.instance.getPendingSyncItems();
      int syncedCount = 0;

      final headers = await _getTenantHeaders(token);

      for (var item in pendingItems) {
        final clientTxId = item['clientTransactionId'] as String;
        final entityName = item['entityName'] as String;
        final payloadJson = item['payload'] as String;

        String endpoint = '/sales';
        if (entityName == 'CUSTOMER') endpoint = '/customers';
        if (entityName == 'PRODUCT') endpoint = '/products';
        if (entityName == 'PAYMENT') endpoint = '/customers/payment';

        try {
          final response = await http.post(
            Uri.parse('$apiBaseUrl$endpoint'),
            headers: headers,
            body: payloadJson,
          ).timeout(const Duration(seconds: 5));

          if (response.statusCode == 200 || response.statusCode == 201) {
            final json = jsonDecode(response.body);
            final postResp = PostResponse.fromJson(json);

            if (postResp.status) {
              await SQLiteHelper.instance.markSynced(clientTxId);
              syncedCount++;
            }
          }
        } catch (e) {
          break;
        }
      }
      return syncedCount;
    } catch (_) {
      return 0;
    }
  }
}
