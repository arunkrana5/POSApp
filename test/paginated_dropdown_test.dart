import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_shop_mobile/widgets/paginated_server_dropdown.dart';

void main() {
  group('CommonPaginatedDropdown Unit & Widget Tests', () {
    testWidgets('Initial open loads exactly 5 items and displays Show More button', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      int requestedPage = 0;
      int requestedPageSize = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommonPaginatedDropdown<Map<String, dynamic>>(
              label: 'Test Item',
              itemTitle: (i) => i['name'].toString(),
              itemId: (i) => i['id'],
              fetchPage: ({required int page, required int pageSize, required String search, dynamic parentFilter}) async {
                requestedPage = page;
                requestedPageSize = pageSize;
                return PaginatedDropdownResult<Map<String, dynamic>>(
                  items: List.generate(5, (index) => {'id': index + 1, 'name': 'Item #${index + 1}'}),
                  hasMore: true,
                  totalCount: 12,
                );
              },
            ),
          ),
        ),
      );

      // Open popup
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Verify page 1 and pageSize 5 were requested
      expect(requestedPage, 1);
      expect(requestedPageSize, 5);

      // Verify 5 items are displayed
      expect(find.text('Item #1'), findsOneWidget);
      expect(find.text('Item #5'), findsOneWidget);

      // Verify 'Show More (+5 options)' button is visible
      expect(find.text('Show More (+5 options)'), findsOneWidget);
    });

    testWidgets('Tapping Show More loads page 2 and appends next 5 items without duplicates', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      int lastRequestedPage = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommonPaginatedDropdown<Map<String, dynamic>>(
              label: 'Test Item',
              itemTitle: (i) => i['name'].toString(),
              itemId: (i) => i['id'],
              fetchPage: ({required int page, required int pageSize, required String search, dynamic parentFilter}) async {
                lastRequestedPage = page;
                if (page == 1) {
                  return PaginatedDropdownResult<Map<String, dynamic>>(
                    items: List.generate(5, (i) => {'id': i + 1, 'name': 'Item #${i + 1}'}),
                    hasMore: true,
                    totalCount: 7,
                  );
                } else {
                  // Page 2: returns 2 items and hasMore = false
                  return PaginatedDropdownResult<Map<String, dynamic>>(
                    items: [
                      {'id': 6, 'name': 'Item #6'},
                      {'id': 7, 'name': 'Item #7'},
                    ],
                    hasMore: false,
                    totalCount: 7,
                  );
                }
              },
            ),
          ),
        ),
      );

      // Open popup
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      expect(find.text('Item #1'), findsOneWidget);
      expect(find.text('Item #5'), findsOneWidget);

      // Click Show More
      final showMoreButton = find.text('Show More (+5 options)');
      expect(showMoreButton, findsOneWidget);
      await tester.tap(showMoreButton);
      await tester.pumpAndSettle();

      // Page 2 was requested
      expect(lastRequestedPage, 2);

      // Items 1 through 7 should now exist
      expect(find.text('Item #6'), findsOneWidget);
      expect(find.text('Item #7'), findsOneWidget);

      // Show More button should now be hidden since hasMore is false
      expect(find.text('Show More (+5 options)'), findsNothing);
    });

    testWidgets('Search input resets to page 1 with search filter and cancels stale queries', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      String lastSearch = '';
      int lastPage = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommonPaginatedDropdown<Map<String, dynamic>>(
              label: 'Search Item',
              itemTitle: (i) => i['name'].toString(),
              itemId: (i) => i['id'],
              fetchPage: ({required int page, required int pageSize, required String search, dynamic parentFilter}) async {
                lastSearch = search;
                lastPage = page;
                if (search.isEmpty) {
                  return PaginatedDropdownResult<Map<String, dynamic>>(
                    items: List.generate(5, (i) => {'id': i + 1, 'name': 'Item #${i + 1}'}),
                    hasMore: true,
                    totalCount: 10,
                  );
                } else {
                  return PaginatedDropdownResult<Map<String, dynamic>>(
                    items: [
                      {'id': 99, 'name': 'Search Result for $search'},
                    ],
                    hasMore: false,
                    totalCount: 1,
                  );
                }
              },
            ),
          ),
        ),
      );

      // Open popup
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      expect(lastPage, 1);
      expect(lastSearch, '');
      expect(find.text('Item #1'), findsOneWidget);

      // Enter search query
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'Sugar');

      // Wait for debounce timer (300ms)
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(lastSearch, 'Sugar');
      expect(lastPage, 1);
      expect(find.text('Search Result for Sugar'), findsOneWidget);
      expect(find.text('Item #1'), findsNothing);
    });

    testWidgets('Dependent dropdown resets child selection when parentFilter changes', (WidgetTester tester) async {
      int? selectedParentId = 10;
      Map<String, dynamic>? childSelected;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          selectedParentId = 20; // Change parent
                        });
                      },
                      child: const Text('Change Parent'),
                    ),
                    CommonPaginatedDropdown<Map<String, dynamic>>(
                      label: 'Sub Item',
                      selectedId: 101,
                      selectedTitle: 'Initial Child Item',
                      parentFilter: selectedParentId,
                      itemTitle: (i) => i['name'].toString(),
                      itemId: (i) => i['id'],
                      onChanged: (item, id, title) {
                        childSelected = item;
                      },
                      fetchPage: ({required int page, required int pageSize, required String search, dynamic parentFilter}) async {
                        return PaginatedDropdownResult<Map<String, dynamic>>(
                          items: [
                            {'id': 101, 'name': 'Child of $parentFilter'},
                          ],
                          hasMore: false,
                          totalCount: 1,
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      expect(find.text('Initial Child Item'), findsOneWidget);

      // Click Change Parent button
      await tester.tap(find.text('Change Parent'));
      await tester.pumpAndSettle();

      // Child selection should be cleared
      expect(childSelected, isNull);
      expect(find.text('Initial Child Item'), findsNothing);
    });

    testWidgets('Error during fetch displays error message and Retry button', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool shouldFail = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommonPaginatedDropdown<Map<String, dynamic>>(
              label: 'Faulty Dropdown',
              itemTitle: (i) => i['name'].toString(),
              itemId: (i) => i['id'],
              fetchPage: ({required int page, required int pageSize, required String search, dynamic parentFilter}) async {
                if (shouldFail) {
                  throw Exception('Network connection timed out');
                }
                return PaginatedDropdownResult<Map<String, dynamic>>(
                  items: [{'id': 1, 'name': 'Recovered Item'}],
                  hasMore: false,
                  totalCount: 1,
                );
              },
            ),
          ),
        ),
      );

      // Open popup
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Error and Retry visible
      expect(find.text('Failed to load options. Please retry.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Fix failure and tap Retry
      shouldFail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      // Recovered successfully
      expect(find.text('Recovered Item'), findsOneWidget);
      expect(find.text('Failed to load options. Please retry.'), findsNothing);
    });
  });
}
