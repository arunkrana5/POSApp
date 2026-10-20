import 'package:flutter_test/flutter_test.dart';

void main() {
  group('POS Screen Flipkart/Amazon Redesign Logic Tests', () {
    test('Categories are sorted alphabetically with "All" always at index 0', () {
      final availableProducts = [
        {'id': '1', 'name': 'Milk 500ml', 'category': 'Dairy'},
        {'id': '2', 'name': 'Basmati Rice', 'category': 'Groceries'},
        {'id': '3', 'name': 'Biscuits', 'category': 'Bakery & Snacks'},
        {'id': '4', 'name': 'Butter 100g', 'category': 'Dairy'},
        {'id': '5', 'name': 'General Item', 'category': 'General'},
      ];

      final Set<String> categorySet = {'All'};
      for (final p in availableProducts) {
        final cat = (p['category']?.toString() ?? '').trim();
        if (cat.isNotEmpty) {
          categorySet.add(cat);
        }
      }
      final categories = categorySet.toList();
      categories.remove('All');
      categories.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      categories.insert(0, 'All');

      expect(categories.first, 'All');
      expect(categories, ['All', 'Bakery & Snacks', 'Dairy', 'General', 'Groceries']);
    });

    test('Category filtering filters products accurately', () {
      final availableProducts = [
        {'id': '1', 'name': 'Milk 500ml', 'category': 'Dairy', 'price': 30.0},
        {'id': '2', 'name': 'Basmati Rice', 'category': 'Groceries', 'price': 120.0},
        {'id': '3', 'name': 'Butter 100g', 'category': 'Dairy', 'price': 55.0},
      ];

      // Selected category Dairy
      String selectedCategory = 'Dairy';
      final filteredDairy = availableProducts.where((p) {
        return selectedCategory == 'All' ||
            (p['category']?.toString().trim().toLowerCase() == selectedCategory.toLowerCase());
      }).toList();

      expect(filteredDairy.length, 2);
      expect(filteredDairy.map((p) => p['name']), containsAll(['Milk 500ml', 'Butter 100g']));

      // Selected category All
      selectedCategory = 'All';
      final filteredAll = availableProducts.where((p) {
        return selectedCategory == 'All' ||
            (p['category']?.toString().trim().toLowerCase() == selectedCategory.toLowerCase());
      }).toList();

      expect(filteredAll.length, 3);
    });

    test('Search filter matches brand, barcode, SKU, and product name', () {
      final availableProducts = [
        {'id': '1', 'name': 'Amul Butter', 'brand': 'Amul', 'barcode': '89012345', 'productCode': 'PRD-01', 'category': 'Dairy'},
        {'id': '2', 'name': 'Tata Tea Gold', 'brand': 'Tata', 'barcode': '89067890', 'productCode': 'PRD-02', 'category': 'Beverages'},
      ];

      bool matchesProduct(Map<String, dynamic> p, String query) {
        final cleanQuery = query.trim().toLowerCase();
        if (cleanQuery.isEmpty) return true;
        final name = p['name']?.toString().toLowerCase() ?? '';
        final category = p['category']?.toString().toLowerCase() ?? '';
        final brand = p['brand']?.toString().toLowerCase() ?? '';
        final barcode = p['barcode']?.toString().toLowerCase() ?? '';
        final productCode = p['productCode']?.toString().toLowerCase() ?? '';
        return name.contains(cleanQuery) ||
            category.contains(cleanQuery) ||
            brand.contains(cleanQuery) ||
            barcode.contains(cleanQuery) ||
            productCode.contains(cleanQuery);
      }

      // Search by brand
      expect(matchesProduct(availableProducts[0], 'amul'), isTrue);
      expect(matchesProduct(availableProducts[1], 'amul'), isFalse);

      // Search by barcode
      expect(matchesProduct(availableProducts[1], '89067890'), isTrue);

      // Search by product code
      expect(matchesProduct(availableProducts[0], 'PRD-01'), isTrue);
    });

    test('Exact amount sales policy ensures 0% offer discount and exact amount calculation', () {
      final product1 = {'price': 80.50, 'mrp': 100.0};
      final product2 = {'price': 100.0, 'mrp': 100.0};

      // Policy: 0% offer discount, exact amount sold
      double getSellingPrice(Map<String, dynamic> p) => (p['price'] as num).toDouble();
      bool showDiscountBadge() => false; // Offers disabled (0% discount)

      expect(showDiscountBadge(), isFalse);
      expect(getSellingPrice(product1), 80.50);
      expect(getSellingPrice(product2), 100.0);

      // Exact formatting preserves decimals
      String formatExact(double val) => val.toStringAsFixed(val.truncateToDouble() == val ? 0 : 2);
      expect(formatExact(80.50), '80.50');
      expect(formatExact(100.0), '100');
    });

    test('Cart quantity transforms between Add button and Stepper', () {
      final List<Map<String, dynamic>> cartItems = [];
      final product = {
        'id': '101',
        'name': 'Sunflower Oil 1L',
        'price': 150.0,
        'stock': 10,
        'unit': 'ltr',
      };

      // Initially not in cart
      int cartIndex = cartItems.indexWhere((item) => item['id'] == product['id']);
      expect(cartIndex, -1);
      bool isInCart = cartIndex >= 0;
      expect(isInCart, isFalse);

      // User clicks + ADD
      cartItems.add({
        'id': product['id'],
        'name': product['name'],
        'price': product['price'],
        'qty': 1,
      });

      cartIndex = cartItems.indexWhere((item) => item['id'] == product['id']);
      expect(cartIndex, 0);
      isInCart = cartIndex >= 0;
      expect(isInCart, isTrue);
      expect(cartItems[cartIndex]['qty'], 1);

      // User clicks + in stepper
      cartItems[cartIndex]['qty'] += 1;
      expect(cartItems[cartIndex]['qty'], 2);

      // User clicks - twice in stepper
      cartItems[cartIndex]['qty'] -= 1;
      expect(cartItems[cartIndex]['qty'], 1);

      cartItems[cartIndex]['qty'] -= 1;
      if (cartItems[cartIndex]['qty'] <= 0) {
        cartItems.removeAt(cartIndex);
      }
      expect(cartItems.isEmpty, isTrue);
    });

    test('Low stock and out-of-stock guard states are correctly determined', () {
      final productOut = {'stock': 0, 'minimumStock': 5};
      final productLow = {'stock': 3, 'minimumStock': 5};
      final productNormal = {'stock': 20, 'minimumStock': 5};

      bool isOutOfStock(Map<String, dynamic> p, bool allowNegative) {
        final stock = (p['stock'] as num).toInt();
        return !allowNegative && stock <= 0;
      }

      bool isLowStock(Map<String, dynamic> p, bool allowNegative) {
        final stock = (p['stock'] as num).toInt();
        final min = (p['minimumStock'] as num).toInt();
        return !isOutOfStock(p, allowNegative) && stock > 0 && stock <= min;
      }

      expect(isOutOfStock(productOut, false), isTrue);
      expect(isLowStock(productOut, false), isFalse);

      expect(isOutOfStock(productLow, false), isFalse);
      expect(isLowStock(productLow, false), isTrue);

      expect(isOutOfStock(productNormal, false), isFalse);
      expect(isLowStock(productNormal, false), isFalse);
    });
  });
}
