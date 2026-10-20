import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'whatsapp_phone_normalizer.dart';
import 'whatsapp_helper_stub.dart'
    if (dart.library.js_interop) 'whatsapp_helper_web.dart';

class WhatsAppHelper {
  /// Opens WhatsApp URL in browser or native WhatsApp application with pre-filled message (100% Free / Unlimited)
  static bool openWhatsApp({
    BuildContext? context,
    required String phone,
    required String message,
  }) {
    final norm = WhatsAppPhoneNormalizer.normalize(phone);
    final targetPhone = norm.isValid ? norm.normalizedPhone : phone.replaceAll(RegExp(r'\D'), '');
    if (targetPhone.isEmpty) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid mobile number')),
        );
      }
      return false;
    }

    final encoded = Uri.encodeComponent(message);
    final waUrl = 'https://api.whatsapp.com/send?phone=$targetPhone&text=$encoded';
    openWhatsAppUrlPlatform(waUrl);

    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📱 Opening WhatsApp for +$targetPhone...'),
          backgroundColor: const Color(0xFF25D366),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    return true;
  }

  /// Dispatches WhatsApp message via Backend Cloud Gateway (Green API)
  /// with automated validation, error reporting, and fallback to native WhatsApp.
  static Future<bool> sendCloudWhatsApp({
    required BuildContext context,
    required String phone,
    required String message,
    int? tenantId,
  }) async {
    final norm = WhatsAppPhoneNormalizer.normalize(phone);
    if (!norm.isValid) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(norm.errorMessage),
            backgroundColor: Colors.orange.shade800,
          ),
        );
      }
      return false;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final effectiveTenantId = tenantId ?? prefs.getInt('tenant_id') ?? 1;
      final token = prefs.getString('auth_token') ?? '';

      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        'X-Tenant-Id': effectiveTenantId.toString(),
      };

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/sales/send-whatsapp'),
        headers: headers,
        body: jsonEncode({
          'tenantId': effectiveTenantId,
          'phone': norm.normalizedPhone,
          'message': message,
        }),
      ).timeout(const Duration(seconds: 12));

      Map<String, dynamic>? resData;
      try {
        resData = jsonDecode(response.body) as Map<String, dynamic>?;
      } catch (_) {}

      final bool isSuccess = response.statusCode == 200 && (resData?['status'] == true);

      if (isSuccess) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ WhatsApp message sent directly to +${norm.normalizedPhone}!'),
              backgroundColor: const Color(0xFF25D366),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return true;
      } else {
        final errorMsg = resData?['message']?.toString() ??
            'WhatsApp Gateway returned status ${response.statusCode}';
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ $errorMsg. Opening WhatsApp app...'),
              backgroundColor: Colors.orange.shade800,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        openWhatsApp(phone: norm.normalizedPhone, message: message);
        return false;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('⚠️ Cloud Gateway unreachable. Opening WhatsApp app...'),
            backgroundColor: Colors.orange.shade800,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      openWhatsApp(phone: norm.normalizedPhone, message: message);
      return false;
    }
  }

  /// Builds ultra-professional tax invoice message for WhatsApp
  static String formatInvoiceMessage({
    required String tenantName,
    required String invoiceNo,
    required String customerName,
    required String paymentMode,
    required String createdAt,
    required double subtotal,
    required double discountAmount,
    required double taxAmount,
    required double grandTotal,
    required List<dynamic> items,
  }) {
    final storeName = tenantName.isNotEmpty ? tenantName.toUpperCase() : 'VILLAGE POS STORE';
    final StringBuffer sb = StringBuffer();

    sb.writeln('🧾 *OFFICIAL TAX INVOICE*');
    sb.writeln('🏪 *$storeName*');
    sb.writeln('--------------------------------------------------');
    sb.writeln('📄 *Invoice No:* $invoiceNo');
    sb.writeln('📅 *Date:* $createdAt');
    sb.writeln('👤 *Customer:* $customerName');
    sb.writeln('💳 *Payment Mode:* $paymentMode');
    sb.writeln('--------------------------------------------------');
    sb.writeln('🛒 *PURCHASED PRODUCTS:*');
    sb.writeln('');

    int idx = 1;
    for (var it in items) {
      String name = 'Item';
      num qty = 1;
      double price = 0.0;
      double total = 0.0;

      if (it is Map) {
        name = (it['productName'] ?? it['name'] ?? 'Item').toString();
        qty = (it['quantity'] ?? it['qty'] ?? 1) as num;
        price = ((it['unitPrice'] ?? it['price'] ?? 0.0) as num).toDouble();
        total = ((it['totalPrice'] ?? (qty * price)) as num).toDouble();
      }

      sb.writeln(' $idx. *$name*');
      sb.writeln('     Qty: $qty x ₹${price.toStringAsFixed(2)}  =  *₹${total.toStringAsFixed(2)}*');
      sb.writeln('');
      idx++;
    }

    sb.writeln('--------------------------------------------------');
    sb.writeln('💰 *BILL SUMMARY:*');
    sb.writeln('💵 *Gross Amount (Subtotal):* ₹${subtotal.toStringAsFixed(2)}');
    if (discountAmount > 0.001) {
      sb.writeln('🎉 *Discount / Off:* - ₹${discountAmount.toStringAsFixed(2)}');
    }
    if (taxAmount > 0.001) {
      sb.writeln('🏛️ *Tax Amount:* + ₹${taxAmount.toStringAsFixed(2)}');
    }
    sb.writeln('--------------------------------------------------');
    sb.writeln('✅ *NET GRAND TOTAL:* *₹${grandTotal.toStringAsFixed(2)}*');
    sb.writeln('==================================');
    sb.writeln('🙏 *Thank you for shopping with us!*');
    sb.writeln('⭐ Have a wonderful day!');

    return sb.toString();
  }

  static String formatLedgerReminderMessage({
    required String tenantName,
    required String customerName,
    required double currentBalance,
    required List<dynamic> transactions,
    String? upiId,
    String? accountName,
    String? bankName,
  }) {
    final storeName = tenantName.isNotEmpty ? tenantName.toUpperCase() : 'VILLAGE POS STORE';
    final StringBuffer sb = StringBuffer();

    sb.writeln('📜 *CUSTOMER LEDGER STATEMENT & OUTSTANDING REMINDER*');
    sb.writeln('🏪 *$storeName*');
    sb.writeln('--------------------------------------------------');
    sb.writeln('👤 *Customer Name:* $customerName');
    sb.writeln('📅 *Statement Date:* ${DateTime.now().toString().substring(0, 10)}');
    sb.writeln('⚠️ *Net Outstanding Balance:* *₹${currentBalance.toStringAsFixed(2)}*');
    sb.writeln('--------------------------------------------------');
    sb.writeln('📋 *RECENT TRANSACTIONS:*');
    sb.writeln('');

    int idx = 1;
    for (var tx in transactions.take(10)) {
      if (tx is Map) {
        final date = (tx['date'] ?? '').toString();
        final desc = (tx['description'] ?? 'Tx').toString();
        final mode = (tx['paymentMode'] ?? '').toString();
        final items = (tx['itemsSummary'] ?? '').toString();
        final bill = ((tx['debit'] ?? tx['totalAmount'] ?? 0.0) as num).toDouble();
        final paid = ((tx['credit'] ?? tx['paidAmount'] ?? 0.0) as num).toDouble();
        final bal = ((tx['balance'] ?? 0.0) as num).toDouble();
        final status = (tx['status'] ?? '').toString();

        sb.writeln('$idx. *$date* - $desc');
        if (items.isNotEmpty) sb.writeln('    🛒 Items: $items');
        if (mode.isNotEmpty) sb.writeln('    💳 Mode: $mode ($status)');
        if (bill > 0) sb.writeln('    Bill Amount: ₹${bill.toStringAsFixed(2)}');
        if (paid > 0) sb.writeln('    Paid: ₹${paid.toStringAsFixed(2)}');
        sb.writeln('    Running Balance: ₹${bal.toStringAsFixed(2)}');
        sb.writeln('');
        idx++;
      }
    }

    sb.writeln('--------------------------------------------------');
    if (upiId != null && upiId.isNotEmpty) {
      sb.writeln('💳 *PAYMENT DETAILS (UPI):*');
      sb.writeln('👤 *Account Name:* ${accountName ?? tenantName}');
      if (bankName != null && bankName.isNotEmpty) {
        sb.writeln('🏦 *Bank:* $bankName');
      }
      sb.writeln('📱 *UPI ID:* `$upiId`');
      sb.writeln('--------------------------------------------------');
    }
    sb.writeln('👉 *Kindly clear the outstanding dues of ₹${currentBalance.toStringAsFixed(2)} at your earliest convenience.*');
    sb.writeln('🙏 *Thank you for your continued business!*');

    return sb.toString();
  }
}
