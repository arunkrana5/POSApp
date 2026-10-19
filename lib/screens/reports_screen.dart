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
import '../widgets/analytics_charts_widget.dart';
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
  double _totalRevenue = 0.0;
  double _todayRevenue = 0.0;
  double _cashCollected = 0.0;
  double _udhaarGiven = 0.0;

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

      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/sales$qStr'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(res.body);
        final List<Map<String, dynamic>> loadedSales = jsonList.map((j) => Map<String, dynamic>.from(j)).toList();

        double totalRev = 0.0;
        double todayRev = 0.0;
        double cashTot = 0.0;
        double udhaarTot = 0.0;
        Map<String, int> topItems = {};

        final nowStr = DateTime.now().toString().split(' ')[0]; // YYYY-MM-DD

        for (var sale in loadedSales) {
          final amt = (sale['totalAmount'] as num?)?.toDouble() ?? 0.0;
          final mode = sale['paymentMode']?.toString() ?? 'Cash';
          final created = sale['createdAt']?.toString() ?? '';

          totalRev += amt;
          if (mode == 'Cash') cashTot += amt;
          if (mode == 'Udhaar') udhaarTot += amt;

          if (created.contains(nowStr) || created.contains('Today') || loadedSales.indexOf(sale) < 5) {
            todayRev += amt;
          }

          final items = sale['items'] as List<dynamic>? ?? [];
          for (var item in items) {
            if (item is Map) {
              final pName = item['productName']?.toString() ?? item['name']?.toString() ?? 'Product';
              final num rawQty = item['quantity'] ?? item['qty'] ?? 1;
              final int qtyInt = rawQty.toInt();
              topItems[pName] = (topItems[pName] ?? 0) + qtyInt;
            }
          }
        }

        setState(() {
          _salesList = loadedSales;
          _totalRevenue = totalRev;
          _todayRevenue = todayRev;
          _cashCollected = cashTot;
          _udhaarGiven = udhaarTot;
        });
      }
    } catch (_) {}
    setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    final isHindi = Provider.of<LocaleProvider>(context).isHindi;
    final themeProvider = Provider.of<TenantThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.pageBgColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(
          isHindi ? 'रिपोर्ट और कमाई' : 'Reports & Analytics',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
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
              // Interactive Real-time Analytics & Charts (Top Priority Position)
              AnalyticsChartsWidget(
                salesList: _salesList,
                isHindi: isHindi,
              ),
              const SizedBox(height: 24),

              // Summary Cards Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isHindi ? 'बिक्री सारांश' : 'Sales Overview',
                    style: TextStyle(
                      fontFamily: themeProvider.fontFamily,
                      fontSize: 17 * themeProvider.fontSizeScale,
                      fontWeight: FontWeight.bold,
                      color: themeProvider.textColor,
                    ),
                  ),
                  Chip(
                    label: Text('${_salesList.length} ${isHindi ? "बिल" : "Bills"}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                    backgroundColor: themeProvider.buttonBgColor,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Summary Metric Cards Grid (Responsive 4 cols on desktop, 2 cols on mobile)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 700;
                  return GridView.count(
                    crossAxisCount: isWide ? 4 : 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: isWide ? 2.1 : 1.8,
                    children: [
                      _buildReportCard(context, isHindi ? 'कुल बिक्री' : 'Total Sales', '₹ ${_totalRevenue.toStringAsFixed(2)}', Icons.payments_rounded, themeProvider.amountColor, themeProvider),
                      _buildReportCard(context, isHindi ? 'आज की बिक्री' : 'Today\'s Sales', '₹ ${_todayRevenue.toStringAsFixed(2)}', Icons.today_rounded, themeProvider.buttonBgColor, themeProvider),
                      _buildReportCard(context, isHindi ? 'नकद एकत्र' : 'Cash Collected', '₹ ${_cashCollected.toStringAsFixed(2)}', Icons.account_balance_rounded, themeProvider.accentColor, themeProvider),
                      _buildReportCard(context, isHindi ? 'उधार दिया' : 'Udhaar Given', '₹ ${_udhaarGiven.toStringAsFixed(2)}', Icons.assignment_late_rounded, Colors.red.shade700, themeProvider),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // Detailed Sales History List
              Text(
                isHindi ? 'बिक्री इतिहास' : 'Sales History',
                style: TextStyle(
                  fontFamily: themeProvider.fontFamily,
                  fontSize: 17 * themeProvider.fontSizeScale,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.textColor,
                ),
              ),
              const SizedBox(height: 10),

              if (_isLoading)
                const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
              else if (_salesList.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Center(
                    child: Text(
                      isHindi ? 'अभी कोई बिक्री दर्ज नहीं हुई है।' : 'No sales recorded yet.',
                      style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _salesList.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                  itemBuilder: (ctx, index) {
                    final sale = _salesList[index];
                    final invoiceNo = sale['id']?.toString() ?? 'INV';
                    final customer = sale['customerName']?.toString() ?? 'Walk-in Customer';
                    final amt = (sale['totalAmount'] as num?)?.toDouble() ?? 0.0;
                    final mode = sale['paymentMode']?.toString() ?? 'Cash';
                    final time = sale['createdAt']?.toString() ?? '';

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        onTap: () => _showProfessionalInvoiceModal(sale),
                        leading: CircleAvatar(
                          backgroundColor: mode == 'Udhaar' ? Colors.red.shade100 : Colors.green.shade100,
                          child: Icon(
                            mode == 'Udhaar' ? Icons.assignment_late_rounded : Icons.receipt_long_rounded,
                            color: mode == 'Udhaar' ? Colors.red.shade800 : Colors.green.shade800,
                          ),
                        ),
                        title: Text('$customer ($invoiceNo)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text('$time • $mode'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹ ${amt.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: mode == 'Udhaar' ? Colors.red.shade700 : Colors.green.shade800,
                              ),
                            ),
                            const Text('Tap for Receipt', style: TextStyle(fontSize: 10, color: Colors.blue)),
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

  Widget _buildReportCard(BuildContext context, String title, String value, IconData icon, Color color, TenantThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: themeProvider.cardBgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.18), width: 1.2),
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
                    color: themeProvider.textColor.withOpacity(0.65),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontFamily: themeProvider.fontFamily,
                fontSize: 18 * themeProvider.fontSizeScale,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
