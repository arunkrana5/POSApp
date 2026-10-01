import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'printer_helper.dart';

enum PrintFormat { a4, thermal }

class InvoicePrinter {
  /// Helper method to compute robust discount amount
  static double _calculateEffectiveDiscount({
    required double subtotal,
    required double taxAmount,
    required double discountAmount,
    required double grandTotal,
    required List<dynamic> items,
  }) {
    if (discountAmount > 0) return discountAmount;

    double itemsSum = 0.0;
    for (var it in items) {
      if (it is Map) {
        final qty = (it['quantity'] ?? it['qty'] ?? 1) as num;
        final price = (it['unitPrice'] ?? it['price'] ?? 0.0) as num;
        itemsSum += (it['totalPrice'] as num?)?.toDouble() ?? (qty * price).toDouble();
      }
    }

    final double baseSubtotal = subtotal > 0 ? subtotal : (itemsSum > 0 ? itemsSum : grandTotal);
    final double diff = (baseSubtotal + taxAmount) - grandTotal;
    return diff > 0.01 ? diff : 0.0;
  }

  /// Helper method to compute base subtotal
  static double _calculateBaseSubtotal({
    required double subtotal,
    required double grandTotal,
    required List<dynamic> items,
  }) {
    if (subtotal > 0) return subtotal;
    double itemsSum = 0.0;
    for (var it in items) {
      if (it is Map) {
        final qty = (it['quantity'] ?? it['qty'] ?? 1) as num;
        final price = (it['unitPrice'] ?? it['price'] ?? 0.0) as num;
        itemsSum += (it['totalPrice'] as num?)?.toDouble() ?? (qty * price).toDouble();
      }
    }
    return itemsSum > 0 ? itemsSum : grandTotal;
  }

  /// Entry point to show modern print & receipt preview dialog with format selection
  static void showPrintPreviewModal(
    BuildContext context, {
    required String tenantName,
    required String appTitle,
    required String logoUrl,
    required String supportPhone,
    required String invoiceNo,
    required String customerName,
    required String customerPhone,
    required String paymentMode,
    required String createdAt,
    required double subtotal,
    required double taxAmount,
    double discountAmount = 0.0,
    required double grandTotal,
    required List<dynamic> items,
    Color? primaryColor,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _InvoicePreviewSheet(
        tenantName: tenantName,
        appTitle: appTitle,
        logoUrl: logoUrl,
        supportPhone: supportPhone,
        invoiceNo: invoiceNo,
        customerName: customerName,
        customerPhone: customerPhone,
        paymentMode: paymentMode,
        createdAt: createdAt,
        subtotal: subtotal,
        taxAmount: taxAmount,
        discountAmount: discountAmount,
        grandTotal: grandTotal,
        items: items,
        primaryColor: primaryColor ?? Theme.of(context).primaryColor,
      ),
    );
  }

  /// Triggers print directly for a specific format
  static void printInvoice({
    required PrintFormat format,
    required String tenantName,
    required String appTitle,
    required String logoUrl,
    required String supportPhone,
    required String invoiceNo,
    required String customerName,
    required String customerPhone,
    required String paymentMode,
    required String createdAt,
    required double subtotal,
    required double taxAmount,
    double discountAmount = 0.0,
    required double grandTotal,
    required List<dynamic> items,
  }) {
    final String htmlContent = format == PrintFormat.a4
        ? generateA4InvoiceHtml(
            tenantName: tenantName,
            appTitle: appTitle,
            logoUrl: logoUrl,
            supportPhone: supportPhone,
            invoiceNo: invoiceNo,
            customerName: customerName,
            customerPhone: customerPhone,
            paymentMode: paymentMode,
            createdAt: createdAt,
            subtotal: subtotal,
            taxAmount: taxAmount,
            discountAmount: discountAmount,
            grandTotal: grandTotal,
            items: items,
          )
        : generateThermalReceiptHtml(
            tenantName: tenantName,
            appTitle: appTitle,
            supportPhone: supportPhone,
            invoiceNo: invoiceNo,
            customerName: customerName,
            customerPhone: customerPhone,
            paymentMode: paymentMode,
            createdAt: createdAt,
            subtotal: subtotal,
            taxAmount: taxAmount,
            discountAmount: discountAmount,
            grandTotal: grandTotal,
            items: items,
          );

    PrinterHelper.printHtml(htmlContent);
  }

