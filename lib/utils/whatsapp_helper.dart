import 'package:flutter/foundation.dart';
import 'whatsapp_helper_stub.dart'
    if (dart.library.js_interop) 'whatsapp_helper_web.dart';

class WhatsAppHelper {
  /// Opens WhatsApp URL in browser or WhatsApp app
  static void openWhatsApp({required String phone, required String message}) {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.isEmpty) return;
    final targetPhone = cleanPhone.startsWith('91') ? cleanPhone : '91$cleanPhone';
    final encoded = Uri.encodeComponent(message);
    final waUrl = 'https://api.whatsapp.com/send?phone=$targetPhone&text=$encoded';

    if (kIsWeb) {
      openWhatsAppUrlWeb(waUrl);
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
}
