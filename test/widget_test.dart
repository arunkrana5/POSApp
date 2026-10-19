import 'package:flutter_test/flutter_test.dart';
import 'package:village_shop_mobile/utils/whatsapp_helper.dart';

void main() {
  group('Invoice & Customer Phone Tests', () {
    test('WhatsApp message format includes items, rates, taxes, and totals', () {
      final message = WhatsAppHelper.formatInvoiceMessage(
        tenantName: 'Village Supermart',
        invoiceNo: 'INV-2026-0001',
        customerName: 'Ramesh Kumar',
        paymentMode: 'Cash',
        createdAt: '2026-10-19 10:00:00',
        subtotal: 500.0,
        discountAmount: 50.0,
        taxAmount: 22.5,
        grandTotal: 472.5,
        items: [
          {
            'productName': 'Basmati Rice',
            'qty': 2,
            'unit': 'kg',
            'price': 100.0,
            'stockRate': 120.0,
            'total': 200.0,
          },
          {
            'productName': 'Mustard Oil',
            'qty': 1,
            'unit': 'ltr',
            'price': 300.0,
            'stockRate': 300.0,
            'total': 300.0,
          },
        ],
      );

      expect(message, contains('VILLAGE SUPERMART'));
      expect(message, contains('INV-2026-0001'));
      expect(message, contains('Ramesh Kumar'));
      expect(message, contains('Basmati Rice'));
      expect(message, contains('Mustard Oil'));
      expect(message, contains('472.50'));
    });

    test('Customer phone extraction handles multiple candidate keys gracefully', () {
      String extractPhone(Map<String, dynamic> sale) {
        return (sale['customerPhone'] ??
                sale['customerMobile'] ??
                sale['phone'] ??
                sale['mobile'] ??
                '')
            .toString()
            .trim();
      }

      final saleWithCustomerPhone = {'customerPhone': '9876543210'};
      final saleWithCustomerMobile = {'customerMobile': '9123456780'};
      final saleWithPhone = {'phone': '9988776655'};
      final saleWithMobile = {'mobile': '9811223344'};
      final walkInSale = {'customerName': 'Walk-in Customer'};

      expect(extractPhone(saleWithCustomerPhone), '9876543210');
      expect(extractPhone(saleWithCustomerMobile), '9123456780');
      expect(extractPhone(saleWithPhone), '9988776655');
      expect(extractPhone(saleWithMobile), '9811223344');
      expect(extractPhone(walkInSale), '');
    });
  });
}
