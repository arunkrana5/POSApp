import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Items List & Pagination Logic Tests', () {
    test('Optimistic instant item addition inserts at index 0 and updates total count', () {
      final List<Map<String, dynamic>> masterItems = [
        {'id': '101', 'itemCode': 'ITM-01', 'name': 'Existing Item 1'},
        {'id': '102', 'itemCode': 'ITM-02', 'name': 'Existing Item 2'},
      ];
      int totalCount = 2;

      final newItem = {
        'id': '103',
        'itemCode': 'ITM-03',
        'name': 'Brand New Item',
      };

      // Optimistic instant insert
      masterItems.removeWhere((i) => i['id'] == newItem['id'] || i['itemCode'] == newItem['itemCode']);
      masterItems.insert(0, newItem);
      totalCount++;

      expect(masterItems.length, 3);
      expect(masterItems.first['name'], 'Brand New Item');
      expect(masterItems.first['id'], '103');
      expect(totalCount, 3);
    });

    test('In-place instant item update replaces target item without changing order', () {
      final List<Map<String, dynamic>> masterItems = [
        {'id': '101', 'itemCode': 'ITM-01', 'name': 'Original Name'},
        {'id': '102', 'itemCode': 'ITM-02', 'name': 'Item 2'},
      ];

      final updatedItem = {
        'id': '101',
        'itemCode': 'ITM-01',
        'name': 'Updated Name',
      };

      final idx = masterItems.indexWhere((i) => i['id'] == '101');
      expect(idx, 0);
      masterItems[idx] = updatedItem;

      expect(masterItems.length, 2);
      expect(masterItems[0]['name'], 'Updated Name');
    });

    test('Instant item deletion removes item and decrements count', () {
      final List<Map<String, dynamic>> masterItems = [
        {'id': '101', 'itemCode': 'ITM-01', 'name': 'Item 1'},
        {'id': '102', 'itemCode': 'ITM-02', 'name': 'Item 2'},
      ];
      int totalCount = 2;

      masterItems.removeWhere((i) => i['id'] == '101');
      totalCount--;

      expect(masterItems.length, 1);
      expect(masterItems.first['id'], '102');
      expect(totalCount, 1);
    });

    test('Pagination deduplication appends new page items without duplicate IDs', () {
      final List<Map<String, dynamic>> masterItems = [
        {'id': '101', 'name': 'Item 1'},
        {'id': '102', 'name': 'Item 2'},
      ];

      final List<Map<String, dynamic>> page2Items = [
        {'id': '102', 'name': 'Item 2'}, // Duplicate
        {'id': '103', 'name': 'Item 3'},
        {'id': '104', 'name': 'Item 4'},
      ];

      final existingIds = masterItems.map((i) => i['id']).toSet();
      for (var item in page2Items) {
        if (!existingIds.contains(item['id'])) {
          masterItems.add(item);
          existingIds.add(item['id']);
        }
      }

      expect(masterItems.length, 4);
      expect(masterItems.map((i) => i['id']).toList(), ['101', '102', '103', '104']);
    });
  });
}