  /// Generates Standard A4 GST Tax Invoice HTML
  static String generateA4InvoiceHtml({
    required String tenantName,
    required String appTitle,
    required String logoUrl,
    required String supportPhone,
    required String invoiceNo,
    required String customerName,
    required String customerPhone,
    required String paymentMode,
    required String createdAt,
    required double subtotal,
    required double taxAmount,
    double discountAmount = 0.0,
    required double grandTotal,
    required List<dynamic> items,
  }) {
    final StringBuffer itemsRows = StringBuffer();
    int srNo = 1;
    for (var it in items) {
      final name = (it['productName'] ?? it['name'] ?? 'Product Item').toString();
      final qty = (it['quantity'] ?? it['qty'] ?? 1);
      final price = ((it['unitPrice'] ?? it['price'] ?? 0.0) as num).toDouble();
      final tot = ((it['totalPrice'] ?? (qty * price)) as num).toDouble();

      itemsRows.write('''
        <tr>
          <td style="text-align: center; font-size: 12px; padding: 10px; border: 1px solid #E2E8F0; color: #475569;">$srNo</td>
          <td style="font-size: 13px; font-weight: 700; padding: 10px; border: 1px solid #E2E8F0; color: #0F172A;">$name</td>
          <td style="text-align: center; font-size: 13px; font-weight: 600; padding: 10px; border: 1px solid #E2E8F0; color: #0F172A;">$qty</td>
          <td style="text-align: right; font-size: 13px; padding: 10px; border: 1px solid #E2E8F0; color: #334155;">₹ ${price.toStringAsFixed(2)}</td>
          <td style="text-align: right; font-size: 13px; font-weight: 800; padding: 10px; border: 1px solid #E2E8F0; color: #0F172A;">₹ ${tot.toStringAsFixed(2)}</td>
        </tr>
      ''');
      srNo++;
    }

    final double effectiveSubtotal = _calculateBaseSubtotal(
      subtotal: subtotal,
      grandTotal: grandTotal,
      items: items,
    );

    final double effectiveDiscount = _calculateEffectiveDiscount(
      subtotal: subtotal,
      taxAmount: taxAmount,
      discountAmount: discountAmount,
      grandTotal: grandTotal,
      items: items,
    );

    final isUdhaar = paymentMode.toLowerCase() == 'udhaar';
    final storeTitle = tenantName.isNotEmpty ? tenantName : "VILLAGE POS STORE";
    final cleanPhone = supportPhone.replaceAll(RegExp(r'\D'), '');
    final qrUpiUrl = cleanPhone.isNotEmpty
        ? "https://api.qrserver.com/v1/create-qr-code/?size=120x120&data=upi://pay?pa=$cleanPhone@upi&pn=${Uri.encodeComponent(storeTitle)}&am=${grandTotal.toStringAsFixed(2)}&tn=Invoice_$invoiceNo"
        : "";

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Tax Invoice - $invoiceNo</title>
  <style>
    @page {
      size: A4 portrait;
      margin: 10mm;
    }
    * {
      box-sizing: border-box;
      -webkit-print-color-adjust: exact !important;
      print-color-adjust: exact !important;
    }
    body {
      font-family: system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      color: #0F172A;
      margin: 0;
      padding: 16px;
      background: #FFFFFF;
    }
    .invoice-wrapper {
      max-width: 800px;
      margin: 0 auto;
      border: 1px solid #CBD5E1;
      border-radius: 8px;
      padding: 24px;
      box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05);
      background: #FFFFFF;
    }
    .top-accent-bar {
      height: 6px;
      background: linear-gradient(90deg, #0F172A 0%, #2563EB 50%, #10B981 100%);
      border-top-left-radius: 7px;
      border-top-right-radius: 7px;
      margin: -24px -24px 20px -24px;
    }
    .header-table {
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 20px;
    }
    .store-brand {
      font-size: 24px;
      font-weight: 900;
      color: #0F172A;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      line-height: 1.1;
    }
    .store-sub {
      font-size: 13px;
      color: #475569;
      margin-top: 3px;
    }
    .invoice-badge {
      display: inline-block;
      background: #0F172A;
      color: #FFFFFF;
      font-size: 15px;
      font-weight: 900;
      padding: 5px 14px;
      border-radius: 4px;
      letter-spacing: 1px;
      text-transform: uppercase;
    }
    .invoice-meta-text {
      font-size: 13px;
      color: #334155;
      text-align: right;
      margin-top: 4px;
    }
    .customer-box {
      background: #F8FAFC;
      border: 1px solid #E2E8F0;
      border-radius: 6px;
      padding: 14px 18px;
      margin-bottom: 20px;
    }
    .items-table {
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 20px;
    }
    .items-table th {
      background: #0F172A;
      color: #FFFFFF;
      font-size: 11px;
      font-weight: 700;
      text-transform: uppercase;
      padding: 10px;
      border: 1px solid #0F172A;
      letter-spacing: 0.5px;
    }
    .summary-grid {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      margin-bottom: 24px;
    }
    .upi-qr-box {
      border: 1px dashed #CBD5E1;
      border-radius: 6px;
      padding: 10px 14px;
      background: #FAFAFA;
      text-align: center;
      width: 220px;
    }
    .summary-box {
      width: 320px;
      border: 1px solid #E2E8F0;
      border-radius: 6px;
      overflow: hidden;
    }
    .summary-table {
      width: 100%;
      border-collapse: collapse;
    }
    .summary-table td {
      padding: 8px 12px;
      font-size: 13px;
      border-bottom: 1px solid #F1F5F9;
    }
    .total-row {
      font-size: 16px !important;
      font-weight: 900;
      color: #FFFFFF !important;
      background: #0F172A;
    }
    .total-row td {
      border-bottom: none !important;
    }
    .footer-note {
      margin-top: 24px;
      padding-top: 16px;
      border-top: 1px dashed #CBD5E1;
      text-align: center;
      font-size: 12px;
      color: #64748B;
    }
  </style>
</head>
<body>
  <div class="invoice-wrapper">
    <div class="top-accent-bar"></div>
    <table class="header-table">
      <tr>
        <td style="vertical-align: top;">
          ${logoUrl.isNotEmpty ? '<img src="' + logoUrl + '" style="max-height: 50px; margin-bottom: 6px; border-radius: 4px;"><br>' : ''}
          <div class="store-brand">$storeTitle</div>
          <div class="store-sub">${appTitle.isNotEmpty ? appTitle : "Official Retail Point of Sale Store"}</div>
          ${supportPhone.isNotEmpty ? '<div class="store-sub">📞 Contact: ' + supportPhone + '</div>' : ''}
        </td>
        <td style="vertical-align: top; text-align: right;">
          <div class="invoice-badge">TAX INVOICE</div>
          <div class="invoice-meta-text"><b>Invoice Ref:</b> <span style="font-family: monospace; font-size: 14px; font-weight: bold;">$invoiceNo</span></div>
          <div class="invoice-meta-text"><b>Date & Time:</b> $createdAt</div>
          <div class="invoice-meta-text"><b>Payment Mode:</b> <span style="color: ${isUdhaar ? '#DC2626' : '#16A34A'}; font-weight: bold;">${paymentMode.toUpperCase()}</span></div>
        </td>
      </tr>
    </table>

    <div class="customer-box">
      <table style="width: 100%;">
        <tr>
          <td>
            <div style="font-size: 10px; color: #64748B; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px;">BILL TO (CUSTOMER):</div>
            <div style="font-size: 16px; font-weight: 800; color: #0F172A; margin-top: 2px;">$customerName</div>
            ${customerPhone.isNotEmpty ? '<div style="font-size: 13px; color: #475569; margin-top: 2px;">📱 Phone: ' + customerPhone + '</div>' : ''}
          </td>
          <td style="text-align: right; vertical-align: top;">
            <div style="font-size: 10px; color: #64748B; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px;">BILLING STATUS:</div>
            <div style="display: inline-block; padding: 4px 12px; margin-top: 4px; border-radius: 20px; font-size: 11px; font-weight: 800; background: ${isUdhaar ? '#FEE2E2' : '#DCFCE7'}; color: ${isUdhaar ? '#991B1B' : '#166534'};">
              ${isUdhaar ? 'CREDIT / UNPAID' : 'PAID IN FULL'}
            </div>
          </td>
        </tr>
      </table>
    </div>

    <table class="items-table">
      <thead>
        <tr>
          <th style="width: 40px; text-align: center;">#</th>
          <th style="text-align: left;">Product Description</th>
          <th style="width: 60px; text-align: center;">Qty</th>
          <th style="width: 110px; text-align: right;">Rate</th>
          <th style="width: 120px; text-align: right;">Amount</th>
        </tr>
      </thead>
      <tbody>
        $itemsRows
      </tbody>
    </table>

    <div class="summary-grid">
      <div class="upi-qr-box">
        ${qrUpiUrl.isNotEmpty ? '''
          <div style="font-size: 10px; font-weight: 800; color: #334155; text-transform: uppercase; margin-bottom: 4px;">SCAN & PAY VIA UPI</div>
          <img src="$qrUpiUrl" style="width: 90px; height: 90px; border-radius: 4px; border: 1px solid #E2E8F0;"><br>
          <div style="font-size: 10px; color: #64748B; margin-top: 4px;">PhonePe • GPay • Paytm</div>
        ''' : '''
          <div style="font-size: 11px; color: #64748B; font-weight: 600; padding: 12px 0;">Official Retail Invoice<br><b>$storeTitle</b></div>
        '''}
      </div>

      <div class="summary-box">
        <table class="summary-table">
          <tr>
            <td style="color: #475569;">Subtotal:</td>
            <td style="text-align: right; font-weight: 700;">₹ ${effectiveSubtotal.toStringAsFixed(2)}</td>
          </tr>
          ${effectiveDiscount > 0 ? '<tr><td style="color: #16A34A; font-weight: 600;">Discount / Off:</td><td style="text-align: right; font-weight: 800; color: #16A34A;">- ₹ ' + effectiveDiscount.toStringAsFixed(2) + '</td></tr>' : ''}
          ${taxAmount > 0 ? '<tr><td style="color: #475569;">GST Tax:</td><td style="text-align: right; font-weight: 700;">₹ ' + taxAmount.toStringAsFixed(2) + '</td></tr>' : ''}
          <tr class="total-row">
            <td style="color: #FFFFFF;">NET GRAND TOTAL:</td>
            <td style="text-align: right; color: #4ADE80 !important; font-weight: 900;">₹ ${grandTotal.toStringAsFixed(2)}</td>
          </tr>
        </table>
      </div>
    </div>

    <div style="display: flex; justify-content: space-between; align-items: flex-end; margin-top: 16px; padding-top: 12px; border-top: 1px solid #E2E8F0;">
      <div style="font-size: 10px; color: #64748B; max-width: 450px;">
        <b>Terms & Conditions:</b><br>
        1. Goods once sold are subject to store policy.<br>
        2. Computer generated GST invoice. E.&O.E.
      </div>
      <div style="text-align: center; width: 160px;">
        <div style="border-bottom: 1px solid #0F172A; height: 30px; margin-bottom: 4px;"></div>
        <div style="font-size: 10px; font-weight: 800; color: #0F172A; text-transform: uppercase;">Authorised Signatory</div>
      </div>
    </div>

    <div class="footer-note">
      <b>Thank you for shopping with us! 🙏</b><br>
      Issued by <b>$storeTitle</b> • Powered by Ekargar POS
    </div>
  </div>
</body>
</html>
    ''';
  }

  /// Generates 80mm POS Thermal Receipt HTML
  static String generateThermalReceiptHtml({
    required String tenantName,
    required String appTitle,
    required String supportPhone,
    required String invoiceNo,
    required String customerName,
    required String customerPhone,
    required String paymentMode,
    required String createdAt,
    required double subtotal,
    required double taxAmount,
    double discountAmount = 0.0,
    required double grandTotal,
    required List<dynamic> items,
  }) {
    final StringBuffer itemsList = StringBuffer();
    for (var it in items) {
      final name = (it['productName'] ?? it['name'] ?? 'Item').toString();
      final qty = (it['quantity'] ?? it['qty'] ?? 1);
      final price = ((it['unitPrice'] ?? it['price'] ?? 0.0) as num).toDouble();
      final tot = ((it['totalPrice'] ?? (qty * price)) as num).toDouble();

      itemsList.write('''
        <div style="margin-bottom: 4px;">
          <div style="font-weight: bold; font-size: 12px;">$name</div>
          <div style="display: flex; justify-content: space-between; font-size: 11px;">
            <span>$qty x ₹${price.toStringAsFixed(2)}</span>
            <span style="font-weight: bold;">₹${tot.toStringAsFixed(2)}</span>
          </div>
        </div>
      ''');
    }

    final double effectiveSubtotal = _calculateBaseSubtotal(
      subtotal: subtotal,
      grandTotal: grandTotal,
      items: items,
    );

    final double effectiveDiscount = _calculateEffectiveDiscount(
      subtotal: subtotal,
      taxAmount: taxAmount,
      discountAmount: discountAmount,
      grandTotal: grandTotal,
      items: items,
    );

    final isUdhaar = paymentMode.toLowerCase() == 'udhaar';
    final storeTitle = tenantName.isNotEmpty ? tenantName : "VILLAGE POS STORE";

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Receipt - $invoiceNo</title>
  <style>
    @page {
      size: 80mm auto;
      margin: 2mm;
    }
    * {
      box-sizing: border-box;
      -webkit-print-color-adjust: exact !important;
      print-color-adjust: exact !important;
    }
    body {
      font-family: 'Courier New', Courier, monospace;
      width: 74mm;
      margin: 0 auto;
      padding: 4mm 2mm;
      color: #000000;
      background: #FFFFFF;
      font-size: 12px;
      line-height: 1.3;
    }
    .text-center { text-align: center; }
    .bold { font-weight: bold; }
    .divider { border-top: 1px dashed #000; margin: 6px 0; }
    .double-divider { border-top: 2px solid #000; margin: 6px 0; }
  </style>
</head>
<body>
  <div class="text-center">
    <div style="font-size: 16px; font-weight: 900; text-transform: uppercase;">$storeTitle</div>
    <div style="font-size: 11px;">${appTitle.isNotEmpty ? appTitle : "Retail Shop Store"}</div>
    ${supportPhone.isNotEmpty ? '<div style="font-size: 11px;">Tel: ' + supportPhone + '</div>' : ''}
  </div>

  <div class="double-divider"></div>

  <div style="font-size: 11px;">
    <div><b>Invoice:</b> $invoiceNo</div>
    <div><b>Date:</b> $createdAt</div>
    <div><b>Customer:</b> $customerName</div>
    <div><b>Payment:</b> <span style="font-weight: bold;">${paymentMode.toUpperCase()} (${isUdhaar ? 'DUE' : 'PAID'})</span></div>
  </div>

  <div class="divider"></div>

  <div style="font-weight: bold; font-size: 11px; display: flex; justify-content: space-between; margin-bottom: 4px;">
    <span>ITEM</span>
    <span>QTY x RATE / AMT</span>
  </div>

  <div class="divider"></div>

  $itemsList

  <div class="divider"></div>

  <div style="font-size: 11px;">
    <div style="display: flex; justify-content: space-between;">
      <span>Subtotal:</span>
      <span>₹${effectiveSubtotal.toStringAsFixed(2)}</span>
    </div>
    ${effectiveDiscount > 0 ? '<div style="display: flex; justify-content: space-between;"><span>Discount:</span><span style="font-weight: bold;">- ₹' + effectiveDiscount.toStringAsFixed(2) + '</span></div>' : ''}
    ${taxAmount > 0 ? '<div style="display: flex; justify-content: space-between;"><span>GST Tax:</span><span>₹' + taxAmount.toStringAsFixed(2) + '</span></div>' : ''}
  </div>

  <div class="double-divider"></div>

  <div style="font-size: 15px; font-weight: 900; display: flex; justify-content: space-between;">
    <span>GRAND TOTAL:</span>
    <span>₹${grandTotal.toStringAsFixed(2)}</span>
  </div>

  <div class="double-divider"></div>

  <div class="text-center" style="font-size: 11px; margin-top: 8px;">
    <b>Thank You! Visit Again 🙏</b><br>
    Powered by Ekargar POS
  </div>
</body>
</html>
    ''';
  }
}

