import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/app_drawer.dart';
import '../widgets/master_dropdown.dart';
import '../utils/toast_helper.dart';

class ItemsScreen extends StatefulWidget {
  final bool autoOpenAddModal;
  const ItemsScreen({super.key, this.autoOpenAddModal = false});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  final List<Map<String, dynamic>> _masterItems = [];
  final List<String> _dynamicCategories = ['Groceries', 'Edible Oil', 'Detergent', 'Spices', 'Beverages', 'Dairy', 'Grains', 'General'];
  final List<String> _dynamicUoms = ['pkt', 'bottle', 'kg', 'gm', 'ltr', 'pcs', 'box'];
  final List<String> _dynamicItemTypes = ['Packed Goods', 'Loose Goods', 'Service / Custom'];
  final List<String> _dynamicBrands = ['General / Local', 'Amul', 'Tata Consumer', 'Nestle'];

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  int _currentPage = 1;
  final int _pageSize = 25;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  int _totalCount = 0;
  Timer? _debounceTimer;

  String _searchQuery = '';
  bool _isLoading = false;
  bool _hasDropdownsLoaded = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchItems(reset: true);
    if (widget.autoOpenAddModal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final isHindi = Provider.of<LocaleProvider>(context, listen: false).isHindi;
          _showAddMasterItemModal(context, isHindi);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchCtrl.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && !_isLoadingMore && _hasMore) {
        _fetchItems(reset: false);
      }
    }
  }

  Future<void> _fetchItems({bool reset = false}) async {
    if (reset) {
      _currentPage = 1;
      _hasMore = true;
      if (mounted) setState(() => _isLoading = true);
    } else {
      if (!_hasMore || _isLoadingMore) return;
      if (mounted) setState(() => _isLoadingMore = true);
    }

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final token = auth.accessToken ?? '';
      final tenantId = auth.tenantId ?? 0;
      final tenantCode = auth.tenantCode ?? '';

      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        if (tenantId > 0) 'X-Tenant-Id': tenantId.toString(),
        if (tenantCode.isNotEmpty) 'X-Tenant-Code': tenantCode,
      };

      // Fetch dynamic master dropdowns once on start or if not loaded
      if (!_hasDropdownsLoaded) {
        try {
          final dropRes = await http.get(
            Uri.parse('${ApiConfig.baseUrl}/masters/all-dropdowns'),
            headers: headers,
          ).timeout(const Duration(seconds: 4));
          if (dropRes.statusCode == 200) {
            final dropData = jsonDecode(dropRes.body);
            if (dropData is Map<String, dynamic>) {
              final catList = (dropData['categories'] as List?)?.map((c) => (c['name'] ?? c['categoryName'] ?? '').toString()).where((s) => s.isNotEmpty).toList() ?? [];
              final uomList = (dropData['uoms'] as List?)?.map((u) => (u['symbol'] ?? u['name'] ?? u['uomName'] ?? '').toString()).where((s) => s.isNotEmpty).toList() ?? [];
              final typeList = (dropData['itemTypes'] as List?)?.map((t) => (t['name'] ?? t['itemTypeName'] ?? '').toString()).where((s) => s.isNotEmpty).toList() ?? [];
              final brandList = (dropData['brands'] as List?)?.map((b) => (b['name'] ?? b['brandName'] ?? '').toString()).where((s) => s.isNotEmpty).toList() ?? [];

              if (catList.isNotEmpty) {
                _dynamicCategories.clear();
                _dynamicCategories.addAll(catList);
              }
              if (uomList.isNotEmpty) {
                _dynamicUoms.clear();
                _dynamicUoms.addAll(uomList);
              }
              if (typeList.isNotEmpty) {
                _dynamicItemTypes.clear();
                _dynamicItemTypes.addAll(typeList);
              }
              if (brandList.isNotEmpty) {
                _dynamicBrands.clear();
                _dynamicBrands.addAll(brandList);
              }
              _hasDropdownsLoaded = true;
            }
          }
        } catch (_) {}
      }

      final queryParams = <String, String>{
        'page': _currentPage.toString(),
        'pageSize': _pageSize.toString(),
        'paged': 'true',
      };
      if (tenantId > 0) queryParams['tenantId'] = tenantId.toString();
      if (tenantCode.isNotEmpty) queryParams['tenantCode'] = tenantCode;
      if (_searchQuery.trim().isNotEmpty) queryParams['search'] = _searchQuery.trim();

      final url = Uri.parse('${ApiConfig.baseUrl}/Items').replace(queryParameters: queryParams);
      final res = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final dynamic raw = jsonDecode(res.body);
        final List<dynamic> data = raw is List ? raw : (raw['items'] as List? ?? []);
        final int total = raw is Map && raw['totalCount'] != null ? (raw['totalCount'] as num).toInt() : (_masterItems.length + data.length);
        final bool serverHasMore = raw is Map && raw['hasMore'] != null ? (raw['hasMore'] as bool) : (data.length >= _pageSize);

        final List<Map<String, dynamic>> newItems = [];
        for (var item in data) {
          newItems.add({
            'id': (item['id'] ?? item['ID'] ?? '').toString(),
            'itemCode': (item['itemCode'] ?? item['ItemCode'] ?? '').toString(),
            'name': (item['name'] ?? item['Name'] ?? '').toString(),
            'category': (item['category'] ?? item['Category'] ?? 'Groceries').toString(),
            'categoryId': item['categoryId'] ?? item['CategoryId'],
            'uom': (item['unit'] ?? item['Unit'] ?? 'pcs').toString(),
            'unitId': item['unitId'] ?? item['UnitId'],
            'format': (item['format'] ?? item['Format'] ?? 'Packed').toString(),
            'itemTypeId': item['itemTypeId'] ?? item['ItemTypeId'],
            'brand': (item['brand'] ?? item['Brand'] ?? '').toString(),
            'brandId': item['brandId'] ?? item['BrandId'],
            'description': (item['description'] ?? item['Description'] ?? '').toString(),
          });
        }

        if (mounted) {
          setState(() {
            if (reset) {
              _masterItems.clear();
            }
            final existingIds = _masterItems.map((i) => i['id']).toSet();
            for (var item in newItems) {
              if (!existingIds.contains(item['id'])) {
                _masterItems.add(item);
                existingIds.add(item['id']);
              }
            }
            _totalCount = total;
            _hasMore = serverHasMore;
            _currentPage++;
          });
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _confirmDeleteItem(Map<String, dynamic> item, bool isHindi) {
    final itemName = item['name'] ?? 'Item';
    final itemId = item['id'];

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: Text(isHindi ? 'सामान हटाएं?' : 'Delete Item?'),
        content: Text(
          isHindi
              ? 'क्या आप निश्चित रूप से "$itemName" को हटाना चाहते हैं?'
              : 'Are you sure you want to delete "$itemName"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: Text(isHindi ? 'रद्द करें' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(dlgCtx);
              try {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                final token = auth.accessToken ?? '';
                final tenantId = auth.tenantId ?? 0;
                final tenantCode = auth.tenantCode ?? '';

                final headers = <String, String>{
                  'Content-Type': 'application/json',
                  if (token.isNotEmpty) 'Authorization': 'Bearer $token',
                  if (tenantId > 0) 'X-Tenant-Id': tenantId.toString(),
                  if (tenantCode.isNotEmpty) 'X-Tenant-Code': tenantCode,
                };

                // Optimistic instant delete
                if (mounted) {
                  setState(() {
                    _masterItems.removeWhere((i) => i['id'] == itemId.toString());
                    if (_totalCount > 0) _totalCount--;
                  });
                }

                final res = await http.delete(
                  Uri.parse('${ApiConfig.baseUrl}/Items/$itemId'),
                  headers: headers,
                ).timeout(const Duration(seconds: 8));

                if (res.statusCode == 200 || res.statusCode == 204) {
                  if (mounted) {
                    ToastHelper.showSuccess(
                      context,
                      isHindi ? 'सामान "$itemName" हटा दिया गया!' : 'Item "$itemName" deleted successfully!',
                    );
                  }
                } else {
                  if (mounted) {
                    ToastHelper.showError(context, 'Failed to delete item from server.');
                    _fetchItems(reset: true);
                  }
                }
              } catch (e) {
                if (mounted) {
                  ToastHelper.showError(context, 'Delete error: $e');
                  _fetchItems(reset: true);
                }
              }
            },
            child: Text(isHindi ? 'हटाएं' : 'Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = Provider.of<LocaleProvider>(context).isHindi;
    final themeProvider = Provider.of<TenantThemeProvider>(context);

    final displayList = _masterItems;

    return Scaffold(
      backgroundColor: themeProvider.pageBgColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(
          isHindi ? 'सामान ($_totalCount)' : 'Items ($_totalCount)',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: isHindi ? 'रिफ्रेश' : 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _fetchItems(reset: true),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              // Search & Add Header
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: isHindi ? 'कोड, नाम, श्रेणी खोजें...' : 'Search Code, Name, Category...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    _searchQuery = '';
                                    _fetchItems(reset: true);
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        onChanged: (val) {
                          _searchQuery = val;
                          _debounceTimer?.cancel();
                          _debounceTimer = Timer(const Duration(milliseconds: 300), () {
                            _fetchItems(reset: true);
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeProvider.buttonBgColor,
                        foregroundColor: themeProvider.buttonTextColor,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: Icon(Icons.add_box_rounded, color: themeProvider.buttonTextColor, size: 20),
                      label: Text(
                        isHindi ? '+ नया सामान' : '+ Add Item',
                        style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.buttonTextColor),
                      ),
                      onPressed: () => _showAddMasterItemModal(context, isHindi),
                    ),
                  ],
                ),
              ),

              if (_isLoading)
                LinearProgressIndicator(color: themeProvider.primaryColor, minHeight: 3),

              // Master Items Catalog List with Infinite Scroll & Show More
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth >= 750;

                    Widget buildItemCard(Map<String, dynamic> item) {
                      final isLoose = item['format'] == 'Loose';
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: isLoose ? Colors.orange.shade50 : themeProvider.primaryColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isLoose ? Colors.orange.shade200 : themeProvider.primaryColor.withOpacity(0.2)),
                              ),
                              child: Icon(
                                isLoose ? Icons.scale_rounded : Icons.inventory_2_rounded,
                                color: isLoose ? Colors.orange.shade800 : themeProvider.primaryColor,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        item['itemCode'] ?? 'ITM-000',
                                        style: TextStyle(fontSize: 10.5, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: themeProvider.primaryColor),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: isLoose ? Colors.orange.shade100 : themeProvider.primaryColor.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isLoose ? 'Loose' : 'Packed',
                                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: isLoose ? Colors.orange.shade900 : themeProvider.primaryColor),
                                        ),
                                      ),
                                      if (item['brand'] != null && item['brand'].toString().isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.blue.shade200),
                                          ),
                                          child: Text(
                                            item['brand'].toString(),
                                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Colors.blue.shade800),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item['name'] ?? '',
                                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item['category']}  •  UOM: ${item['uom']}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                  ),
                                  if (item['description'] != null && item['description'].toString().isNotEmpty)
                                    Text(
                                      item['description'],
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: isHindi ? 'संपादित करें' : 'Edit',
                                  icon: Icon(Icons.edit_note_rounded, color: themeProvider.primaryColor),
                                  onPressed: () => _showAddMasterItemModal(context, isHindi, item),
                                ),
                                IconButton(
                                  tooltip: isHindi ? 'हटाएं' : 'Delete',
                                  icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400, size: 20),
                                  onPressed: () => _confirmDeleteItem(item, isHindi),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }

                    Widget buildPaginationFooter() {
                      if (_isLoadingMore) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                                SizedBox(width: 10),
                                Text('Loading more items...', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        );
                      }
                      if (_hasMore) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                side: BorderSide(color: themeProvider.primaryColor, width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: Icon(Icons.arrow_downward_rounded, size: 16, color: themeProvider.primaryColor),
                              label: Text(
                                isHindi ? 'और सामान देखें (+25)' : 'Show More (+25)',
                                style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.primaryColor),
                              ),
                              onPressed: () => _fetchItems(reset: false),
                            ),
                          ),
                        );
                      }
                      if (_masterItems.isNotEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: Text(
                              isHindi ? '✅ सभी $_totalCount सामान लोड हो चुके हैं' : '✅ All $_totalCount items loaded',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    }

                    if (displayList.isEmpty && !_isLoading) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                isHindi ? 'कोई सामान नहीं मिला' : 'No items found matching query',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 15, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: themeProvider.buttonBgColor,
                                  foregroundColor: themeProvider.buttonTextColor,
                                ),
                                icon: const Icon(Icons.add_rounded),
                                label: Text(isHindi ? 'पहला सामान जोड़ें' : 'Add First Item'),
                                onPressed: () => _showAddMasterItemModal(context, isHindi),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () => _fetchItems(reset: true),
                      child: CustomScrollView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            sliver: isDesktop
                                ? SliverGrid(
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                      mainAxisExtent: 96,
                                    ),
                                    delegate: SliverChildBuilderDelegate(
                                      (ctx, index) => buildItemCard(displayList[index]),
                                      childCount: displayList.length,
                                    ),
                                  )
                                : SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (ctx, index) => Padding(
                                        padding: const EdgeInsets.only(bottom: 8.0),
                                        child: buildItemCard(displayList[index]),
                                      ),
                                      childCount: displayList.length,
                                    ),
                                  ),
                          ),
                          SliverToBoxAdapter(
                            child: buildPaginationFooter(),
                          ),
                        ],
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

  void _showAddMasterItemModal(BuildContext context, bool isHindi, [Map<String, dynamic>? existing]) {
    final themeProvider = Provider.of<TenantThemeProvider>(context, listen: false);
    final codeCtrl = TextEditingController(text: existing?['itemCode'] ?? 'ITM-${1000 + Random().nextInt(8999)}');
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final descCtrl = TextEditingController(text: existing?['description'] ?? '');

    int? categoryId = existing?['categoryId'] is int
        ? existing!['categoryId']
        : int.tryParse('${existing?['categoryId']}');
    String categoryVal = existing?['category'] ?? '';

    int? uomId = existing?['unitId'] is int
        ? existing!['unitId']
        : int.tryParse('${existing?['unitId']}');
    String uomVal = existing?['uom'] ?? 'pcs';

    int? itemTypeId = existing?['itemTypeId'] is int
        ? existing!['itemTypeId']
        : int.tryParse('${existing?['itemTypeId']}');
    String formatVal = existing?['format'] ?? 'Packed';

    int? brandId = existing?['brandId'] is int
        ? existing!['brandId']
        : int.tryParse('${existing?['brandId']}');
    String brandVal = existing?['brand'] ?? '';

    bool isSaving = false;
    String? modalErrorMsg;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (modalErrorMsg != null && modalErrorMsg!.isNotEmpty)
                      ToastHelper.buildInlineAlert(modalErrorMsg!, isError: true),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          existing != null
                              ? (isHindi ? 'सामान अपडेट करें' : 'Edit Item')
                              : (isHindi ? 'नया सामान जोड़ें' : 'Add Item'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.grey),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Item Code & Name
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: codeCtrl,
                            decoration: InputDecoration(
                              labelText: isHindi ? 'आइटम कोड *' : 'Item Code *',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: nameCtrl,
                            decoration: InputDecoration(
                              labelText: isHindi ? 'सामान का नाम *' : 'Item Name *',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Dynamic Item Type (Packed, Loose, Service) from Master
                    MasterDropdown(
                      masterType: 'ItemType',
                      label: isHindi ? 'सामान का प्रकार (Item Type)' : 'Item Type',
                      selectedValue: formatVal,
                      selectedId: itemTypeId,
                      prefixIcon: const Icon(Icons.merge_type_rounded, size: 20),
                      onChanged: (id, name) {
                        setModalState(() {
                          itemTypeId = id;
                          formatVal = name ?? 'Packed';
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    // Dynamic Category & UOM Dropdowns from Masters
                    Row(
                      children: [
                        Expanded(
                          child: MasterDropdown(
                            masterType: 'ItemCategory',
                            label: isHindi ? 'श्रेणी (Category)' : 'Category',
                            selectedValue: categoryVal,
                            selectedId: categoryId,
                            isRequired: true,
                            prefixIcon: const Icon(Icons.category_rounded, size: 20),
                            onChanged: (id, name) {
                              setModalState(() {
                                categoryId = id;
                                categoryVal = name ?? '';
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: MasterDropdown(
                            masterType: 'UnitOfMeasurement',
                            label: isHindi ? 'इकाई (UOM)' : 'Unit (UOM)',
                            selectedValue: uomVal,
                            selectedId: uomId,
                            isRequired: true,
                            prefixIcon: const Icon(Icons.square_foot_rounded, size: 20),
                            onChanged: (id, name) {
                              setModalState(() {
                                uomId = id;
                                uomVal = name ?? 'pcs';
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Dynamic Brand Dropdown from Masters
                    MasterDropdown(
                      masterType: 'Brand',
                      label: isHindi ? 'ब्रांड (Brand)' : 'Brand',
                      selectedValue: brandVal,
                      selectedId: brandId,
                      allowClear: true,
                      prefixIcon: const Icon(Icons.branding_watermark_rounded, size: 20),
                      onChanged: (id, name) {
                        setModalState(() {
                          brandId = id;
                          brandVal = name ?? '';
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    // Description / Notes
                    TextField(
                      controller: descCtrl,
                      decoration: InputDecoration(
                        labelText: isHindi ? 'विवरण / टिप्पणी' : 'Description / Notes',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeProvider.buttonBgColor,
                          foregroundColor: themeProvider.buttonTextColor,
                        ),
                        onPressed: isSaving ? null : () async {
                          final trimmedName = nameCtrl.text.trim();
                          final trimmedCode = codeCtrl.text.trim();

                          if (trimmedName.isEmpty) {
                            setModalState(() {
                              modalErrorMsg = isHindi ? 'कृपया सामान का नाम दर्ज करें।' : 'Please enter item name.';
                            });
                            return;
                          }
                          if (trimmedCode.isEmpty) {
                            setModalState(() {
                              modalErrorMsg = isHindi ? 'कृपया आइटम कोड दर्ज करें।' : 'Please enter item code.';
                            });
                            return;
                          }

                          setModalState(() {
                            isSaving = true;
                            modalErrorMsg = null;
                          });

                          final auth = Provider.of<AuthProvider>(context, listen: false);
                          final token = auth.accessToken ?? '';
                          final tenantId = auth.tenantId ?? 0;
                          final tenantCode = auth.tenantCode ?? '';

                          final headers = <String, String>{
                            'Content-Type': 'application/json',
                            if (token.isNotEmpty) 'Authorization': 'Bearer $token',
                            if (tenantId > 0) 'X-Tenant-Id': tenantId.toString(),
                            if (tenantCode.isNotEmpty) 'X-Tenant-Code': tenantCode,
                          };

                          final payload = {
                            'itemCode': trimmedCode,
                            'name': trimmedName,
                            'category': categoryVal.isNotEmpty ? categoryVal : 'Groceries',
                            'categoryId': categoryId,
                            'unit': uomVal.isNotEmpty ? uomVal : 'pcs',
                            'unitId': uomId,
                            'format': formatVal.isNotEmpty ? formatVal : 'Packed',
                            'itemTypeId': itemTypeId,
                            'brandId': brandId,
                            'description': descCtrl.text.trim(),
                            'tenantId': tenantId > 0 ? tenantId : 1,
                          };

                          try {
                            http.Response res;
                            if (existing != null) {
                              res = await http.put(
                                Uri.parse('${ApiConfig.baseUrl}/Items/${existing['id']}'),
                                headers: headers,
                                body: jsonEncode({...payload, 'id': int.tryParse(existing['id'].toString()) ?? 0}),
                              ).timeout(const Duration(seconds: 10));
                            } else {
                              res = await http.post(
                                Uri.parse('${ApiConfig.baseUrl}/Items'),
                                headers: headers,
                                body: jsonEncode(payload),
                              ).timeout(const Duration(seconds: 10));
                            }

                            if (res.statusCode == 200 || res.statusCode == 201) {
                              dynamic resData;
                              try { resData = jsonDecode(res.body); } catch (_) {}
                              final int createdId = (resData is Map && resData['id'] != null)
                                  ? (resData['id'] as num).toInt()
                                  : (existing != null ? (int.tryParse(existing['id'].toString()) ?? 0) : DateTime.now().millisecondsSinceEpoch);

                              final itemRecord = {
                                'id': createdId.toString(),
                                'itemCode': trimmedCode,
                                'name': trimmedName,
                                'category': categoryVal.isNotEmpty ? categoryVal : 'Groceries',
                                'categoryId': categoryId,
                                'uom': uomVal.isNotEmpty ? uomVal : 'pcs',
                                'unitId': uomId,
                                'format': formatVal.isNotEmpty ? formatVal : 'Packed',
                                'itemTypeId': itemTypeId,
                                'brand': brandVal,
                                'brandId': brandId,
                                'description': descCtrl.text.trim(),
                              };

                              // INSTANT UI UPDATE in the list!
                              if (mounted) {
                                setState(() {
                                  if (existing != null) {
                                    final idx = _masterItems.indexWhere((i) => i['id'] == existing['id'].toString());
                                    if (idx >= 0) {
                                      _masterItems[idx] = itemRecord;
                                    }
                                  } else {
                                    _masterItems.removeWhere((i) => i['id'] == itemRecord['id'] || (i['itemCode'] == itemRecord['itemCode'] && itemRecord['itemCode'].toString().isNotEmpty));
                                    _masterItems.insert(0, itemRecord);
                                    _totalCount++;
                                  }
                                });
                              }

                              if (existing == null && _scrollController.hasClients) {
                                _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                              }

                              if (modalCtx.mounted) Navigator.pop(modalCtx, itemRecord);

                              if (context.mounted) {
                                ToastHelper.showSuccess(
                                  context,
                                  isHindi
                                      ? (existing != null ? 'सामान अपडेट हो गया!' : 'नया सामान "$trimmedName" तुरंत जोड़ा गया!')
                                      : (existing != null ? 'Item updated successfully!' : 'Item "$trimmedName" added instantly!'),
                                );
                              }

                              // Background sync with reset: true
                              _fetchItems(reset: true);
                            } else {
                              String errText = isHindi ? 'सामान सेव करने में विफल।' : 'Failed to save item.';
                              try {
                                final errJson = jsonDecode(res.body);
                                if (errJson is Map && errJson['message'] != null) {
                                  errText = errJson['message'].toString();
                                }
                              } catch (_) {
                                if (res.body.isNotEmpty && res.body.length < 150) errText = res.body;
                              }
                              setModalState(() {
                                modalErrorMsg = errText;
                                isSaving = false;
                              });
                              if (context.mounted) {
                                ToastHelper.showError(context, errText);
                              }
                            }
                          } catch (e) {
                            final errText = 'Network Error: $e';
                            setModalState(() {
                              modalErrorMsg = errText;
                              isSaving = false;
                            });
                            if (context.mounted) {
                              ToastHelper.showError(context, errText);
                            }
                          }
                        },
                        child: isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                existing != null
                                    ? (isHindi ? 'अपडेट सेव करें' : 'Update Item')
                                    : (isHindi ? 'सेव करें' : 'Save Item'),
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: themeProvider.buttonTextColor),
                              ),
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
