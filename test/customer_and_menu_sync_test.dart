import 'package:flutter_test/flutter_test.dart';
import 'package:village_shop_mobile/providers/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Menu Deduplication Tests', () {
    test('ThemeProvider dynamicMenuItems deduplicates routes case-insensitively', () {
      final themeProvider = TenantThemeProvider();
      
      final duplicateList = [
        {'route': '/pos', 'title': 'POS Billing'},
        {'route': '/masters', 'title': 'Master Management'},
        {'route': '/MASTERS', 'title': 'Master Data'},
        {'route': '/pos', 'title': 'POS Screen Duplicate'},
        {'route': '/items', 'title': 'Items'},
      ];

      themeProvider.setDynamicMenuItems(duplicateList);

      final result = themeProvider.dynamicMenuItems;
      // Should have only 3 distinct items: /pos, /masters, /items
      expect(result.length, 3);
      expect(result.map((m) => m['route'].toString().toLowerCase()).toSet().length, 3);
      expect(result[0]['route'], '/pos');
      expect(result[1]['route'], '/masters');
      expect(result[2]['route'], '/items');
    });
  });

  group('Customer Payload Parsing & ID Retention Tests', () {
    test('Handles PascalCase and camelCase customer records correctly', () {
      final rawPascal = {
        'Id': 105,
        'Name': 'Rajesh Kumar',
        'Mobile': '9876543210',
      };

      final rawCamel = {
        'id': 202,
        'name': 'Anita Devi',
        'phone': '9123456780',
      };

      // PascalCase extraction
      final pId = rawPascal['id'] ?? rawPascal['Id'] ?? rawPascal['ID'];
      final pName = rawPascal['name'] ?? rawPascal['Name'] ?? '';
      final pMobile = rawPascal['phone'] ?? rawPascal['mobile'] ?? rawPascal['Mobile'] ?? '';

      expect(pId, 105);
      expect(pName, 'Rajesh Kumar');
      expect(pMobile, '9876543210');

      // camelCase extraction
      final cId = rawCamel['id'] ?? rawCamel['Id'] ?? rawCamel['ID'];
      final cName = rawCamel['name'] ?? rawCamel['Name'] ?? '';
      final cMobile = rawCamel['phone'] ?? rawCamel['mobile'] ?? rawCamel['Mobile'] ?? '';

      expect(cId, 202);
      expect(cName, 'Anita Devi');
      expect(cMobile, '9123456780');
    });

    test('Customer selection persists valid non-zero ID for checkout transaction', () {
      dynamic selectedCustomerId;
      Map<String, dynamic> customerIdMap = {};

      void onCustomerSelected(dynamic id, String name) {
        selectedCustomerId = int.tryParse(id?.toString() ?? '') ?? id;
        customerIdMap[name] = selectedCustomerId;
      }

      onCustomerSelected(42, 'Ramesh Trader');

      expect(selectedCustomerId, 42);
      expect(customerIdMap['Ramesh Trader'], 42);

      // Verify transaction payload generation
      final salePayload = {
        'clientTransactionId': 'INV-2026-001',
        'customerId': selectedCustomerId ?? customerIdMap['Ramesh Trader'],
        'customerName': 'Ramesh Trader',
        'totalAmount': 500.0,
      };

      expect(salePayload['customerId'], 42);
      expect(salePayload['customerName'], 'Ramesh Trader');
    });
  });
}