class _InvoicePreviewSheet extends StatefulWidget {
  final String tenantName;
  final String appTitle;
  final String logoUrl;
  final String supportPhone;
  final String invoiceNo;
  final String customerName;
  final String customerPhone;
  final String paymentMode;
  final String createdAt;
  final double subtotal;
  final double taxAmount;
  final double discountAmount;
  final double grandTotal;
  final List<dynamic> items;
  final Color primaryColor;

  const _InvoicePreviewSheet({
    required this.tenantName,
    required this.appTitle,
    required this.logoUrl,
    required this.supportPhone,
    required this.invoiceNo,
    required this.customerName,
    required this.customerPhone,
    required this.paymentMode,
    required this.createdAt,
    required this.subtotal,
    required this.taxAmount,
    required this.discountAmount,
    required this.grandTotal,
    required this.items,
    required this.primaryColor,
  });

  @override
  State<_InvoicePreviewSheet> createState() => _InvoicePreviewSheetState();
}

class _InvoicePreviewSheetState extends State<_InvoicePreviewSheet> {
  PrintFormat _selectedFormat = PrintFormat.a4;

  @override
  Widget build(BuildContext context) {
    final isUdhaar = widget.paymentMode.toLowerCase() == 'udhaar';
    final storeTitle = widget.tenantName.isNotEmpty ? widget.tenantName : "VILLAGE POS STORE";
    final themeColor = widget.primaryColor;

    final double effectiveSubtotal = InvoicePrinter._calculateBaseSubtotal(
      subtotal: widget.subtotal,
      grandTotal: widget.grandTotal,
      items: widget.items,
    );

    final double effectiveDiscount = InvoicePrinter._calculateEffectiveDiscount(
      subtotal: widget.subtotal,
      taxAmount: widget.taxAmount,
      discountAmount: widget.discountAmount,
      grandTotal: widget.grandTotal,
      items: widget.items,
    );

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 4),

