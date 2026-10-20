import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/sync_provider.dart';
import '../providers/theme_provider.dart';
import '../database/sqlite_helper.dart';
import '../widgets/app_drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/invoice_printer.dart';
import '../utils/whatsapp_helper.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final List<Map<String, dynamic>> _customers = [];
  String _searchQuery = '';
  bool _isLoading = false;

  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  final int _pageSize = 25;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  int _totalCount = 0;
  double _serverTotalUdhaar = 0.0;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadCustomers(reset: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && !_isLoadingMore && _hasMore) {
        _loadCustomers(reset: false);
      }
    }
  }

  Future<void> _loadCustomers({bool reset = false}) async {
    if (reset) {
      _currentPage = 1;
      _hasMore = true;
      if (mounted) setState(() => _isLoading = true);
    } else {
      if (!_hasMore || _isLoadingMore) return;
      if (mounted) setState(() => _isLoadingMore = true);
    }

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final prefs = await SharedPreferences.getInstance();
      final token = (auth.accessToken != null && auth.accessToken!.isNotEmpty)
          ? auth.accessToken!
          : (prefs.getString('auth_token') ?? '');
      final tenantId = (auth.tenantId != null && auth.tenantId! > 0)
          ? auth.tenantId!
          : (prefs.getInt('tenant_id') ?? 0);
      final tenantCode = (auth.tenantCode != null && auth.tenantCode!.isNotEmpty)
          ? auth.tenantCode!
          : (prefs.getString('tenant_code') ?? '');

      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        if (tenantId > 0) 'X-Tenant-Id': tenantId.toString(),
        if (tenantCode.isNotEmpty) 'X-Tenant-Code': tenantCode,
      };

      // Fetch dashboard metrics for accurate totalUdhaar across store on reset
      if (reset) {
        try {
          final qParams = <String>[];
          if (tenantId > 0) qParams.add('tenantId=$tenantId');
          if (tenantCode.isNotEmpty) qParams.add('tenantCode=$tenantCode');
          final qMetric = qParams.isNotEmpty ? '?${qParams.join('&')}' : '';
          final mRes = await http.get(Uri.parse('${ApiConfig.baseUrl}/reports/dashboard-metrics$qMetric'), headers: headers).timeout(const Duration(seconds: 5));
          if (mRes.statusCode == 200) {
            final mData = jsonDecode(mRes.body);
            if (mData is Map<String, dynamic>) {
              _serverTotalUdhaar = (mData['totalUdhaar'] ?? mData['udhaarSales'] as num?)?.toDouble() ?? 0.0;
            }
          }
        } catch (_) {}
      }

      final queryParams = <String, String>{
        'page': _currentPage.toString(),
        'pageSize': _pageSize.toString(),
        'paged': 'true',
      };
      if (tenantId > 0) queryParams['tenantId'] = tenantId.toString();
      if (tenantCode.isNotEmpty) queryParams['tenantCode'] = tenantCode;
      if (_searchQuery.trim().isNotEmpty) queryParams['search'] = _searchQuery.trim();

      final url = Uri.parse('${ApiConfig.baseUrl}/customers').replace(queryParameters: queryParams);
      final res = await http.get(url, headers: headers).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final dynamic raw = jsonDecode(res.body);
        final List<dynamic> data = raw is List ? raw : (raw['items'] as List? ?? []);
        final int total = raw is Map && raw['totalCount'] != null ? raw['totalCount'] as int : (_customers.length + data.length);
        final bool serverHasMore = raw is Map && raw['hasMore'] != null ? raw['hasMore'] as bool : (data.length >= _pageSize);

        final List<Map<String, dynamic>> newItems = data.map((c) => {
          'id': (c['id'] ?? c['ID'] ?? '0').toString(),
          'name': c['name'] ?? '',
          'phone': c['phone'] ?? '',
          'email': c['email'] ?? '',
          'whatsapp': c['whatsapp'] ?? '',
          'fatherName': c['fatherName'] ?? '',
          'address': c['address'] ?? '',
          'village': c['village'] ?? '',
          'po': c['po'] ?? '',
          'ps': c['ps'] ?? '',
          'dist': c['dist'] ?? '',
          'pincode': c['pincode'] ?? '',
          'udhaar': (c['udhaar'] as num?)?.toDouble() ?? 0.0,
          'lastTx': c['lastTx'] ?? 'Registered Today',
        }).toList();

        if (mounted) {
          setState(() {
            if (reset) {
              _customers.clear();
            }
            final existingIds = _customers.map((i) => i['id']).toSet();
            for (var item in newItems) {
              if (!existingIds.contains(item['id'])) {
                _customers.add(item);
                existingIds.add(item['id']);
              }
            }
            _totalCount = total;
            _hasMore = serverHasMore;
            _currentPage++;
          });
        }
      } else {
        if (reset && _customers.isEmpty) {
          final syncProvider = Provider.of<SyncProvider>(context, listen: false);
          final fetchedCustomers = await syncProvider.fetchCustomers();
          if (mounted && fetchedCustomers.isNotEmpty) {
            setState(() {
              _customers.clear();
              _customers.addAll(fetchedCustomers.map((c) => {
                'id': c['id']?.toString() ?? '0',
                'name': c['name'] ?? '',
                'phone': c['phone'] ?? '',
                'email': c['email'] ?? '',
                'whatsapp': c['whatsapp'] ?? '',
                'fatherName': c['fatherName'] ?? '',
                'address': c['address'] ?? '',
                'village': c['village'] ?? '',
                'po': c['po'] ?? '',
                'ps': c['ps'] ?? '',
                'dist': c['dist'] ?? '',
                'pincode': c['pincode'] ?? '',
                'udhaar': (c['udhaar'] as num?)?.toDouble() ?? 0.0,
                'lastTx': c['lastTx'] ?? 'Registered Today',
              }));
            });
          }
        }
      }
    } catch (_) {
      if (reset && _customers.isEmpty) {
        try {
          final dbCustomers = await SQLiteHelper.instance.getCustomers();
          if (mounted && dbCustomers.isNotEmpty) {
            setState(() {
              _customers.clear();
              _customers.addAll(dbCustomers.map((c) => {
                'id': c['id']?.toString() ?? '0',
                'name': c['name'] ?? '',
                'phone': c['phone'] ?? '',
                'email': c['email'] ?? '',
                'whatsapp': c['whatsapp'] ?? '',
                'fatherName': c['fatherName'] ?? '',
                'address': c['address'] ?? '',
                'village': c['village'] ?? '',
                'po': c['po'] ?? '',
                'ps': c['ps'] ?? '',
                'dist': c['dist'] ?? '',
                'pincode': c['pincode'] ?? '',
                'udhaar': (c['udhaar'] as num?)?.toDouble() ?? 0.0,
                'lastTx': c['lastTx'] ?? 'Today',
              }));
            });
          }
        } catch (_) {}
      }
    }
    if (mounted) setState(() {
      _isLoading = false;
      _isLoadingMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = Provider.of<LocaleProvider>(context).isHindi;
    final filteredCustomers = _customers
        .where((c) =>
            c['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
            c['phone'].toString().contains(_searchQuery))
        .toList();

    final totalUdhaar = _serverTotalUdhaar > 0 ? _serverTotalUdhaar : _customers.fold(0.0, (sum, c) => sum + ((c['udhaar'] as num?)?.toDouble() ?? 0.0));

    final themeProvider = Provider.of<TenantThemeProvider>(context);
    return Scaffold(
      backgroundColor: themeProvider.pageBgColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(
          isHindi ? 'ग्राहक खाता ($_totalCount)' : 'Customer Ledger ($_totalCount)',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
          // Total Udhaar Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: themeProvider.cardBgColor,
              border: Border(bottom: BorderSide(color: themeProvider.textColor.withOpacity(0.08))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isHindi ? 'कुल उधार' : 'Total Outstanding',
                      style: TextStyle(
                        fontFamily: themeProvider.fontFamily,
                        color: themeProvider.textColor.withOpacity(0.7),
                        fontSize: 13 * themeProvider.fontSizeScale,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹ ${totalUdhaar.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontFamily: themeProvider.fontFamily,
                        fontSize: 24 * themeProvider.fontSizeScale,
                        fontWeight: FontWeight.bold,
                        color: themeProvider.amountColor,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeProvider.buttonBgColor,
                    foregroundColor: themeProvider.buttonTextColor,
                  ),
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                  label: Text(
                    isHindi ? 'नया ग्राहक' : 'Add Customer',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  onPressed: () => _showAddCustomerModal(context, isHindi),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: isHindi ? 'ग्राहक नाम या फोन नंबर खोजें...' : 'Search by customer name or phone...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              onChanged: (val) {
                _debounceTimer?.cancel();
                _debounceTimer = Timer(const Duration(milliseconds: 350), () {
                  setState(() => _searchQuery = val);
                  _loadCustomers(reset: true);
                });
              },
            ),
          ),

          // Customer List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth >= 750;

                      Widget buildCustomerCard(Map<String, dynamic> customer) {
                        final udhaarVal = (customer['udhaar'] as num?)?.toDouble() ?? 0.0;
                        final hasBalance = udhaarVal > 0;
                        final phone = customer['phone'] ?? '';
                        final village = customer['village'] ?? customer['address'] ?? '';

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            onTap: () => _showCustomerDetailModal(context, customer, isHindi),
                            leading: CircleAvatar(
                              backgroundColor: hasBalance ? Colors.red.shade100 : Colors.green.shade100,
                              child: Icon(
                                Icons.person_rounded,
                                color: hasBalance ? Colors.red.shade800 : Colors.green.shade800,
                              ),
                            ),
                            title: Text(
                              customer['name'] ?? 'Unnamed',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            subtitle: Text(
                              village.toString().isNotEmpty
                                  ? '$phone • $village'
                                  : '$phone • ${customer["lastTx"] ?? "No tx"}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '₹ ${udhaarVal.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: hasBalance ? Colors.red.shade700 : Colors.green.shade700,
                                      ),
                                    ),
                                    if (hasBalance)
                                      InkWell(
                                        onTap: () => _showRecordPaymentDialog(context, customer, isHindi),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade700,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            isHindi ? 'जमा लें' : 'Pay Received',
                                            style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: Icon(Icons.edit_outlined, color: themeProvider.primaryColor, size: 20),
                                  tooltip: 'Edit Customer',
                                  onPressed: () => _showAddCustomerModal(context, isHindi, customer),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: () => _loadCustomers(reset: true),
                        child: isDesktop
                            ? GridView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  mainAxisExtent: 78,
                                ),
                                itemCount: filteredCustomers.length,
                                itemBuilder: (ctx, index) => buildCustomerCard(filteredCustomers[index]),
                              )
                            : ListView.separated(
                                controller: _scrollController,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                itemCount: filteredCustomers.length + (_isLoadingMore ? 1 : 0),
                                separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                                itemBuilder: (ctx, index) {
                                  if (index == filteredCustomers.length) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 16),
                                      child: Center(child: CircularProgressIndicator()),
                                    );
                                  }
                                  return buildCustomerCard(filteredCustomers[index]);
                                },
                              ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  ),
);
}

  void _showRecordPaymentDialog(BuildContext context, Map<String, dynamic> customer, bool isHindi) {
    final amountController = TextEditingController();
    final double currentUdhaar = (customer['udhaar'] as num?)?.toDouble() ?? 0.0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${isHindi ? "भुगतान प्राप्त करें" : "Record Payment"} - ${customer["name"]}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${isHindi ? "वर्तमान बकाया" : "Current Balance"}: ₹ ${currentUdhaar.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: isHindi ? 'जमा की गई राशि (₹)' : 'Amount Received (₹)',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isHindi ? 'रद्द करें' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
            onPressed: () async {
              final paidAmount = double.tryParse(amountController.text) ?? 0.0;
              if (paidAmount > 0) {
                final newUdhaar = (currentUdhaar - paidAmount).clamp(0.0, double.infinity);
                
                final syncProvider = Provider.of<SyncProvider>(context, listen: false);
                await syncProvider.saveOfflineCustomerPayment(customer['name'], paidAmount, newUdhaar);

                setState(() {
                  customer['udhaar'] = newUdhaar;
                  customer['lastTx'] = 'Payment Paid';
                });

                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isHindi
                            ? 'भुगतान सफलतापूर्‍वक दर्ज किया गया!'
                            : 'Payment recorded successfully!',
                      ),
                      backgroundColor: Colors.green.shade700,
                    ),
                  );
                  _loadCustomers(reset: true);
                }
              }
            },
            child: Text(isHindi ? 'जमा करें' : 'Save Payment', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    try {
      final prefs = await SharedPreferences.getInstance();
      final tId = prefs.getInt('tenant_id');
      final tCode = prefs.getString('tenant_code');
      final token = prefs.getString('auth_token');
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
      if (tId != null && tId > 0) headers['X-Tenant-Id'] = tId.toString();
      if (tCode != null && tCode.isNotEmpty) headers['X-Tenant-Code'] = tCode;
    } catch (_) {}
    return headers;
  }

  void _showCustomerDetailModal(BuildContext context, Map<String, dynamic> c, bool isHindi) {
    final themeProvider = Provider.of<TenantThemeProvider>(context, listen: false);
    final udhaarVal = (c['udhaar'] as num?)?.toDouble() ?? 0.0;
    final String custId = (c['id'] != null && c['id'].toString() != '0') ? c['id'].toString() : (c['name'] ?? '');

    Future<Map<String, dynamic>> fetchLedgerData() async {
      try {
        final baseUrl = ApiConfig.baseUrl;
        final headers = await _getAuthHeaders();
        final prefs = await SharedPreferences.getInstance();
        final tId = prefs.getInt('tenant_id');
        final tCode = prefs.getString('tenant_code');
        final encodedId = Uri.encodeComponent(custId);
        final qParams = <String>[];
        if (tId != null && tId > 0) qParams.add('tenantId=$tId');
        if (tCode != null && tCode.isNotEmpty) qParams.add('tenantCode=$tCode');
        final qStr = qParams.isNotEmpty ? '?${qParams.join('&')}' : '';

        final res = await http.get(Uri.parse('$baseUrl/customers/$encodedId/ledger$qStr'), headers: headers).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data is Map<String, dynamic>) {
            return data;
          }
        }
      } catch (_) {}
      return {
        'customer': {
          'id': custId,
          'name': c['name'] ?? '',
          'phone': c['phone'] ?? '',
          'currentBalance': udhaarVal,
          'totalPurchases': 0.0,
          'totalPaid': 0.0,
          'salesCount': 0,
        },
        'transactions': <Map<String, dynamic>>[]
      };
    }

    final ledgerFuture = fetchLedgerData();
    String activeFilter = 'ALL';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.88,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (sheetContext, scrollController) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.account_balance_wallet_rounded, color: themeProvider.primaryColor, size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  isHindi ? 'ग्राहक खाता विवरण (Ledger Statement)' : 'Customer Ledger Statement',
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: themeProvider.primaryColor),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_note_rounded, color: Colors.blue),
                              tooltip: 'Edit Profile',
                              onPressed: () {
                                Navigator.pop(ctx);
                                _showAddCustomerModal(context, isHindi, c);
                              },
                            ),
                          ],
                        ),
                        const Divider(),
                        const SizedBox(height: 8),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundColor: themeProvider.primaryColor.withOpacity(0.1),
                            child: Icon(Icons.person_rounded, color: themeProvider.primaryColor, size: 28),
                          ),
                          title: Text(c['name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          subtitle: Text('Father\'s Name: ${c["fatherName"] ?? "N/A"}'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Total Outstanding', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              Text(
                                '₹ ${udhaarVal.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: udhaarVal > 0 ? Colors.red.shade700 : Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.phone, size: 16, color: Colors.grey.shade700),
                            const SizedBox(width: 6),
                            Text('${c["phone"] ?? "N/A"}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(width: 16),
                            Icon(Icons.message_rounded, size: 16, color: Colors.green),
                            const SizedBox(width: 6),
                            Text('${c["whatsapp"] ?? c["phone"] ?? "N/A"}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ],
                        ),
                        if (c['address'] != null && c['address'].toString().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade700),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${c["address"]}${c["village"] != null ? ", " + c["village"] : ""}',
                                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 14),

                        // FUTURE BUILDER FOR LEDGER TRANSACTIONS & SUMMARY
                        FutureBuilder<Map<String, dynamic>>(
                          future: ledgerFuture,
                          builder: (fCtx, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()));
                            }

                            final data = snapshot.data ?? {};
                            final custObj = (data['customer'] as Map<String, dynamic>?) ?? {};
                            final allTxs = (data['transactions'] as List?) ?? [];

                            final double totalPurchases = (custObj['totalPurchases'] as num?)?.toDouble() ??
                                allTxs.fold(0.0, (s, t) => s + ((t['totalAmount'] ?? t['debit'] ?? 0.0) as num).toDouble());
                            final double totalPaid = (custObj['totalPaid'] as num?)?.toDouble() ??
                                allTxs.fold(0.0, (s, t) => s + ((t['paidAmount'] ?? t['credit'] ?? 0.0) as num).toDouble());
                            final double liveBalance = (custObj['currentBalance'] as num?)?.toDouble() ?? udhaarVal;

                            // 1. TOP 3 KPI SUMMARY CARDS
                            final kpiCards = Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.blue.shade200),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(isHindi ? 'कुल बिक्री (Purchases)' : 'Total Purchases', style: TextStyle(fontSize: 10, color: Colors.blue.shade900, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 2),
                                        Text('₹ ${totalPurchases.toStringAsFixed(2)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.blue.shade900)),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.green.shade200),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(isHindi ? 'कुल जमा (Paid)' : 'Total Paid', style: TextStyle(fontSize: 10, color: Colors.green.shade900, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 2),
                                        Text('₹ ${totalPaid.toStringAsFixed(2)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.green.shade900)),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: liveBalance > 0 ? Colors.red.shade50 : Colors.teal.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: liveBalance > 0 ? Colors.red.shade200 : Colors.teal.shade200),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(isHindi ? 'बकाया (Balance)' : 'Balance Due', style: TextStyle(fontSize: 10, color: liveBalance > 0 ? Colors.red.shade900 : Colors.teal.shade900, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 2),
                                        Text('₹ ${liveBalance.toStringAsFixed(2)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: liveBalance > 0 ? Colors.red.shade900 : Colors.teal.shade900)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );

                            // 2. ACTION BUTTONS (WhatsApp, Print, Add Payment)
                            final actionButtons = Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                // Option 1: WhatsApp App (Free & Unlimited Auto-fill)
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF25D366),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  ),
                                  icon: const Icon(Icons.chat_rounded, size: 16, color: Colors.white),
                                  label: Text(
                                    isHindi ? 'व्हाट्सएप ऐप (फ़्री)' : 'WhatsApp App',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: () {
                                    final phone = (c['whatsapp'] ?? c['phone'] ?? '').toString();
                                    if (phone.trim().isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Customer does not have a phone/WhatsApp number')),
                                      );
                                      return;
                                    }
                                    final msg = WhatsAppHelper.formatLedgerReminderMessage(
                                      tenantName: themeProvider.tenantName,
                                      customerName: (c['name'] ?? '').toString(),
                                      currentBalance: liveBalance,
                                      transactions: allTxs,
                                    );
                                    WhatsAppHelper.openWhatsApp(context: context, phone: phone, message: msg);
                                  },
                                ),
                                // Option 2: Server Cloud API (Green API Gateway)
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0284C7),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  ),
                                  icon: const Icon(Icons.cloud_upload_rounded, size: 16, color: Colors.white),
                                  label: Text(
                                    isHindi ? 'क्लाउड API' : 'Cloud API',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: () async {
                                    final phone = (c['whatsapp'] ?? c['phone'] ?? '').toString();
                                    if (phone.trim().isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Customer does not have a phone/WhatsApp number')),
                                      );
                                      return;
                                    }
                                    final msg = WhatsAppHelper.formatLedgerReminderMessage(
                                      tenantName: themeProvider.tenantName,
                                      customerName: (c['name'] ?? '').toString(),
                                      currentBalance: liveBalance,
                                      transactions: allTxs,
                                    );
                                    await WhatsAppHelper.sendCloudWhatsApp(context: context, phone: phone, message: msg);
                                  },
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: themeProvider.primaryColor,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  ),
                                  icon: const Icon(Icons.print_rounded, size: 16, color: Colors.white),
                                  label: Text(
                                    isHindi ? 'खाता प्रिंट करें' : 'Print Ledger',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: () {
                                    InvoicePrinter.printCustomerLedger(
                                      tenantName: themeProvider.tenantName,
                                      customerName: (c['name'] ?? '').toString(),
                                      customerPhone: (c['phone'] ?? '').toString(),
                                      currentBalance: liveBalance,
                                      transactions: allTxs,
                                    );
                                  },
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade700,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  ),
                                  icon: const Icon(Icons.add_card, size: 16, color: Colors.white),
                                  label: Text(
                                    isHindi ? 'भुगतान जोड़ें' : 'Add Payment',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _showRecordPaymentDialog(context, c, isHindi);
                                  },
                                ),
                              ],
                            );

                            // 3. FILTER TABS (All, Udhaar, Cash, Payments)
                            List filteredTxs = allTxs;
                            if (activeFilter == 'UDHAAR') {
                              filteredTxs = allTxs.where((t) {
                                final udhaar = (t['udhaarAmount'] as num?)?.toDouble() ?? 0.0;
                                final mode = (t['paymentMode'] ?? '').toString().toLowerCase();
                                return udhaar > 0 || mode.contains('udhaar');
                              }).toList();
                            } else if (activeFilter == 'CASH') {
                              filteredTxs = allTxs.where((t) {
                                final mode = (t['paymentMode'] ?? '').toString().toLowerCase();
                                final type = (t['type'] ?? '').toString().toUpperCase();
                                return mode.contains('cash') || mode.contains('upi') || type == 'CASH_SALE' || type == 'SALE';
                              }).toList();
                            } else if (activeFilter == 'PAYMENT') {
                              filteredTxs = allTxs.where((t) {
                                final type = (t['type'] ?? '').toString().toUpperCase();
                                final mode = (t['paymentMode'] ?? '').toString().toLowerCase();
                                return type == 'PAYMENT' || mode.contains('received');
                              }).toList();
                            }

                            final filterRow = SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  ChoiceChip(
                                    label: Text(isHindi ? 'सभी (${allTxs.length})' : 'All (${allTxs.length})', style: const TextStyle(fontSize: 11)),
                                    selected: activeFilter == 'ALL',
                                    onSelected: (sel) => setModalState(() => activeFilter = 'ALL'),
                                  ),
                                  const SizedBox(width: 6),
                                  ChoiceChip(
                                    label: Text(isHindi ? 'उधार (Udhaar)' : 'Udhaar / Credit', style: const TextStyle(fontSize: 11)),
                                    selected: activeFilter == 'UDHAAR',
                                    selectedColor: Colors.red.shade100,
                                    onSelected: (sel) => setModalState(() => activeFilter = 'UDHAAR'),
                                  ),
                                  const SizedBox(width: 6),
                                  ChoiceChip(
                                    label: Text(isHindi ? 'नकद / चुकता (Cash)' : 'Cash / Paid', style: const TextStyle(fontSize: 11)),
                                    selected: activeFilter == 'CASH',
                                    selectedColor: Colors.green.shade100,
                                    onSelected: (sel) => setModalState(() => activeFilter = 'CASH'),
                                  ),
                                  const SizedBox(width: 6),
                                  ChoiceChip(
                                    label: Text(isHindi ? 'खाता जमा (Payments)' : 'Payments', style: const TextStyle(fontSize: 11)),
                                    selected: activeFilter == 'PAYMENT',
                                    selectedColor: Colors.teal.shade100,
                                    onSelected: (sel) => setModalState(() => activeFilter = 'PAYMENT'),
                                  ),
                                ],
                              ),
                            );

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                kpiCards,
                                const SizedBox(height: 12),
                                actionButtons,
                                const SizedBox(height: 12),
                                const Divider(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      isHindi ? 'खाता लेन-देन बही (${filteredTxs.length})' : 'Ledger Transactions (${filteredTxs.length})',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                filterRow,
                                const SizedBox(height: 10),
                                if (filteredTxs.isEmpty)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: Center(
                                      child: Text(
                                        isHindi ? 'इस फ़िल्टर में कोई लेन-देन नहीं मिला' : 'No transactions found in this filter.',
                                        style: const TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: DataTable(
                                        columnSpacing: 14,
                                        headingRowHeight: 38,
                                        dataRowMinHeight: 48,
                                        dataRowMaxHeight: 56,
                                        headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                                        columns: [
                                          DataColumn(label: Text(isHindi ? 'दिनांक' : 'Date', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                          DataColumn(label: Text(isHindi ? 'विवरण व सामान' : 'Description & Items', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                          DataColumn(label: Text(isHindi ? 'मोड' : 'Mode', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                          DataColumn(label: Text(isHindi ? 'कुल बिल' : 'Bill Amount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                          DataColumn(label: Text(isHindi ? 'जमा भुगतान' : 'Paid Amount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                          DataColumn(label: Text(isHindi ? 'बकाया शेष' : 'Balance Due', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                        ],
                                        rows: filteredTxs.map<DataRow>((t) {
                                          final map = t as Map<String, dynamic>;
                                          final dateStr = map['date']?.toString() ?? '';
                                          final descStr = map['description']?.toString() ?? '';
                                          final itemsStr = map['itemsSummary']?.toString() ?? '';
                                          final modeStr = (map['paymentMode'] ?? (map['type'] == 'PAYMENT' ? 'Payment' : 'Cash')).toString();
                                          final bill = ((map['debit'] ?? map['totalAmount'] ?? 0.0) as num).toDouble();
                                          final paid = ((map['credit'] ?? map['paidAmount'] ?? 0.0) as num).toDouble();
                                          final bal = ((map['balance'] ?? 0.0) as num).toDouble();

                                          Color modeBg = Colors.blue.shade50;
                                          Color modeColor = Colors.blue.shade900;
                                          if (modeStr.toLowerCase().contains('cash')) {
                                            modeBg = Colors.green.shade50;
                                            modeColor = Colors.green.shade900;
                                          } else if (modeStr.toLowerCase().contains('udhaar')) {
                                            modeBg = Colors.red.shade50;
                                            modeColor = Colors.red.shade900;
                                          } else if (modeStr.toLowerCase().contains('upi')) {
                                            modeBg = Colors.purple.shade50;
                                            modeColor = Colors.purple.shade900;
                                          }

                                          return DataRow(
                                            cells: [
                                              DataCell(Text(dateStr, style: const TextStyle(fontSize: 11))),
                                              DataCell(
                                                Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(descStr, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                    if (itemsStr.isNotEmpty)
                                                      Text(
                                                        '🛒 $itemsStr',
                                                        style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              DataCell(
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: modeBg,
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: modeColor.withOpacity(0.3)),
                                                  ),
                                                  child: Text(
                                                    modeStr,
                                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: modeColor),
                                                  ),
                                                ),
                                              ),
                                              DataCell(Text(
                                                bill > 0 ? '₹ ${bill.toStringAsFixed(2)}' : '-',
                                                style: TextStyle(fontSize: 11, color: bill > 0 ? Colors.red.shade800 : Colors.black, fontWeight: bill > 0 ? FontWeight.bold : FontWeight.normal),
                                              )),
                                              DataCell(Text(
                                                paid > 0 ? '₹ ${paid.toStringAsFixed(2)}' : '-',
                                                style: TextStyle(fontSize: 11, color: paid > 0 ? Colors.green.shade800 : Colors.black, fontWeight: paid > 0 ? FontWeight.bold : FontWeight.normal),
                                              )),
                                              DataCell(Text(
                                                '₹ ${bal.toStringAsFixed(2)}',
                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: bal > 0 ? Colors.red.shade900 : Colors.green.shade900),
                                              )),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(isHindi ? 'बंद करें' : 'Close Ledger Statement'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showAddCustomerModal(BuildContext context, bool isHindi, [Map<String, dynamic>? existing]) {
    final themeProvider = Provider.of<TenantThemeProvider>(context, listen: false);

    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final phoneCtrl = TextEditingController(text: existing?['phone'] ?? '');
    final emailCtrl = TextEditingController(text: existing?['email'] ?? '');
    final whatsappCtrl = TextEditingController(text: existing?['whatsapp'] ?? existing?['phone'] ?? '');
    final fatherCtrl = TextEditingController(text: existing?['fatherName'] ?? '');
    final addressCtrl = TextEditingController(text: existing?['address'] ?? '');
    final villageCtrl = TextEditingController(text: existing?['village'] ?? '');
    final poCtrl = TextEditingController(text: existing?['po'] ?? '');
    final psCtrl = TextEditingController(text: existing?['ps'] ?? '');
    final distCtrl = TextEditingController(text: existing?['dist'] ?? '');
    final pincodeCtrl = TextEditingController(text: existing?['pincode'] ?? '');
    final udhaarCtrl = TextEditingController(text: (existing?['udhaar'] ?? 0.0).toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    existing != null
                        ? (isHindi ? 'ग्राहक अपडेट करें' : 'Edit Customer')
                        : (isHindi ? 'नया ग्राहक जोड़ें' : 'Add Customer'),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 12),
              
              const Text('PRIMARY CONTACT INFORMATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: isHindi ? 'ग्राहक नाम *' : 'Customer Name *',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: fatherCtrl,
                      decoration: InputDecoration(
                        labelText: isHindi ? 'पिता का नाम' : 'Father\'s Name',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: isHindi ? 'मोबाइल नंबर *' : 'Phone Number *',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: whatsappCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: isHindi ? 'व्हाट्सएप नंबर' : 'WhatsApp Number',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: isHindi ? 'ईमेल' : 'Email',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),

              const SizedBox(height: 16),
              const Text('FULL ADDRESS DETAILS (VILLAGE / PO / PS / DIST)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
              const SizedBox(height: 8),
              TextField(
                controller: addressCtrl,
                decoration: InputDecoration(
                  labelText: isHindi ? 'पता / मकान / गली' : 'House No, Street, Landmark',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: villageCtrl,
                      decoration: InputDecoration(
                        labelText: isHindi ? 'गाँव / कस्बा' : 'Village / Town',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: poCtrl,
                      decoration: InputDecoration(
                        labelText: isHindi ? 'डाकघर' : 'Post Office (P.O.)',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: psCtrl,
                      decoration: InputDecoration(
                        labelText: isHindi ? 'थाना' : 'Police Station (P.S.)',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: distCtrl,
                      decoration: InputDecoration(
                        labelText: isHindi ? 'जिला' : 'District (Dist)',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: pincodeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isHindi ? 'पिन कोड' : 'PIN Code',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: udhaarCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isHindi ? 'उधार बकाया' : 'Udhaar Balance (₹)',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeProvider.buttonBgColor,
                    foregroundColor: themeProvider.buttonTextColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;

                    final phoneStr = phoneCtrl.text.isNotEmpty ? phoneCtrl.text.trim() : '+91 99000 00000';
                    final newUdhaar = double.tryParse(udhaarCtrl.text) ?? 0.0;

                    final record = {
                      'name': nameCtrl.text.trim(),
                      'phone': phoneStr,
                      'email': emailCtrl.text.trim(),
                      'whatsapp': whatsappCtrl.text.trim(),
                      'fatherName': fatherCtrl.text.trim(),
                      'address': addressCtrl.text.trim(),
                      'village': villageCtrl.text.trim(),
                      'po': poCtrl.text.trim(),
                      'ps': psCtrl.text.trim(),
                      'dist': distCtrl.text.trim(),
                      'pincode': pincodeCtrl.text.trim(),
                      'udhaar': newUdhaar,
                      'lastTx': existing != null ? 'Profile Updated' : 'Registered Today',
                    };

                    // 1. Instantly update in-memory state
                    if (mounted) {
                      setState(() {
                        if (existing != null) {
                          existing['name'] = record['name'];
                          existing['phone'] = record['phone'];
                          existing['email'] = record['email'];
                          existing['whatsapp'] = record['whatsapp'];
                          existing['fatherName'] = record['fatherName'];
                          existing['address'] = record['address'];
                          existing['village'] = record['village'];
                          existing['po'] = record['po'];
                          existing['ps'] = record['ps'];
                          existing['dist'] = record['dist'];
                          existing['pincode'] = record['pincode'];
                          existing['udhaar'] = record['udhaar'];
                        } else {
                          _customers.insert(0, Map<String, dynamic>.from(record));
                        }
                      });
                    }

                    // 2. Instantly pop modal sheet so UI never freezes
                    if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                    }

                    // 3. Show feedback snackbar immediately
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            existing != null
                                ? (isHindi ? 'ग्राहक प्रोफाइल अपडेट हुई!' : 'Customer profile updated!')
                                : (isHindi ? 'ग्राहक सफलतापूर्वक सहेजा गया!' : 'Customer saved successfully!'),
                          ),
                          backgroundColor: Colors.green.shade700,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }

                    // 4. Perform background persistence (SQLite & HTTP API)
                    try {
                      final sqlite = SQLiteHelper.instance;
                      if (existing != null) {
                        final oldName = existing['name']?.toString() ?? nameCtrl.text.trim();
                        await sqlite.updateCustomerRecord(oldName, record);
                      } else {
                        await sqlite.saveCustomer(record);
                      }
                    } catch (_) {}

                    try {
                      final baseUrl = ApiConfig.baseUrl;
                      final targetId = existing != null ? (existing['id']?.toString() ?? existing['name']) : '';
                      if (existing != null && targetId != null && targetId.toString().isNotEmpty) {
                        await http.put(
                          Uri.parse('$baseUrl/customers/$targetId'),
                          headers: {'Content-Type': 'application/json'},
                          body: jsonEncode(record),
                        ).timeout(const Duration(seconds: 8));
                      } else {
                        await http.post(
                          Uri.parse('$baseUrl/customers'),
                          headers: {'Content-Type': 'application/json'},
                          body: jsonEncode(record),
                        ).timeout(const Duration(seconds: 8));
                      }
                      _loadCustomers(reset: true);
                    } catch (_) {}
                  },
                  child: Text(
                    existing != null ? (isHindi ? 'अपडेट सेव करें' : 'Update Profile') : (isHindi ? 'ग्राहक सेव करें' : 'Save Customer Profile'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
