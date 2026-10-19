import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../database/sqlite_helper.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/sync_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/invoice_printer.dart';
import '../utils/whatsapp_helper.dart';
import '../widgets/app_drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _salesList = [];
  List<Map<String, dynamic>> _categorySummary = [];
  double _totalRevenue = 0.0;
  double _cashCollected = 0.0;
  double _upiCollected = 0.0;
  double _udhaarGiven = 0.0;
  int _totalInvoices = 0;
  String _selectedPeriod = 'All Time';
  String _selectedPaymentMode = 'All';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchReportData();
  }

  Future<void> _fetchReportData() async {
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final tCode = auth.tenantCode ?? '';
      final tId = auth.tenantId ?? 0;
      final token = auth.accessToken ?? '';

      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        if (tId > 0) 'X-Tenant-Id': tId.toString(),
        if (tCode.isNotEmpty) 'X-Tenant-Code': tCode,
      };

      final qParams = <String>[];
      if (tId > 0) qParams.add('tenantId=$tId');
      if (tCode.isNotEmpty) qParams.add('tenantCode=$tCode');
      final qStr = qParams.isNotEmpty ? '?${qParams.join('&')}' : '';
      final baseUrl = ApiConfig.baseUrl.isNotEmpty ? ApiConfig.baseUrl : 'https://villageshop-api.onrender.com/api';

      // 1. Fetch fast server-side metrics
      try {
        final resMetrics = await http.get(
          Uri.parse('$baseUrl/reports/dashboard-metrics$qStr'),
          headers: headers,
        ).timeout(const Duration(seconds: 8));
        if (resMetrics.statusCode == 200) {
          final mData = jsonDecode(resMetrics.body);
          if (mData is Map<String, dynamic>) {
            _totalRevenue = (mData['totalRevenue'] as num?)?.toDouble() ?? 0.0;
            _cashCollected = (mData['cashSales'] as num?)?.toDouble() ?? 0.0;
            _upiCollected = (mData['upiSales'] as num?)?.toDouble() ?? 0.0;
            _udhaarGiven = (mData['udhaarSales'] as num?)?.toDouble() ?? (mData['totalUdhaar'] as num?)?.toDouble() ?? 0.0;
            _totalInvoices = (mData['totalSales'] as num?)?.toInt() ?? 0;
          }
        }
      } catch (_) {}

      // 2. Fetch category summary from SQL aggregation
      try {
        final resCat = await http.get(
          Uri.parse('$baseUrl/reports/category-summary$qStr'),
          headers: headers,
        ).timeout(const Duration(seconds: 8));
        if (resCat.statusCode == 200) {
          final catData = jsonDecode(resCat.body);
          if (catData is Map && catData.containsKey('value')) {
            _categorySummary = List<Map<String, dynamic>>.from(catData['value']);
          } else if (catData is List) {
            _categorySummary = List<Map<String, dynamic>>.from(catData);
          }
        }
      } catch (_) {}

      // 3. Fetch sales records for detailed audit ledger
      final res = await http.get(
        Uri.parse('$baseUrl/sales$qStr'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final dynamic raw = jsonDecode(res.body);
        final List<dynamic> jsonList = raw is List ? raw : (raw['items'] as List? ?? []);
        final List<Map<String, dynamic>> loadedSales = jsonList.map((j) => Map<String, dynamic>.from(j)).toList();

        if (_totalRevenue == 0.0 && loadedSales.isNotEmpty) {
          double totalRev = 0.0;
          double cashTot = 0.0;
          double upiTot = 0.0;
          double udhaarTot = 0.0;
          for (var sale in loadedSales) {
            final amt = (sale['totalAmount'] as num?)?.toDouble() ?? 0.0;
            final mode = sale['paymentMode']?.toString() ?? 'Cash';
            totalRev += amt;
            if (mode == 'Cash') cashTot += amt;
            else if (mode == 'UPI') upiTot += amt;
            else if (mode == 'Udhaar') udhaarTot += amt;
          }
          _totalRevenue = totalRev;
          _cashCollected = cashTot;
          _upiCollected = upiTot;
          _udhaarGiven = udhaarTot;
          _totalInvoices = loadedSales.length;
        }

        _salesList = loadedSales;
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _showProfessionalInvoiceModal(Map<String, dynamic> sale) {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final isHindi = localeProvider.isHindi;
    final themeProvider = Provider.of<TenantThemeProvider>(context, listen: false);

    final invoiceNo = sale['id']?.toString() ?? 'INV-${DateTime.now().millisecondsSinceEpoch}';
    final customerName = sale['customerName']?.toString() ?? 'Walk-in Customer';
    final dynamic customerId = sale['customerId'];
    final paymentMode = sale['paymentMode']?.toString() ?? 'Cash';
    final createdAt = sale['createdAt']?.toString() ?? DateTime.now().toString().split('.')[0];
    final grandTotal = (sale['totalAmount'] ?? sale['amount'] as num?)?.toDouble() ?? 0.0;

    final itemsList = (sale['items'] as List<dynamic>?) ?? [];

    double calculatedItemsGross = 0.0;
    for (var it in itemsList) {
      if (it is Map) {
        final qty = (it['quantity'] ?? it['qty'] ?? 1) as num;
        final price = (it['unitPrice'] ?? it['price'] ?? 0.0) as num;
        final total = (it['totalPrice'] ?? it['totalAmount'] ?? (qty.toDouble() * price.toDouble())) as num;
        calculatedItemsGross += total.toDouble();
      }
    }

    final double rawGross = (sale['grossAmount'] ?? sale['subtotal'] ?? sale['subTotal'] as num?)?.toDouble() ?? calculatedItemsGross;
    final double rawDiscount = (sale['discountAmount'] ?? sale['discount'] as num?)?.toDouble() ?? 0.0;
    final double rawTax = (sale['taxAmount'] as num?)?.toDouble() ?? 0.0;

    double effectiveGross = rawGross;
    double effectiveDiscount = rawDiscount;

    if (effectiveDiscount <= 0.001 && rawGross > grandTotal) {
      effectiveDiscount = rawGross - grandTotal;
    }
    if (effectiveGross < grandTotal + effectiveDiscount) {
      effectiveGross = grandTotal + effectiveDiscount;
    }

    final rawPhone = sale['customerPhone'] ?? sale['customerMobile'] ?? sale['phone'] ?? sale['mobile'];
    final initialPhone = (rawPhone != null && rawPhone.toString().trim() != '9876543210')
        ? rawPhone.toString().trim()
        : '';

    final phoneCtrl = TextEditingController(text: initialPhone);
    bool isPrintingAction = false;
    bool isSendingWhatsApp = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          // Asynchronously resolve phone from Customer Master if empty
          if (phoneCtrl.text.isEmpty && customerName != 'Walk-in Customer') {
            Future.microtask(() async {
              try {
                final syncProvider = Provider.of<SyncProvider>(context, listen: false);
                final customers = await syncProvider.fetchCustomers();
                Map<String, dynamic>? matched;

                if (customerId != null) {
                  matched = customers.firstWhere(
                    (c) => c['id']?.toString() == customerId.toString(),
                    orElse: () => {},
                  );
                }
                if ((matched == null || matched.isEmpty) && customerName.isNotEmpty) {
                  matched = customers.firstWhere(
                    (c) => (c['name'] ?? '').toString().trim().toLowerCase() == customerName.trim().toLowerCase(),
                    orElse: () => {},
                  );
                }

                if (matched == null || matched.isEmpty) {
                  final dbCustomers = await SQLiteHelper.instance.getCustomers();
                  if (customerId != null) {
                    matched = dbCustomers.firstWhere(
                      (c) => c['id']?.toString() == customerId.toString(),
                      orElse: () => {},
                    );
                  }
                  if ((matched == null || matched.isEmpty) && customerName.isNotEmpty) {
                    matched = dbCustomers.firstWhere(
                      (c) => (c['name'] ?? '').toString().trim().toLowerCase() == customerName.trim().toLowerCase(),
                      orElse: () => {},
                    );
                  }
                }

                if (matched != null && matched.isNotEmpty) {
                  final foundPhone = (matched['phone'] ?? matched['mobile'] ?? '').toString().trim();
                  if (foundPhone.isNotEmpty && phoneCtrl.text.isEmpty && modalCtx.mounted) {
                    phoneCtrl.text = foundPhone;
                    setModalState(() {});
                  }
                }
              } catch (_) {}
            });
          }

          final isUdhaar = paymentMode.toLowerCase() == 'udhaar';

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              width: 600,
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with Title & Explicit Close Cut Icon (X)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.receipt_long_rounded, color: themeProvider.primaryColor, size: 28),
                          const SizedBox(width: 8),
                          Text(
                            isHindi ? 'टैक्स इनवॉइस रसीद' : 'Tax Invoice Receipt',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.red, size: 28),
                        tooltip: isHindi ? 'बंद करें' : 'Close Invoice',
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const Divider(height: 16, thickness: 1.5),

                  // Printable Invoice Content Area
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Store Branding Header
                          Center(
                            child: Column(
                              children: [
                                if (themeProvider.logoUrl.isNotEmpty)
                                  Image.network(themeProvider.logoUrl, height: 48, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                                Text(
                                  themeProvider.tenantName.isNotEmpty ? themeProvider.tenantName : "VILLAGE POS STORE",
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                ),
                                Text(
                                  "${themeProvider.appTitle.isNotEmpty ? themeProvider.appTitle : 'Village POS'} • Billing & POS Solutions",
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                ),
                                if (themeProvider.supportPhone.isNotEmpty)
                                  Text("Ph: ${themeProvider.supportPhone}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Meta details: Invoice No, Customer, Date, Payment Mode
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Inv #: $invoiceNo", style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                                    Text("Date: $createdAt", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Customer: $customerName", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isUdhaar ? Colors.red.shade100 : Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        isUdhaar ? "UDHAAR / DUE" : "PAID ($paymentMode)",
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isUdhaar ? Colors.red.shade900 : Colors.green.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Itemized Purchase Table
                          Table(
                            border: TableBorder.all(color: Colors.grey.shade300, width: 1),
                            columnWidths: const {
                              0: FlexColumnWidth(3),
                              1: FlexColumnWidth(1),
                              2: FlexColumnWidth(1.5),
                              3: FlexColumnWidth(1.5),
                            },
                            children: [
                              TableRow(
                                decoration: BoxDecoration(color: Colors.grey.shade200),
                                children: const [
                                  Padding(padding: EdgeInsets.all(6), child: Text("Item", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                  Padding(padding: EdgeInsets.all(6), child: Text("Qty", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
                                  Padding(padding: EdgeInsets.all(6), child: Text("Rate", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                                  Padding(padding: EdgeInsets.all(6), child: Text("Total", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                                ],
                              ),
                              if (itemsList.isEmpty)
                                TableRow(
                                  children: [
                                    const Padding(padding: EdgeInsets.all(6), child: Text("Store Merchandise", style: TextStyle(fontSize: 12))),
                                    const Padding(padding: EdgeInsets.all(6), child: Text("1", style: TextStyle(fontSize: 12), textAlign: TextAlign.center)),
                                    Padding(padding: const EdgeInsets.all(6), child: Text("₹${grandTotal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 12), textAlign: TextAlign.right)),
                                    Padding(padding: const EdgeInsets.all(6), child: Text("₹${grandTotal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                                  ],
                                )
                              else
                                ...itemsList.map((it) {
                                  final name = it['productName'] ?? it['name'] ?? 'Product Item';
                                  final qty = (it['quantity'] ?? it['qty'] ?? 1);
                                  final price = (it['unitPrice'] ?? it['price'] ?? 0.0) as num;
                                  final total = (it['totalPrice'] ?? it['totalAmount'] ?? (qty * price)) as num;
                                  return TableRow(
                                    children: [
                                      Padding(padding: const EdgeInsets.all(6), child: Text(name.toString(), style: const TextStyle(fontSize: 12))),
                                      Padding(padding: const EdgeInsets.all(6), child: Text(qty.toString(), style: const TextStyle(fontSize: 12), textAlign: TextAlign.center)),
                                      Padding(padding: const EdgeInsets.all(6), child: Text("₹${price.toStringAsFixed(2)}", style: const TextStyle(fontSize: 12), textAlign: TextAlign.right)),
                                      Padding(padding: const EdgeInsets.all(6), child: Text("₹${total.toStringAsFixed(2)}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                                    ],
                                  );
                                }),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Bill Financial Breakdown Card (Gross Amount, Discount, Net Amount)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text("Gross Amount (Subtotal):", style: TextStyle(fontSize: 13, color: Colors.black87)),
                                    Text("₹${effectiveGross.toStringAsFixed(2)}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                if (effectiveDiscount > 0.001) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text("Discount / Off:", style: TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.bold)),
                                      Text("- ₹${effectiveDiscount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                                if (rawTax > 0.001) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text("Tax Amount:", style: TextStyle(fontSize: 13, color: Colors.black87)),
                                      Text("+ ₹${rawTax.toStringAsFixed(2)}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ],
                                const Divider(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "NET AMOUNT (Grand Total):",
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green),
                                    ),
                                    Text(
                                      "₹${grandTotal.toStringAsFixed(2)}",
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(),

                          // Customer Mobile Input for Instant WhatsApp share & Print autofill
                          TextField(
                            controller: phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: isHindi ? 'ग्राहक व्हाट्सएप नंबर' : 'Customer WhatsApp Mobile',
                              hintText: 'Autofilled from Customer Master',
                              prefixIcon: const Icon(Icons.phone, color: Colors.green),
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Action Buttons: Print PDF & WhatsApp Share
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: themeProvider.primaryColor, width: 1.5),
                          ),
                          icon: isPrintingAction
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(Icons.print_rounded, size: 20, color: themeProvider.primaryColor),
                          label: Text(
                            isPrintingAction ? (isHindi ? 'लोड हो रहा है...' : 'Opening...') : (isHindi ? 'इनवॉइस प्रिंट / PDF' : 'Print Invoice / PDF'),
                            style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.primaryColor),
                          ),
                          onPressed: isPrintingAction
                              ? null
                              : () {
                                  setModalState(() => isPrintingAction = true);
                                  try {
                                    InvoicePrinter.showPrintPreviewModal(
                                      context,
                                      tenantName: themeProvider.tenantName,
                                      appTitle: themeProvider.appTitle,
                                      logoUrl: themeProvider.logoUrl,
                                      supportPhone: themeProvider.supportPhone,
                                      invoiceNo: invoiceNo,
                                      customerName: customerName,
                                      customerPhone: phoneCtrl.text.trim(),
                                      paymentMode: paymentMode,
                                      createdAt: createdAt,
                                      subtotal: effectiveGross,
                                      taxAmount: rawTax,
                                      discountAmount: effectiveDiscount,
                                      grandTotal: grandTotal,
                                      items: itemsList.isNotEmpty
                                          ? itemsList
                                          : [
                                              {
                                                'name': 'Store Purchase',
                                                'qty': 1,
                                                'price': grandTotal,
                                                'totalPrice': grandTotal,
                                              }
                                            ],
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Print preview error: $e'), backgroundColor: Colors.red),
                                    );
                                  } finally {
                                    if (modalCtx.mounted) {
                                      setModalState(() => isPrintingAction = false);
                                    }
                                  }
                                },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: isSendingWhatsApp
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.send_rounded, size: 20),
                          label: Text(
                            isSendingWhatsApp ? (isHindi ? 'भेज रहा है...' : 'Sending...') : 'WhatsApp Share',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: isSendingWhatsApp
                              ? null
                              : () async {
                                  final cleanPhone = phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
                                  if (cleanPhone.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Please enter a valid customer mobile number to share WhatsApp invoice')),
                                    );
                                    return;
                                  }

                                  setModalState(() => isSendingWhatsApp = true);

                                  final messageText = WhatsAppHelper.formatInvoiceMessage(
                                    tenantName: themeProvider.tenantName,
                                    invoiceNo: invoiceNo,
                                    customerName: customerName,
                                    paymentMode: paymentMode,
                                    createdAt: createdAt,
                                    subtotal: effectiveGross,
                                    discountAmount: effectiveDiscount,
                                    taxAmount: rawTax,
                                    grandTotal: grandTotal,
                                    items: itemsList.isNotEmpty
                                        ? itemsList
                                        : [
                                            {
                                              'name': 'Store Purchase',
                                              'qty': 1,
                                              'price': grandTotal,
                                              'totalPrice': grandTotal,
                                            }
                                          ],
                                  );

                                  try {
                                    final prefs = await SharedPreferences.getInstance();
                                    final tId = prefs.getInt('tenant_id') ?? 1;
                                    final token = prefs.getString('auth_token') ?? '';

                                    final response = await http.post(
                                      Uri.parse('${ApiConfig.baseUrl}/sales/send-whatsapp'),
                                      headers: {
                                        'Content-Type': 'application/json',
                                        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
                                      },
                                      body: jsonEncode({
                                        'tenantId': tId,
                                        'phone': cleanPhone,
                                        'message': messageText,
                                      }),
                                    ).timeout(const Duration(seconds: 8));

                                    if (response.statusCode == 200) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('WhatsApp invoice sent successfully to +91 $cleanPhone!'),
                                            backgroundColor: const Color(0xFF25D366),
                                          ),
                                        );
                                      }
                                    } else {
                                      WhatsAppHelper.openWhatsApp(phone: cleanPhone, message: messageText);
                                    }
                                  } catch (_) {
                                    WhatsAppHelper.openWhatsApp(phone: cleanPhone, message: messageText);
                                  } finally {
                                    if (modalCtx.mounted) {
                                      setModalState(() => isSendingWhatsApp = false);
                                    }
                                  }
                                },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredSales {
    final now = DateTime.now();
    return _salesList.where((sale) {
      if (_selectedPeriod != 'All Time') {
        final dateStr = sale['createdAt']?.toString() ?? '';
        final parsed = DateTime.tryParse(dateStr);
        if (parsed != null) {
          if (_selectedPeriod == 'Today') {
            if (parsed.year != now.year || parsed.month != now.month || parsed.day != now.day) {
              return false;
            }
          } else if (_selectedPeriod == 'Yesterday') {
            final yest = now.subtract(const Duration(days: 1));
            if (parsed.year != yest.year || parsed.month != yest.month || parsed.day != yest.day) {
              return false;
            }
          } else if (_selectedPeriod == 'This Week') {
            final weekAgo = now.subtract(const Duration(days: 7));
            if (parsed.isBefore(weekAgo)) return false;
          } else if (_selectedPeriod == 'This Month') {
            if (parsed.year != now.year || parsed.month != now.month) return false;
          }
        }
      }

      if (_selectedPaymentMode != 'All') {
        final mode = (sale['paymentMode']?.toString() ?? 'Cash').toLowerCase();
        if (_selectedPaymentMode.toLowerCase() != mode) {
          return false;
        }
      }

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final id = (sale['id'] ?? sale['invoiceNumber'] ?? '').toString().toLowerCase();
        final cust = (sale['customerName'] ?? '').toString().toLowerCase();
        final amt = (sale['totalAmount'] ?? '').toString();
        if (!id.contains(q) && !cust.contains(q) && !amt.contains(q)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  double get _periodRevenue {
    if (_selectedPeriod == 'All Time' && _totalRevenue > 0) return _totalRevenue;
    return _filteredSales.fold<double>(0.0, (sum, s) => sum + ((s['totalAmount'] as num?)?.toDouble() ?? 0.0));
  }

  double get _periodCash {
    if (_selectedPeriod == 'All Time' && _cashCollected > 0) return _cashCollected;
    return _filteredSales.where((s) => (s['paymentMode'] ?? 'Cash').toString().toLowerCase() == 'cash')
        .fold<double>(0.0, (sum, s) => sum + ((s['totalAmount'] as num?)?.toDouble() ?? 0.0));
  }

  double get _periodUpi {
    if (_selectedPeriod == 'All Time' && _upiCollected > 0) return _upiCollected;
    return _filteredSales.where((s) => (s['paymentMode'] ?? '').toString().toLowerCase() == 'upi')
        .fold<double>(0.0, (sum, s) => sum + ((s['totalAmount'] as num?)?.toDouble() ?? 0.0));
  }

  double get _periodUdhaar {
    if (_selectedPeriod == 'All Time' && _udhaarGiven > 0) return _udhaarGiven;
    return _filteredSales.where((s) => (s['paymentMode'] ?? '').toString().toLowerCase() == 'udhaar')
        .fold<double>(0.0, (sum, s) => sum + ((s['totalAmount'] as num?)?.toDouble() ?? 0.0));
  }

  int get _periodCount {
    if (_selectedPeriod == 'All Time' && _totalInvoices > 0) return _totalInvoices;
    return _filteredSales.length;
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = Provider.of<LocaleProvider>(context).isHindi;
    final themeProvider = Provider.of<TenantThemeProvider>(context);
    final filtered = _filteredSales;

    return Scaffold(
      backgroundColor: themeProvider.pageBgColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(
          isHindi ? 'वित्तीय रिपोर्ट एवं ऑडिट लेजर' : 'Financial & Audit Reports',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: isHindi ? 'रिफ्रेश करें' : 'Refresh',
            onPressed: _fetchReportData,
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchReportData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Audit Period Selector (Clean Professional Bar)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 18, color: themeProvider.primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          isHindi ? 'अवधि:' : 'Audit Period:',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: ['All Time', 'Today', 'Yesterday', 'This Week', 'This Month'].map((period) {
                                final isSelected = _selectedPeriod == period;
                                String label = period;
                                if (isHindi) {
                                  switch (period) {
                                    case 'All Time': label = 'कुल समय'; break;
                                    case 'Today': label = 'आज'; break;
                                    case 'Yesterday': label = 'कल'; break;
                                    case 'This Week': label = 'इस हफ्ते'; break;
                                    case 'This Month': label = 'इस महीने'; break;
                                  }
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ChoiceChip(
                                    label: Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        color: isSelected ? Colors.white : Colors.grey.shade800,
                                      ),
                                    ),
                                    selected: isSelected,
                                    selectedColor: themeProvider.primaryColor,
                                    backgroundColor: Colors.grey.shade100,
                                    elevation: isSelected ? 1 : 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    onSelected: (_) {
                                      setState(() => _selectedPeriod = period);
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Executive Financial KPI Cards
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 900;
                      final isMedium = constraints.maxWidth >= 600;
                      final count = isWide ? 5 : (isMedium ? 3 : 2);
                      final avgBill = _periodCount > 0 ? (_periodRevenue / _periodCount).toStringAsFixed(1) : "0";

                      return GridView.count(
                        crossAxisCount: count,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: isWide ? 1.8 : 1.7,
                        children: [
                          _buildReportCard(
                            context,
                            isHindi ? 'कुल कारोबार' : 'Gross Revenue',
                            '₹ ${_periodRevenue.toStringAsFixed(2)}',
                            '$_periodCount ${isHindi ? "बिल" : "bills"}',
                            Icons.monetization_on_rounded,
                            themeProvider.amountColor,
                            themeProvider,
                          ),
                          _buildReportCard(
                            context,
                            isHindi ? 'नकद वसूली' : 'Cash in Hand',
                            '₹ ${_periodCash.toStringAsFixed(2)}',
                            isHindi ? 'रजिस्टर में' : 'In Cash Drawer',
                            Icons.payments_rounded,
                            const Color(0xFF0D9488),
                            themeProvider,
                          ),
                          _buildReportCard(
                            context,
                            isHindi ? 'यूपीआई / ऑनलाइन' : 'UPI / Digital',
                            '₹ ${_periodUpi.toStringAsFixed(2)}',
                            isHindi ? 'डिजिटल पेमेंट' : 'Direct Bank',
                            Icons.qr_code_2_rounded,
                            const Color(0xFF2563EB),
                            themeProvider,
                          ),
                          _buildReportCard(
                            context,
                            isHindi ? 'उधार बकाया' : 'Udhaar Given',
                            '₹ ${_periodUdhaar.toStringAsFixed(2)}',
                            isHindi ? 'लेनदारियां' : 'Receivables',
                            Icons.assignment_late_rounded,
                            const Color(0xFFDC2626),
                            themeProvider,
                          ),
                          _buildReportCard(
                            context,
                            isHindi ? 'कुल रसीदें' : 'Invoices Audited',
                            '$_periodCount',
                            'Avg: ₹ $avgBill',
                            Icons.receipt_long_rounded,
                            const Color(0xFF7C3AED),
                            themeProvider,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // 3. Category Performance Ledger (Pure Tabular Audit Data)
                  if (_categorySummary.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: themeProvider.primaryColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.category_rounded, color: themeProvider.primaryColor, size: 18),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isHindi ? 'कैटेगरी-वार बिक्री विश्लेषण' : 'Category Performance Audit',
                              style: TextStyle(
                                fontFamily: themeProvider.fontFamily,
                                fontSize: 16 * themeProvider.fontSizeScale,
                                fontWeight: FontWeight.bold,
                                color: themeProvider.textColor,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${_categorySummary.length} ${isHindi ? "श्रेणियां" : "Categories"}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 700),
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                              headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                              dataRowMinHeight: 44,
                              dataRowMaxHeight: 48,
                              columns: [
                                DataColumn(label: Text(isHindi ? 'कैटेगरी' : 'Category')),
                                DataColumn(label: Text(isHindi ? 'उत्पाद' : 'Products'), numeric: true),
                                DataColumn(label: Text(isHindi ? 'बिकी यूनिट्स' : 'Units Sold'), numeric: true),
                                DataColumn(label: Text(isHindi ? 'कुल कमाई' : 'Total Revenue'), numeric: true),
                                DataColumn(label: Text(isHindi ? 'योगदान %' : 'Share (%)'), numeric: true),
                              ],
                              rows: _categorySummary.map((cat) {
                                final name = cat['category']?.toString() ?? 'General';
                                final pCount = cat['productCount'] ?? 0;
                                final sold = cat['itemsSold'] ?? 0;
                                final rev = (cat['totalRevenue'] as num?)?.toDouble() ?? 0.0;
                                final share = cat['sharePercent']?.toString() ?? '0%';

                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: themeProvider.primaryColor,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                    DataCell(Text('$pCount', style: const TextStyle(fontSize: 12))),
                                    DataCell(Text('$sold', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                                    DataCell(
                                      Text(
                                        '₹ ${rev.toStringAsFixed(2)}',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.amountColor, fontSize: 13),
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          share,
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 4. Sales Audit Ledger (Transaction History)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF059669), size: 18),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isHindi ? 'बिक्री ऑडिट लेजर' : 'Sales Transaction Audit Ledger',
                            style: TextStyle(
                              fontFamily: themeProvider.fontFamily,
                              fontSize: 16 * themeProvider.fontSizeScale,
                              fontWeight: FontWeight.bold,
                              color: themeProvider.textColor,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: themeProvider.buttonBgColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${filtered.length} ${isHindi ? "रसीदें" : "Invoices"}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Search & Payment Filter Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        TextField(
                          decoration: InputDecoration(
                            hintText: isHindi ? 'इनवॉइस नंबर या ग्राहक के नाम से खोजें...' : 'Search by invoice #, customer name, or amount...',
                            prefixIcon: const Icon(Icons.search_rounded, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () => setState(() => _searchQuery = ''),
                                  )
                                : null,
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val),
                        ),
                        const Divider(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: ['All', 'Cash', 'UPI', 'Udhaar'].map((mode) {
                              final isSelected = _selectedPaymentMode == mode;
                              String label = mode;
                              if (isHindi) {
                                switch (mode) {
                                  case 'All': label = 'सभी मोड'; break;
                                  case 'Cash': label = 'नकद (Cash)'; break;
                                  case 'UPI': label = 'यूपीआई (UPI)'; break;
                                  case 'Udhaar': label = 'उधार (Udhaar)'; break;
                                }
                              }
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: FilterChip(
                                  label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.white : Colors.black87)),
                                  selected: isSelected,
                                  selectedColor: themeProvider.primaryColor,
                                  backgroundColor: Colors.grey.shade100,
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  onSelected: (_) => setState(() => _selectedPaymentMode = mode),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_isLoading)
                    const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
                  else if (filtered.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text(
                              isHindi ? 'इस फिल्टर के तहत कोई बिक्री रसीद नहीं मिली।' : 'No sales records found matching the selected filter.',
                              style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                      itemBuilder: (ctx, index) {
                        final sale = filtered[index];
                        final invoiceNo = sale['id']?.toString() ?? sale['invoiceNumber']?.toString() ?? 'INV';
                        final customer = sale['customerName']?.toString() ?? 'Walk-in Customer';
                        final amt = (sale['totalAmount'] as num?)?.toDouble() ?? 0.0;
                        final mode = sale['paymentMode']?.toString() ?? 'Cash';
                        final time = sale['createdAt']?.toString() ?? '';
                        final itemsCount = (sale['items'] as List?)?.length ?? 1;

                        Color modeColor = Colors.green.shade700;
                        Color modeBg = Colors.green.shade50;
                        if (mode.toLowerCase() == 'udhaar') {
                          modeColor = Colors.red.shade700;
                          modeBg = Colors.red.shade50;
                        } else if (mode.toLowerCase() == 'upi') {
                          modeColor = Colors.blue.shade700;
                          modeBg = Colors.blue.shade50;
                        }

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            onTap: () => _showProfessionalInvoiceModal(sale),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            leading: CircleAvatar(
                              backgroundColor: modeBg,
                              child: Icon(
                                mode.toLowerCase() == 'udhaar'
                                    ? Icons.assignment_late_rounded
                                    : (mode.toLowerCase() == 'upi' ? Icons.qr_code_2_rounded : Icons.receipt_long_rounded),
                                color: modeColor,
                                size: 20,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    customer,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: modeBg, borderRadius: BorderRadius.circular(6)),
                                  child: Text(
                                    mode.toUpperCase(),
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: modeColor),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Text(
                                    invoiceNo,
                                    style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('• $time', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                  const SizedBox(width: 8),
                                  Text('• $itemsCount items', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                ],
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹ ${amt.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: mode.toLowerCase() == 'udhaar' ? Colors.red.shade700 : Colors.green.shade800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.print_rounded, size: 11, color: themeProvider.primaryColor),
                                    const SizedBox(width: 3),
                                    Text(
                                      isHindi ? 'रसीद देखें' : 'View Receipt',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: themeProvider.primaryColor),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard(
    BuildContext context,
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
    TenantThemeProvider themeProvider,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: themeProvider.cardBgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: themeProvider.fontFamily,
                    fontSize: 12 * themeProvider.fontSizeScale,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.textColor.withOpacity(0.7),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontFamily: themeProvider.fontFamily,
                    fontSize: 17 * themeProvider.fontSizeScale,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