          // Header Title Bar with Theme Primary Color Accent
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: themeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.print_rounded, color: themeColor, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Print & Receipt Preview',
                        style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Official POS Invoice & Receipt',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Format Selection Toggle Segment (Clean, Professional Theme Color Tabs)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedFormat = PrintFormat.a4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedFormat == PrintFormat.a4 ? themeColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _selectedFormat == PrintFormat.a4
                              ? [BoxShadow(color: themeColor.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))]
                              : [],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.description_rounded, size: 16, color: _selectedFormat == PrintFormat.a4 ? Colors.white : const Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Text(
                              'A4 Tax Invoice',
                              style: TextStyle(
                                color: _selectedFormat == PrintFormat.a4 ? Colors.white : const Color(0xFF334155),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedFormat = PrintFormat.thermal),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedFormat == PrintFormat.thermal ? themeColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _selectedFormat == PrintFormat.thermal
                              ? [BoxShadow(color: themeColor.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))]
                              : [],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_rounded, size: 16, color: _selectedFormat == PrintFormat.thermal ? Colors.white : const Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Text(
                              'Thermal Slip (80mm)',
                              style: TextStyle(
                                color: _selectedFormat == PrintFormat.thermal ? Colors.white : const Color(0xFF334155),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Live Interactive Receipt Preview Canvas
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Container(
                  width: _selectedFormat == PrintFormat.a4 ? 500 : 340,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 18, offset: const Offset(0, 6)),
                    ],
                  ),
                  padding: EdgeInsets.all(_selectedFormat == PrintFormat.a4 ? 20 : 14),
                  child: _selectedFormat == PrintFormat.a4
                      ? _buildA4FlutterPreview(storeTitle, isUdhaar, effectiveSubtotal, effectiveDiscount, themeColor)
                      : _buildThermalFlutterPreview(storeTitle, isUdhaar, effectiveSubtotal, effectiveDiscount),
                ),
              ),
            ),
          ),

          // Bottom Action Bar: Print & Close
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.print_rounded, size: 20),
                    label: Text(
                      _selectedFormat == PrintFormat.a4 ? 'PRINT A4 INVOICE' : 'PRINT THERMAL RECEIPT',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                    ),
                    onPressed: () {
                      InvoicePrinter.printInvoice(
                        format: _selectedFormat,
                        tenantName: widget.tenantName,
                        appTitle: widget.appTitle,
                        logoUrl: widget.logoUrl,
                        supportPhone: widget.supportPhone,
                        invoiceNo: widget.invoiceNo,
                        customerName: widget.customerName,
                        customerPhone: widget.customerPhone,
                        paymentMode: widget.paymentMode,
                        createdAt: widget.createdAt,
                        subtotal: effectiveSubtotal,
                        taxAmount: widget.taxAmount,
                        discountAmount: effectiveDiscount,
                        grandTotal: widget.grandTotal,
                        items: widget.items,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildA4FlutterPreview(String storeTitle, bool isUdhaar, double effectiveSubtotal, double effectiveDiscount, Color themeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Accent Bar
        Container(
          height: 4,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: themeColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(storeTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                Text(widget.appTitle.isNotEmpty ? widget.appTitle : "Retail POS Store", style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(4)),
              child: const Text('TAX INVOICE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ],
        ),
        const Divider(height: 20, thickness: 1),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Ref: ${widget.invoiceNo}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            Text('Date: ${widget.createdAt.split('T')[0].split(' ')[0]}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('BILL TO:', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  Text(widget.customerName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isUdhaar ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isUdhaar ? 'CREDIT' : 'PAID',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isUdhaar ? Colors.red.shade900 : Colors.green.shade900),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          color: const Color(0xFF0F172A),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: const Row(
            children: [
              Expanded(flex: 3, child: Text('ITEM', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
              Expanded(child: Text('QTY', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text('TOTAL', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        ...widget.items.map((it) {
          final name = (it['productName'] ?? it['name'] ?? 'Item').toString();
          final qty = (it['quantity'] ?? it['qty'] ?? 1);
          final price = ((it['unitPrice'] ?? it['price'] ?? 0.0) as num).toDouble();
          final tot = ((it['totalPrice'] ?? (qty * price)) as num).toDouble();
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                Expanded(child: Text('$qty', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11))),
                Expanded(flex: 2, child: Text('₹${tot.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),

        // Financial Breakdown Table
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subtotal:', style: TextStyle(fontSize: 11, color: Color(0xFF475569))),
                  Text('₹${effectiveSubtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
              if (effectiveDiscount > 0) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Discount / Off:', style: TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                    Text('- ₹${effectiveDiscount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                  ],
                ),
              ],
              if (widget.taxAmount > 0) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('GST Tax:', style: TextStyle(fontSize: 11, color: Color(0xFF475569))),
                    Text('₹${widget.taxAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),

        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(6)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('GRAND TOTAL:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              Text('₹${widget.grandTotal.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF4ADE80), fontWeight: FontWeight.w900, fontSize: 15)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Center(child: Text('Thank you for your business! 🙏', style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontStyle: FontStyle.italic))),
      ],
    );
  }

  Widget _buildThermalFlutterPreview(String storeTitle, bool isUdhaar, double effectiveSubtotal, double effectiveDiscount) {
    return Column(
      children: [
        Text(storeTitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
        Text('Invoice: ${widget.invoiceNo}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
        const Text('--------------------------------', style: TextStyle(fontFamily: 'monospace')),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Cust: ${widget.customerName}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
            Text(isUdhaar ? 'DUE' : 'PAID', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
          ],
        ),
        const Text('--------------------------------', style: TextStyle(fontFamily: 'monospace')),
        ...widget.items.map((it) {
          final name = (it['productName'] ?? it['name'] ?? 'Item').toString();
          final qty = (it['quantity'] ?? it['qty'] ?? 1);
          final price = ((it['unitPrice'] ?? it['price'] ?? 0.0) as num).toDouble();
          final tot = ((it['totalPrice'] ?? (qty * price)) as num).toDouble();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(name, style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
                Text('$qty x ₹$price = ₹$tot', style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }),
        const Text('--------------------------------', style: TextStyle(fontFamily: 'monospace')),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Subtotal:', style: TextStyle(fontSize: 10, fontFamily: 'monospace')),
            Text('₹${effectiveSubtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
          ],
        ),
        if (effectiveDiscount > 0)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Discount:', style: TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
              Text('- ₹${effectiveDiscount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
            ],
          ),
        const Text('================================', style: TextStyle(fontFamily: 'monospace')),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('TOTAL:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            Text('₹${widget.grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
          ],
        ),
        const Text('================================', style: TextStyle(fontFamily: 'monospace')),
        const Text('Thank You! Visit Again 🙏', style: TextStyle(fontSize: 10, fontFamily: 'monospace')),
      ],
    );
  }
}
