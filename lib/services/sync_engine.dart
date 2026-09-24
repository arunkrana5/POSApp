import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../database/sqlite_helper.dart';
import '../models/product.dart';
import '../models/post_response.dart';

class SyncEngine {
  final String apiBaseUrl;

  SyncEngine({String? baseUrl}) : apiBaseUrl = baseUrl ?? ApiConfig.baseUrl;

  Future<int> getPendingCount() async {
    if (kIsWeb) return 0;
    try {
      final pendingItems = await SQLiteHelper.instance.getPendingSyncItems();
      return pendingItems.length;
    } catch (_) {
      return 0;
    }
  }

  // Fetch live products from backend API and save into local SQLite database if non-web
  Future<List<Product>> fetchAndCacheProducts([String token = '']) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/products'),
        headers: {
          'Content-Type': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
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
    } catch (_) {
      // Offline fallback: load from local SQLite
    }

    if (!kIsWeb) {
      try {
        return await SQLiteHelper.instance.getProducts();
      } catch (_) {}
    }
    return [];
  }

  Future<void> saveProductOffline(Map<String, dynamic> productData) async {
    // 1. Direct API call to backend first
    try {
      await http.post(
        Uri.parse('$apiBaseUrl/products'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(productData),
      ).timeout(const Duration(seconds: 8));
    } catch (_) {}

    // 2. Save locally if non-web SQLite is available
    if (!kIsWeb) {
      try {
        final clientTxId = 'PROD-${DateTime.now().millisecondsSinceEpoch}';
        final payloadJson = jsonEncode(productData);
        await SQLiteHelper.instance.saveProductRecord(productData);
        await SQLiteHelper.instance.addToSyncQueue(clientTxId, 'PRODUCT', payloadJson);
      } catch (_) {}
    }
  }

  Future<void> saveSaleOffline(Map<String, dynamic> saleData) async {
    final clientTxId = 'TX-${DateTime.now().millisecondsSinceEpoch}';

    // Direct API call
    try {
      await http.post(
        Uri.parse('$apiBaseUrl/sales'),
        headers: {'Content-Type': 'application/json'},
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

        final payloadJson = jsonEncode({
          'clientTransactionId': clientTxId,
          'customerName': saleData['customer'],
          'totalAmount': saleData['amount'],
          'paymentMode': saleData['paymentMode'],
          'items': saleData['items'],
          'createdAt': saleData['createdAt'] ?? DateTime.now().toIso8601String(),
        });

        await SQLiteHelper.instance.addToSyncQueue(clientTxId, 'SALE', payloadJson);
      } catch (_) {}
    }
  }

  Future<void> saveCustomerOffline(String name, String phone) async {
    final clientTxId = 'CUST-${DateTime.now().millisecondsSinceEpoch}';
    final payloadMap = {'name': name, 'phone': phone};

    try {
      await http.post(
        Uri.parse('$apiBaseUrl/customers'),
        headers: {'Content-Type': 'application/json'},
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
    final payloadMap = {
      'customerName': customerName,
      'amountPaid': amountPaid,
      'remainingUdhaar': remainingUdhaar,
      'paidAt': DateTime.now().toIso8601String(),
    };

    try {
      await http.post(
        Uri.parse('$apiBaseUrl/customers/payment'),
        headers: {'Content-Type': 'application/json'},
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
            headers: {
              'Content-Type': 'application/json',
              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
            },
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
