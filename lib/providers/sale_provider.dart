import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../database/sqlite_helper.dart';
import '../models/sale.dart';
import '../models/post_response.dart';

class SaleProvider with ChangeNotifier {
  bool _isProcessing = false;
  int _pendingSyncCount = 0;

  bool get isProcessing => _isProcessing;
  int get pendingSyncCount => _pendingSyncCount;

  Future<void> loadPendingCount() async {
    final pending = await SQLiteHelper.instance.getPendingSyncItems();
    _pendingSyncCount = pending.length;
    notifyListeners();
  }

  Future<PostResponse> recordSale({
    required String clientTxId,
    required double totalAmount,
    required double paidAmount,
    required String paymentMode,
    required List<OfflineSaleItem> items,
    required String token,
  }) async {
    _isProcessing = true;
    notifyListeners();

    final sale = OfflineSale(
      clientTransactionId: clientTxId,
      discountAmount: 0,
      paidAmount: paidAmount,
      paymentMode: paymentMode,
      notes: 'Mobile Sale',
      items: items,
      createdAt: DateTime.now(),
    );

    final payloadJson = jsonEncode(sale.toJson());

    // Try online API submit first
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/sales'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: payloadJson,
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final postResp = PostResponse.fromJson(jsonDecode(response.body));
        if (postResp.status) {
          _isProcessing = false;
          notifyListeners();
          return postResp;
        }
      }
    } catch (_) {
      // API call timed out or network offline -> Save to SQLite offline queue!
    }

    // Save to local SQLite pending queue for background sync
    await SQLiteHelper.instance.addToSyncQueue(clientTxId, 'SALE', payloadJson);
    await loadPendingCount();

    _isProcessing = false;
    notifyListeners();

    return PostResponse(
      viewAsString: '',
      status: true,
      statusCode: 200,
      message: 'Sale saved offline! Will sync when internet is connected.',
      redirectURL: '',
      id: 0,
      additionalMessage: '',
    );
  }
}
