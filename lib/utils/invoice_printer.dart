import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:html' as html;

class InvoicePrinter {
  static void printA4Invoice({
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
    required double grandTotal,
    required List<dynamic> items,
  }) {
    if (!kIsWeb) return;

    final StringBuffer itemsRows = StringBuffer();
    int srNo = 1;
    for (var it in items) {
      final name = (it['productName'] ?? it['name'] ?? 'Product Item').toString();
      final qty = (it['quantity'] ?? it['qty'] ?? 1);
      final price = ((it['unitPrice'] ?? it['price'] ?? 0.0) as num).toDouble();
      final tot = ((it['totalPrice'] ?? (qty * price)) as num).toDouble();

      itemsRows.write('''
        <tr>
          <td style="text-align: center; font-size: 13px; padding: 10px; border: 1px solid #E2E8F0;">$srNo</td>
          <td style="font-size: 13px; font-weight: 600; padding: 10px; border: 1px solid #E2E8F0;">$name</td>
          <td style="text-align: center; font-size: 13px; padding: 10px; border: 1px solid #E2E8F0;">$qty</td>
          <td style="text-align: right; font-size: 13px; padding: 10px; border: 1px solid #E2E8F0;">₹ ${price.toStringAsFixed(2)}</td>
          <td style="text-align: right; font-size: 13px; font-weight: 700; padding: 10px; border: 1px solid #E2E8F0;">₹ ${tot.toStringAsFixed(2)}</td>
        </tr>
      ''');
      srNo++;
    }

    final isUdhaar = paymentMode.toLowerCase() == 'udhaar';
    final storeTitle = tenantName.isNotEmpty ? tenantName : "VILLAGE POS STORE";

    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Tax Invoice - $invoiceNo</title>
  <style>
    @page {
      size: A4 portrait;
      margin: 12mm;
    }
    body {
      font-family: system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      color: #0F172A;
      margin: 0;
      padding: 24px;
      background: #FFFFFF;
    }
    .invoice-container {
      max-width: 800px;
      margin: 0 auto;
      border: 2px solid #0F172A;
      border-radius: 8px;
      padding: 32px;
      box-sizing: border-box;
    }
    .header-table {
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 24px;
    }
    .store-brand {
      font-size: 24px;
      font-weight: 900;
      color: #0F172A;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .store-sub {
      font-size: 13px;
      color: #475569;
      margin-top: 4px;
    }
    .invoice-badge {
      font-size: 24px;
      font-weight: 900;
      color: #2563EB;
      text-align: right;
      letter-spacing: 1px;
    }
    .invoice-meta-text {
      font-size: 13px;
      color: #334155;
      text-align: right;
      margin-top: 4px;
    }
    .customer-box {
      background: #F8FAFC;
      border: 1px solid #CBD5E1;
      border-radius: 6px;
      padding: 16px;
      margin-bottom: 24px;
    }
    .items-table {
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 24px;
    }
    .items-table th {
      background: #0F172A;
      color: #FFFFFF;
      font-size: 12px;
      font-weight: 700;
      text-transform: uppercase;
      padding: 12px 10px;
      border: 1px solid #0F172A;
      letter-spacing: 0.5px;
    }
    .summary-box {
      width: 320px;
      margin-left: auto;
      margin-bottom: 30px;
    }
    .summary-table {
      width: 100%;
      border-collapse: collapse;
    }
    .summary-table td {
      padding: 8px 12px;
      font-size: 14px;
    }
    .total-row {
      font-size: 18px !important;
      font-weight: 900;
      color: #16A34A;
      background: #F0FDF4;
      border-top: 2px solid #0F172A;
      border-bottom: 2px solid #0F172A;
    }
    .footer-note {
      margin-top: 40px;
      padding-top: 20px;
      border-top: 1px solid #E2E8F0;
      text-align: center;
      font-size: 12px;
      color: #64748B;
    }
  </style>
</head>
<body>
  <div class="invoice-container">
    <table class="header-table">
      <tr>
        <td style="vertical-align: top;">
          ${logoUrl.isNotEmpty ? '<img src="$logoUrl" style="max-height: 55px; margin-bottom: 8px; border-radius: 6px;"><br>' : ''}
          <div class="store-brand">$storeTitle</div>
          <div class="store-sub">${appTitle.isNotEmpty ? appTitle : "Official Retail Point of Sale Store"}</div>
          ${supportPhone.isNotEmpty ? '<div class="store-sub">📞 Contact Support: ' + supportPhone + '</div>' : ''}
        </td>
        <td style="vertical-align: top;">
          <div class="invoice-badge">TAX INVOICE</div>
          <div class="invoice-meta-text"><b>Invoice Ref:</b> <span style="font-family: monospace; font-size: 14px;">$invoiceNo</span></div>
          <div class="invoice-meta-text"><b>Date & Time:</b> $createdAt</div>
          <div class="invoice-meta-text"><b>Payment Mode:</b> <span style="color: ${isUdhaar ? '#DC2626' : '#16A34A'}; font-weight: bold;">${paymentMode.toUpperCase()}</span></div>
        </td>
      </tr>
    </table>

    <div class="customer-box">
      <table style="width: 100%;">
        <tr>
          <td>
            <div style="font-size: 11px; color: #64748B; font-weight: 700; text-transform: uppercase;">BILL TO (CUSTOMER INFORMATION):</div>
            <div style="font-size: 16px; font-weight: 800; color: #0F172A; margin-top: 4px;">$customerName</div>
            ${customerPhone.isNotEmpty ? '<div style="font-size: 13px; color: #475569; margin-top: 2px;">Phone: ' + customerPhone + '</div>' : ''}
          </td>
          <td style="text-align: right; vertical-align: top;">
            <div style="font-size: 11px; color: #64748B; font-weight: 700; text-transform: uppercase;">BILLING STATUS:</div>
            <div style="display: inline-block; padding: 4px 12px; margin-top: 4px; border-radius: 4px; font-size: 12px; font-weight: 800; background: ${isUdhaar ? '#FEE2E2' : '#DCFCE7'}; color: ${isUdhaar ? '#991B1B' : '#166534'};">
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
          <th style="width: 110px; text-align: right;">Unit Price</th>
          <th style="width: 120px; text-align: right;">Line Total</th>
        </tr>
      </thead>
      <tbody>
        $itemsRows
      </tbody>
    </table>

    <div class="summary-box">
      <table class="summary-table">
        <tr>
          <td>Subtotal Amount:</td>
          <td style="text-align: right; font-weight: 600;">₹ ${subtotal.toStringAsFixed(2)}</td>
        </tr>
        ${taxAmount > 0 ? '<tr><td>GST Tax Amount:</td><td style="text-align: right; font-weight: 600;">₹ ' + taxAmount.toStringAsFixed(2) + '</td></tr>' : ''}
        <tr class="total-row">
          <td>NET GRAND TOTAL:</td>
          <td style="text-align: right;">₹ ${grandTotal.toStringAsFixed(2)}</td>
        </tr>
      </table>
    </div>

    <div class="footer-note">
      <b>Thank you for shopping with us! 🙏</b><br>
      This is an official computer-generated Tax Invoice issued by <b>$storeTitle</b>.<br>
      Powered by VillageShop POS System.
    </div>
  </div>

  <script>
    window.onload = function() {
      setTimeout(function() {
        window.print();
      }, 400);
    };
  </script>
</body>
</html>
    ''';

    final dataUrl = Uri.dataFromString(htmlContent, mimeType: 'text/html', encoding: utf8).toString();
    html.window.open(dataUrl, '_blank', 'width=850,height=1000');
  }
}
