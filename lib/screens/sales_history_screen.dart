import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/invoice_printer.dart';
import '../utils/whatsapp_helper.dart';
import '../widgets/app_drawer.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _salesList = [];
  String _searchQuery = '';

  double _totalRevenue = 0.0;
  double _cashRevenue = 0.0;
  double _udhaarRevenue = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchSalesHistory();
  }

  Future<void> _fetchSalesHistory() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final tId = prefs.getInt('tenant_id');
      final tCode = prefs.getString('tenant_code');
      final token = prefs.getString('auth_token') ?? '';

      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
      if (tId != null && tId > 0) headers['X-Tenant-Id'] = tId.toString();
      if (tCode != null && tCode.isNotEmpty) headers['X-Tenant-Code'] = tCode;

      final queryParams = <String>[];
      if (tId != null && tId > 0) queryParams.add('tenantId=$tId');
      if (tCode != null && tCode.isNotEmpty) queryParams.add('tenantCode=$tCode');
      final qStr = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';

      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/sales$qStr'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(res.body);
        final List<Map<String, dynamic>> loadedSales = jsonList.map((j) => Map<String, dynamic>.from(j)).toList();

        double totalRev = 0.0;
        double cashRev = 0.0;
        double udhaarRev = 0.0;

        for (var s in loadedSales) {
          final amt = (s['totalAmount'] as num?)?.toDouble() ?? 0.0;
          final mode = s['paymentMode']?.toString() ?? 'Cash';

          totalRev += amt;
          if (mode == 'Cash') cashRev += amt;
          if (mode == 'Udhaar') udhaarRev += amt;
        }

        setState(() {
          _salesList = loadedSales;
          _totalRevenue = totalRev;
          _cashRevenue = cashRev;
          _udhaarRevenue = udhaarRev;
        });
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  void _showProfessionalInvoiceModal(Map<String, dynamic> sale) {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final themeProvider = Provider.of<TenantThemeProvider>(context, listen: false);
    final isHindi = localeProvider.isHindi;

    final invoiceNo = sale['id']?.toString() ?? 'INV-${DateTime.now().millisecondsSinceEpoch}';
    final customerName = sale['customerName']?.toString() ?? 'Walk-in Customer';
    final paymentMode = sale['paymentMode']?.toString() ?? 'Cash';
    final grandTotal = (sale['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final createdAt = sale['createdAt']?.toString() ?? DateTime.now().toString().split('.')[0];
    final itemsList = (sale['items'] as List<dynamic>?) ?? [];

    double calculatedItemsGross = 0.0;
    for (var it in itemsList) {
      final qty = (it['quantity'] ?? it['qty'] ?? 1) as num;
      final price = (it['unitPrice'] ?? it['price'] ?? 0.0) as num;
      final total = (it['totalPrice'] ?? (qty.toDouble() * price.toDouble())) as num;
      calculatedItemsGross += total.toDouble();
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

    final phoneCtrl = TextEditingController(text: (sale['customerPhone'] != null && sale['customerPhone'].toString() != '9876543210') ? sale['customerPhone'].toString() : '');

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
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
                              Image.network(themeProvider.logoUrl, height: 50, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                            Text(
                              themeProvider.tenantName.isNotEmpty ? themeProvider.tenantName : "VILLAGE POS STORE",
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            ),
                            Text(
                              "${themeProvider.appTitle} • Billing & POS Solutions",
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                            if (themeProvider.supportPhone.isNotEmpty)
                              Text("Ph: ${themeProvider.supportPhone}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),

                      // Meta details: Invoice No, Customer, Date, Payment Mode
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
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
                                Text("Customer: $customerName", style: const TextStyle(fontWeight: FontWeight.bold)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: paymentMode == 'Udhaar' ? Colors.red.shade100 : Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    paymentMode.toUpperCase(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: paymentMode == 'Udhaar' ? Colors.red.shade900 : Colors.green.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Itemized Sales Tran Table
                      const Text(
                        "Itemized Purchased Products (बिक्री सामान विवरण):",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
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
                          ...itemsList.map((it) {
                            final name = it['productName'] ?? it['name'] ?? 'Product Item';
                            final qty = (it['quantity'] ?? it['qty'] ?? 1);
                            final price = (it['unitPrice'] ?? it['price'] ?? 0.0) as num;
                            final total = (it['totalPrice'] ?? (qty * price)) as num;
                            return TableRow(
                              children: [
                                Padding(padding: const EdgeInsets.all(6), child: Text(name.toString(), style: const TextStyle(fontSize: 12))),
                                Padding(padding: const EdgeInsets.all(6), child: Text(qty.toString(), style: const TextStyle(fontSize: 12), textAlign: TextAlign.center)),
                                Padding(padding: const EdgeInsets.all(6), child: Text("₹${price.toStringAsFixed(2)}", style: const TextStyle(fontSize: 12), textAlign: TextAlign.right)),
                                Padding(padding: const EdgeInsets.all(6), child: Text("₹${total.toStringAsFixed(2)}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                              ],
                            );
                          }).toList(),
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

                      // Customer Mobile Input for Instant WhatsApp share
                      TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: isHindi ? 'ग्राहक व्हाट्सएप नंबर' : 'Customer WhatsApp Mobile',
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

              // Action Buttons: Print A4 & WhatsApp Share
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                      icon: const Icon(Icons.print_rounded, size: 20),
                      label: Text(isHindi ? 'प्रिंट' : 'Print'),
                      onPressed: () {
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
                          items: itemsList,
                        );
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
                      icon: const Icon(Icons.send_rounded, size: 20),
                      label: const Text('WhatsApp Share'),
                      onPressed: () async {
                        final cleanPhone = phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
                        if (cleanPhone.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a valid customer mobile number to share WhatsApp invoice')),
                          );
                          return;
                        }

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
                          items: itemsList,
                        );

                        try {
                          final prefs = await SharedPreferences.getInstance();
                          final tId = prefs.getInt('tenant_id') ?? 1;
                          final token = prefs.getString('auth_token') ?? '';

                          final headers = <String, String>{'Content-Type': 'application/json'};
                          if (token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

                          final response = await http.post(
                            Uri.parse('${ApiConfig.baseUrl}/sales/send-whatsapp'),
                            headers: headers,
                            body: jsonEncode({
                              'tenantId': tId,
                              'phone': cleanPhone,
                              'message': messageText,
                            }),
                          ).timeout(const Duration(seconds: 12));

                          if (response.statusCode == 200) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('✅ Cloud Server WhatsApp message sent directly to +91 $cleanPhone!'),
                                  backgroundColor: const Color(0xFF25D366),
                                ),
                              );
                            }
                          } else {
                            WhatsAppHelper.openWhatsApp(phone: cleanPhone, message: messageText);
                          }
                        } catch (_) {
                          WhatsAppHelper.openWhatsApp(phone: cleanPhone, message: messageText);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final themeProvider = Provider.of<TenantThemeProvider>(context);
    final isHindi = localeProvider.isHindi;

    final filtered = _salesList.where((s) {
      final invId = s['id']?.toString().toLowerCase() ?? '';
      final cust = s['customerName']?.toString().toLowerCase() ?? '';
      final mode = s['paymentMode']?.toString().toLowerCase() ?? '';
      final q = _searchQuery.toLowerCase();
      return invId.contains(q) || cust.contains(q) || mode.contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(isHindi ? 'बिक्री इतिहास' : 'Sales History'),
        backgroundColor: themeProvider.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Sales',
            onPressed: _fetchSalesHistory,
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
          // Stat Overview Banner
          Container(
            padding: const EdgeInsets.all(14),
            color: themeProvider.primaryColor.withOpacity(0.06),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                    child: Column(
                      children: [
                        Text(isHindi ? 'कुल बिक्री' : 'Total Revenue', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 2),
                        Text('₹ ${_totalRevenue.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2563EB))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                    child: Column(
                      children: [
                        Text(isHindi ? 'नकद संग्रहित' : 'Cash Collected', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 2),
                        Text('₹ ${_cashRevenue.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                    child: Column(
                      children: [
                        Text(isHindi ? 'उधार बिक्री' : 'Udhaar Given', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 2),
                        Text('₹ ${_udhaarRevenue.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: TextField(
              decoration: InputDecoration(
                hintText: isHindi ? 'बिल नंबर या ग्राहक खोजें...' : 'Search invoice no, customer name...',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          // Sales List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              isHindi ? 'कोई बिक्री इतिहास नहीं मिला' : 'No Sale History Records Found',
                              style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(14),
                        itemCount: filtered.length,
                        separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                        itemBuilder: (ctx, idx) {
                          final sale = filtered[idx];
                          final invNo = sale['id']?.toString() ?? 'INV';
                          final cust = sale['customerName']?.toString() ?? 'Walk-in Customer';
                          final amt = (sale['totalAmount'] as num?)?.toDouble() ?? 0.0;
                          final mode = sale['paymentMode']?.toString() ?? 'Cash';
                          final time = sale['createdAt']?.toString() ?? '';
                          final items = (sale['items'] as List<dynamic>?) ?? [];

                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                                            child: const Icon(Icons.receipt_rounded, color: Color(0xFF2563EB)),
                                          ),
                                          const SizedBox(width: 10),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(invNo, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 14)),
                                              Text(time, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: mode == 'Udhaar' ? Colors.red.shade50 : Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: mode == 'Udhaar' ? Colors.red.shade200 : Colors.green.shade200),
                                        ),
                                        child: Text(
                                          mode,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: mode == 'Udhaar' ? Colors.red.shade800 : Colors.green.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('${isHindi ? "ग्राहक" : "Customer"}: $cust', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                          Text('${items.length} ${isHindi ? "सामान" : "items purchased"}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text('₹ ${amt.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            side: BorderSide(color: themeProvider.primaryColor),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          icon: Icon(Icons.print_rounded, size: 18, color: themeProvider.primaryColor),
                                          label: Text(
                                            isHindi ? 'देखें / प्रिंट' : 'View / Print',
                                            style: TextStyle(color: themeProvider.primaryColor, fontWeight: FontWeight.bold),
                                          ),
                                          onPressed: () => _showProfessionalInvoiceModal(sale),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.edit_note_rounded, color: Colors.blue),
                                        tooltip: 'Edit Invoice Metadata',
                                        onPressed: () => _showEditSaleModal(sale, isHindi, themeProvider),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
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

  void _showEditSaleModal(Map<String, dynamic> sale, bool isHindi, TenantThemeProvider themeProvider) {
    final custCtrl = TextEditingController(text: (sale['customerName'] ?? sale['customer'] ?? '').toString());
    final phoneCtrl = TextEditingController(text: (sale['customerPhone'] ?? '').toString());
    final amtCtrl = TextEditingController(text: (sale['totalAmount'] ?? sale['amount'] ?? 0.0).toString());
    final paidCtrl = TextEditingController(text: (sale['paidAmount'] ?? sale['totalAmount'] ?? 0.0).toString());
    String selectedMode = (sale['paymentMode'] ?? 'Cash').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 16,
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
                          isHindi ? 'एडिट करें' : 'Edit',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: themeProvider.primaryColor),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(modalCtx)),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text('Invoice ID: ${sale["id"] ?? sale["clientTransactionId"]}', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                    const SizedBox(height: 12),
                    TextField(
                      controller: custCtrl,
                      decoration: InputDecoration(
                        labelText: isHindi ? 'ग्राहक नाम' : 'Customer Name',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: isHindi ? 'ग्राहक मोबाइल' : 'Customer Phone',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: amtCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: isHindi ? 'कुल राशि' : 'Total Bill (₹)',
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: paidCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: isHindi ? 'प्राप्त नगद' : 'Paid Amount (₹)',
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: ['Cash', 'UPI', 'Udhaar'].contains(selectedMode) ? selectedMode : 'Cash',
                      decoration: InputDecoration(
                        labelText: isHindi ? 'भुगतान का प्रकार' : 'Payment Mode',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Cash', child: Text('Cash (नगद)')),
                        DropdownMenuItem(value: 'UPI', child: Text('UPI / Online')),
                        DropdownMenuItem(value: 'Udhaar', child: Text('Udhaar (उधार)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedMode = val);
                      },
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeProvider.buttonBgColor,
                          foregroundColor: themeProvider.buttonTextColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          setState(() {
                            sale['customerName'] = custCtrl.text.trim();
                            sale['customer'] = custCtrl.text.trim();
                            sale['customerPhone'] = phoneCtrl.text.trim();
                            sale['totalAmount'] = double.tryParse(amtCtrl.text) ?? sale['totalAmount'];
                            sale['paidAmount'] = double.tryParse(paidCtrl.text) ?? sale['paidAmount'];
                            sale['paymentMode'] = selectedMode;
                          });

                          Navigator.pop(modalCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isHindi ? 'इनवॉइस अपडेट किया गया!' : 'Invoice record updated successfully!'),
                              backgroundColor: Colors.green.shade700,
                            ),
                          );
                        },
                        child: Text(isHindi ? 'अपडेट सेव करें' : 'Save Invoice Edits', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
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
  }
}
