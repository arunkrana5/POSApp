import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/sync_engine.dart';

class SyncProvider with ChangeNotifier {
  final SyncEngine _syncEngine = SyncEngine();
  int _pendingSyncCount = 0;
  bool _isSyncing = false;

  int get pendingSyncCount => _pendingSyncCount;
  bool get isSyncing => _isSyncing;

  Future<void> loadPendingCount() async {
    _pendingSyncCount = await _syncEngine.getPendingCount();
    notifyListeners();
  }

  Future<List<Product>> fetchProducts([String token = '']) async {
    return await _syncEngine.fetchAndCacheProducts(token);
  }

  Future<void> saveOfflineSale(Map<String, dynamic> saleData) async {
    await _syncEngine.saveSaleOffline(saleData);
    await loadPendingCount();
  }

  Future<void> saveOfflineCustomer(String name, String phone) async {
    await _syncEngine.saveCustomerOffline(name, phone);
    await loadPendingCount();
  }

  Future<void> saveOfflineCustomerPayment(String customerName, double amountPaid, double remainingUdhaar) async {
    await _syncEngine.saveCustomerPaymentOffline(customerName, amountPaid, remainingUdhaar);
    await loadPendingCount();
  }

  Future<void> saveOfflineProduct(Map<String, dynamic> productData) async {
    await _syncEngine.saveProductOffline(productData);
    await loadPendingCount();
  }

  Future<void> syncNow([String token = '']) async {
    _isSyncing = true;
    notifyListeners();

    await _syncEngine.syncPendingTransactions(token);

    _isSyncing = false;
    await loadPendingCount();
  }
}
