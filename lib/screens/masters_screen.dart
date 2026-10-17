import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/master_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/toast_helper.dart';
import '../widgets/app_drawer.dart';

class MastersScreen extends StatefulWidget {
  final int initialTabIndex;
  const MastersScreen({super.key, this.initialTabIndex = 0});

  @override
  State<MastersScreen> createState() => _MastersScreenState();
}

class _MastersScreenState extends State<MastersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _activeOnly = false;

  // Generic Master Lists stored per MasterType
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _uoms = [];
  List<Map<String, dynamic>> _itemTypes = [];
  List<Map<String, dynamic>> _brands = [];
  List<Map<String, dynamic>> _paymentModes = [];
  List<Map<String, dynamic>> _taxes = [];
  List<Map<String, dynamic>> _expenseCategories = [];

  bool _isLoading = false;

  // Tab definitions: id, masterType, english label, hindi label, icon, theme color
  static const List<Map<String, dynamic>> _tabConfigs = [
    {
      'type': 'ItemCategory',
      'labelEn': 'Categories',
      'labelHi': 'श्रेणियां',
      'descEn': 'Grocery, Electronics, Clothing...',
      'icon': Icons.category_rounded,
      'color': Color(0xFF6366F1), // Indigo
    },
    {
      'type': 'UnitOfMeasurement',
      'labelEn': 'UOM (Units)',
      'labelHi': 'मापक इकाइयाँ',
      'descEn': 'kg, gm, litre, ml, pcs, box...',
      'icon': Icons.straighten_rounded,
      'color': Color(0xFFF59E0B), // Amber
    },
    {
      'type': 'ItemType',
      'labelEn': 'Item Types',
      'labelHi': 'सामान प्रकार',
      'descEn': 'Packed Goods, Loose Goods, Service...',
      'icon': Icons.widgets_rounded,
      'color': Color(0xFF06B6D4), // Cyan
    },
    {
      'type': 'Brand',
      'labelEn': 'Brands',
      'labelHi': 'ब्रांड्स',
      'descEn': 'Tata, Amul, Nestle, Britannia...',
      'icon': Icons.verified_rounded,
      'color': Color(0xFF3B82F6), // Blue
    },
    {
      'type': 'PaymentMode',
      'labelEn': 'Payment Modes',
      'labelHi': 'भुगतान साधन',
      'descEn': 'Cash, UPI, Card, Udhaar, NetBanking...',
      'icon': Icons.payments_rounded,
      'color': Color(0xFF10B981), // Emerald
    },
    {
      'type': 'Tax',
      'labelEn': 'Taxes / GST',
      'labelHi': 'टैक्स / GST',
      'descEn': 'GST 0%, GST 5%, GST 12%, GST 18%...',
      'icon': Icons.percent_rounded,
      'color': Color(0xFFEC4899), // Pink
    },
    {
      'type': 'ExpenseCategory',
      'labelEn': 'Expense Categories',
      'labelHi': 'खर्च श्रेणियां',
      'descEn': 'Rent, Electricity, Salary, Transport...',
      'icon': Icons.account_balance_wallet_rounded,
      'color': Color(0xFF8B5CF6), // Purple
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabConfigs.length,
      vsync: this,
      initialIndex: (widget.initialTabIndex >= 0 && widget.initialTabIndex < _tabConfigs.length)
          ? widget.initialTabIndex
          : 0,
    );
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllMasters();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Map<String, String> _getHeaders() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.accessToken ?? '';
    final tenantId = auth.tenantId ?? 0;
    final tenantCode = auth.tenantCode ?? '';
    return {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (tenantId > 0) 'X-Tenant-Id': tenantId.toString(),
      if (tenantCode.isNotEmpty) 'X-Tenant-Code': tenantCode,
    };
  }

  String _getValStr(Map<String, dynamic> item, List<String> keys, {String fallback = ''}) {
    for (var k in keys) {
      if (item.containsKey(k) && item[k] != null && item[k].toString().trim().isNotEmpty) {
        return item[k].toString().trim();
      }
    }
    for (var entry in item.entries) {
      for (var k in keys) {
        if (entry.key.toLowerCase() == k.toLowerCase() && entry.value != null && entry.value.toString().trim().isNotEmpty) {
          return entry.value.toString().trim();
        }
      }
    }
    return fallback;
  }

  void _setMastersFromList(List<Map<String, dynamic>> allMasters) {
    if (!mounted) return;
    setState(() {
      _categories = allMasters.where((m) {
        final t = _getValStr(m, ['masterType', 'MasterType', 'type', 'Type']).toLowerCase();
        return t == 'itemcategory' || t == 'category' || t == 'categories';
      }).toList();
      _uoms = allMasters.where((m) {
        final t = _getValStr(m, ['masterType', 'MasterType', 'type', 'Type']).toLowerCase();
        return t == 'unitofmeasurement' || t == 'uom' || t == 'unit' || t == 'units';
      }).toList();
      _itemTypes = allMasters.where((m) {
        final t = _getValStr(m, ['masterType', 'MasterType', 'type', 'Type']).toLowerCase();
        return t == 'itemtype' || t == 'itemtypes' || t == 'format';
      }).toList();
      _brands = allMasters.where((m) {
        final t = _getValStr(m, ['masterType', 'MasterType', 'type', 'Type']).toLowerCase();
        return t == 'brand' || t == 'brands';
      }).toList();
      _paymentModes = allMasters.where((m) {
        final t = _getValStr(m, ['masterType', 'MasterType', 'type', 'Type']).toLowerCase();
        return t == 'paymentmode' || t == 'paymentmodes' || t == 'payment';
      }).toList();
      _taxes = allMasters.where((m) {
        final t = _getValStr(m, ['masterType', 'MasterType', 'type', 'Type']).toLowerCase();
        return t == 'tax' || t == 'taxes' || t == 'gst';
      }).toList();
      _expenseCategories = allMasters.where((m) {
        final t = _getValStr(m, ['masterType', 'MasterType', 'type', 'Type']).toLowerCase();
        return t == 'expensecategory' || t == 'expensecategories' || t == 'expense' || t == 'expenses';
      }).toList();
    });
  }

  Future<void> _loadAllMasters() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final masterProvider = Provider.of<MasterProvider>(context, listen: false);

    // Eagerly populate from MasterProvider in-memory cache if available (instant UI render)
    if (masterProvider.hasFetched && masterProvider.allMasters.isNotEmpty) {
      final all = masterProvider.allMasters.map((m) => {
        'id': m.id,
        'ID': m.id,
        'masterType': m.masterType,
        'MasterType': m.masterType,
        'masterName': m.masterName,
        'MasterName': m.masterName,
        'name': m.masterName,
        'masterCode': m.masterCode,
        'MasterCode': m.masterCode,
        'description': m.description,
        'Description': m.description,
        'priority': m.priority,
        'Priority': m.priority,
        'isActive': m.isActive,
        'IsActive': m.isActive,
      }).toList();
      _setMastersFromList(all);
    }

    setState(() => _isLoading = true);
    List<Map<String, dynamic>> loadedMasters = [];

    try {
      final baseUrl = ApiConfig.baseUrl;
      final headers = _getHeaders();
      final tenantId = auth.tenantId ?? 0;
      final qParam = tenantId > 0 ? '?tenantId=$tenantId' : '';

      // Step 1: Try primary /masters endpoint
      try {
        final res = await http.get(Uri.parse('$baseUrl/masters$qParam'), headers: headers).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          final List<dynamic> raw = jsonDecode(res.body);
          if (raw.isNotEmpty) {
            loadedMasters = List<Map<String, dynamic>>.from(raw);
          }
        }
      } catch (e) {
        debugPrint('Primary /masters endpoint error: $e');
      }

      // Step 2: Resilient fallback to /masters/all-dropdowns if primary had 0 records or error
      if (loadedMasters.isEmpty) {
        try {
          final fbRes = await http.get(Uri.parse('$baseUrl/masters/all-dropdowns$qParam'), headers: headers).timeout(const Duration(seconds: 8));
          if (fbRes.statusCode == 200) {
            final fbData = jsonDecode(fbRes.body);
            if (fbData is Map<String, dynamic>) {
              if (fbData['allMasters'] != null && fbData['allMasters'] is List) {
                loadedMasters = List<Map<String, dynamic>>.from(fbData['allMasters']);
              } else {
                final List<Map<String, dynamic>> collected = [];
                for (var key in ['categories', 'uoms', 'itemTypes', 'brands', 'paymentModes', 'taxes', 'expenseCategories']) {
                  final list = fbData[key];
                  if (list is List) {
                    collected.addAll(List<Map<String, dynamic>>.from(list));
                  }
                }
                if (collected.isNotEmpty) loadedMasters = collected;
              }
            } else if (fbData is List) {
              loadedMasters = List<Map<String, dynamic>>.from(fbData);
            }
          }
        } catch (e) {
          debugPrint('Fallback /masters/all-dropdowns error: $e');
        }
      }

      // Step 3: Populate state
      if (loadedMasters.isNotEmpty) {
        _setMastersFromList(loadedMasters);
      } else if (masterProvider.hasFetched && masterProvider.allMasters.isNotEmpty) {
        // Fallback to in-memory MasterProvider items
        final all = masterProvider.allMasters.map((m) => {
          'id': m.id,
          'ID': m.id,
          'masterType': m.masterType,
          'MasterType': m.masterType,
          'masterName': m.masterName,
          'MasterName': m.masterName,
          'name': m.masterName,
          'masterCode': m.masterCode,
          'MasterCode': m.masterCode,
          'description': m.description,
          'Description': m.description,
          'priority': m.priority,
          'Priority': m.priority,
          'isActive': m.isActive,
          'IsActive': m.isActive,
        }).toList();
        _setMastersFromList(all);
      }

      // Step 4: Keep MasterProvider background cache sync'd
      try {
        masterProvider.fetchAllMasters(
          auth.accessToken ?? '',
          forceRefresh: true,
          tenantId: tenantId > 0 ? tenantId : null,
          tenantCode: auth.tenantCode,
        );
      } catch (_) {}
    } catch (e) {
      debugPrint('Masters fetch error: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // Generic Toggle Active State API Call targeting V_Masters ID
  Future<void> _toggleActive(int id, bool currentActive) async {
    try {
      final baseUrl = ApiConfig.baseUrl;
      final res = await http.put(Uri.parse('$baseUrl/masters/$id/toggle-active'), headers: _getHeaders());
      if (res.statusCode == 200) {
        if (mounted) ToastHelper.showSuccess(context, 'Status updated successfully.');
        _loadAllMasters();
      } else {
        if (mounted) ToastHelper.showError(context, 'Failed to update status.');
      }
    } catch (e) {
      if (mounted) ToastHelper.showError(context, 'Error updating status: ${e.toString()}');
    }
  }

  // Generic Soft Delete API Call targeting V_Masters ID
  Future<void> _softDeleteMaster(int id, String name, bool isHindi) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            Text(isHindi ? 'हटाने की पुष्टि करें' : 'Confirm Delete', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          isHindi
              ? 'क्या आप वास्तव में master record "$name" को हटाना चाहते हैं?'
              : 'Are you sure you want to soft-delete master record "$name"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isHindi ? 'रद्द करें' : 'Cancel', style: TextStyle(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isHindi ? 'हटाएं' : 'Delete', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final baseUrl = ApiConfig.baseUrl;
        final res = await http.delete(Uri.parse('$baseUrl/masters/$id'), headers: _getHeaders());
        if (res.statusCode == 200) {
          if (mounted) ToastHelper.showSuccess(context, 'Record deleted successfully.');
          _loadAllMasters();
        } else {
          if (mounted) ToastHelper.showError(context, 'Failed to delete record.');
        }
      } catch (e) {
        if (mounted) ToastHelper.showError(context, 'Delete failed: ${e.toString()}');
      }
    }
  }

  void _showAuditDetails(BuildContext context, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Colors.blue, size: 24),
            SizedBox(width: 8),
            Text('Audit Trail (V_Masters)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _auditRow('Master ID:', '${item['id'] ?? item['ID']}'),
              _auditRow('Master Type:', '${item['masterType'] ?? item['MasterType']}'),
              _auditRow('Tenant ID:', '${item['tenantId'] ?? item['TenantId'] ?? 1}'),
              _auditRow('Name:', _resolveMasterName(item)),
              _auditRow('Code:', _resolveMasterCode(item)),
              _auditRow('Is Active:', item['isActive'] == true ? 'YES' : 'NO'),
              _auditRow('Priority:', '${item['priority'] ?? 0}'),
              _auditRow('Created By:', '${item['createdBy'] ?? 0}'),
              _auditRow('Created Date:', '${item['createdDate'] ?? 'N/A'}'),
              _auditRow('Modified By:', '${item['modifiedBy'] ?? 0}'),
              _auditRow('Modified Date:', '${item['modifiedDate'] ?? 'N/A'}'),
              _auditRow('Entry Source:', '${item['entrySource'] ?? 'API'}'),
              _auditRow('IP Address:', '${item['ipAddress'] ?? '127.0.0.1'}'),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _auditRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: Colors.black54))),
        ],
      ),
    );
  }

  String _resolveMasterName(Map<String, dynamic> item) {
    final name = _getValStr(item, [
      'masterName', 'MasterName',
      'name', 'Name',
      'categoryName', 'CategoryName',
      'uomName', 'UOMName',
      'itemTypeName', 'ItemTypeName',
      'brandName', 'BrandName',
      'paymentModeName', 'PaymentModeName',
      'taxName', 'TaxName',
      'expenseCategoryName', 'ExpenseCategoryName',
      'expenseName', 'ExpenseName',
      'title', 'Title',
      'label', 'Label',
    ]);
    if (name.isNotEmpty && name.toLowerCase() != 'unnamed') return name;

    // Fallback 1: Code / Symbol
    final code = _resolveMasterCode(item);
    if (code.isNotEmpty) return code;

    // Fallback 2: Description
    final desc = _getValStr(item, ['description', 'Description', 'desc', 'Desc']);
    if (desc.isNotEmpty) return desc;

    // Fallback 3: Master ID
    final id = item['id'] ?? item['ID'] ?? item['Id'] ?? '';
    return id.toString().isNotEmpty ? 'Master Record #$id' : 'Master Record';
  }

  String _resolveMasterCode(Map<String, dynamic> item) {
    return _getValStr(item, [
      'masterCode', 'MasterCode',
      'code', 'Code',
      'symbol', 'Symbol',
      'categoryCode', 'CategoryCode',
      'uomCode', 'UOMCode',
      'itemTypeCode', 'ItemTypeCode',
      'brandCode', 'BrandCode',
      'shortName', 'ShortName',
    ]);
  }

  List<Map<String, dynamic>> _getListForTab(int index) {
    switch (index) {
      case 0:
        return _categories;
      case 1:
        return _uoms;
      case 2:
        return _itemTypes;
      case 3:
        return _brands;
      case 4:
        return _paymentModes;
      case 5:
        return _taxes;
      case 6:
        return _expenseCategories;
      default:
        return _categories;
    }
  }

  // =========================================================================
  // MODERN ENTERPRISE TAB PILL WIDGET (GUARANTEED 100% CONTRAST & READABILITY)
  // =========================================================================
  Widget _buildTabPill({
    required int index,
    required Map<String, dynamic> tabConfig,
    required int count,
    required bool isSelected,
    required bool isDark,
    required Color primaryColor,
    required bool isHindi,
  }) {
    final label = isHindi ? tabConfig['labelHi'] : tabConfig['labelEn'];
    final icon = tabConfig['icon'] as IconData;
    final tabAccent = tabConfig['color'] as Color;

    final selectedColor = tabAccent;

    return InkWell(
      onTap: () {
        _tabController.animateTo(index);
        setState(() {});
      },
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedColor
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? selectedColor
                : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: selectedColor.withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : tabAccent,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A)),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 13,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected
                      ? selectedColor
                      : (isDark ? Colors.white : const Color(0xFF1E293B)),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final themeProvider = Provider.of<TenantThemeProvider>(context);
    final isHindi = localeProvider.isHindi;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = themeProvider.primaryColor;

    final currentTabIndex = _tabController.index;
    final currentTabConfig = _tabConfigs[currentTabIndex];
    final currentList = _getListForTab(currentTabIndex);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isHindi ? 'मास्टर्स डेटा प्रबंधन' : 'Master Data Management',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
            ),
            Text(
              isHindi ? '7 कोर मास्टर वर्गीकरण (Common Masters)' : '7 Core Classifications (Unified Masters)',
              style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: isHindi ? 'ताज़ा करें' : 'Refresh Masters',
            onPressed: _loadAllMasters,
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
            tooltip: isHindi ? 'नया जोड़ें' : 'Add New Master',
            onPressed: () => _showMasterFormModal(context, null),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          // =========================================================
          // 1. ENTERPRISE HORIZONTAL SCROLLABLE MASTER PILLS
          // =========================================================
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: List.generate(_tabConfigs.length, (idx) {
                  final config = _tabConfigs[idx];
                  final count = _getListForTab(idx).length;
                  final isSelected = currentTabIndex == idx;
                  return _buildTabPill(
                    index: idx,
                    tabConfig: config,
                    count: count,
                    isSelected: isSelected,
                    isDark: isDark,
                    primaryColor: primaryColor,
                    isHindi: isHindi,
                  );
                }),
              ),
            ),
          ),

          // =========================================================
          // 2. ACTIVE CATEGORY INFO BAR + SEARCH & FILTER
          // =========================================================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            child: Column(
              children: [
                Row(
                  children: [
                    // Active master type badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: (currentTabConfig['color'] as Color).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: (currentTabConfig['color'] as Color).withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(currentTabConfig['icon'] as IconData, size: 16, color: currentTabConfig['color'] as Color),
                          const SizedBox(width: 6),
                          Text(
                            isHindi ? currentTabConfig['labelHi'] : currentTabConfig['labelEn'],
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: currentTabConfig['color'] as Color,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: currentTabConfig['color'] as Color,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${currentList.length}',
                              style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Active Only Switch Chip
                    FilterChip(
                      label: Text(
                        isHindi ? 'सक्रिय केवल' : 'Active Only',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: _activeOnly ? primaryColor : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                      selected: _activeOnly,
                      onSelected: (val) => setState(() => _activeOnly = val),
                      selectedColor: primaryColor.withOpacity(0.15),
                      checkmarkColor: primaryColor,
                      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: _activeOnly ? primaryColor : (isDark ? Colors.grey.shade700 : Colors.grey.shade300)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Search Input Field
                SizedBox(
                  height: 42,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: isHindi ? 'खोजें (नाम, कोड या विवरण)...' : 'Search by name, code or description...',
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                      prefixIcon: const Icon(Icons.search, size: 19, color: Colors.grey),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: primaryColor, width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      filled: true,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                  ),
                ),
              ],
            ),
          ),

          // =========================================================
          // 3. TAB CONTENT LIST (CARDS VIEW)
          // =========================================================
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMasterList(_categories, 'ItemCategory', isHindi, isDark, primaryColor, const Color(0xFF6366F1), Icons.category_rounded),
                      _buildMasterList(_uoms, 'UnitOfMeasurement', isHindi, isDark, primaryColor, const Color(0xFFF59E0B), Icons.straighten_rounded),
                      _buildMasterList(_itemTypes, 'ItemType', isHindi, isDark, primaryColor, const Color(0xFF06B6D4), Icons.widgets_rounded),
                      _buildMasterList(_brands, 'Brand', isHindi, isDark, primaryColor, const Color(0xFF3B82F6), Icons.verified_rounded),
                      _buildMasterList(_paymentModes, 'PaymentMode', isHindi, isDark, primaryColor, const Color(0xFF10B981), Icons.payments_rounded),
                      _buildMasterList(_taxes, 'Tax', isHindi, isDark, primaryColor, const Color(0xFFEC4899), Icons.percent_rounded),
                      _buildMasterList(_expenseCategories, 'ExpenseCategory', isHindi, isDark, primaryColor, const Color(0xFF8B5CF6), Icons.account_balance_wallet_rounded),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          isHindi ? '+ नया रिकॉर्ड जोड़ें' : '+ Add Record',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        onPressed: () => _showMasterFormModal(context, null),
      ),
    );
  }

  // =========================================================================
  // ENTERPRISE MASTER LIST BUILDER WITH BEAUTIFUL CARDS
  // =========================================================================
  Widget _buildMasterList(
    List<Map<String, dynamic>> rawList,
    String masterType,
    bool isHindi,
    bool isDark,
    Color primaryColor,
    Color categoryColor,
    IconData categoryIcon,
  ) {
    var list = rawList.where((item) {
      final name = _resolveMasterName(item).toLowerCase();
      final code = _resolveMasterCode(item).toLowerCase();
      final desc = (item['description'] ?? '').toString().toLowerCase();
      final isActive = item['isActive'] == true;

      if (_activeOnly && !isActive) return false;
      if (_searchQuery.isNotEmpty && !name.contains(_searchQuery) && !code.contains(_searchQuery) && !desc.contains(_searchQuery)) {
        return false;
      }
      return true;
    }).toList();

    if (list.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: categoryColor.withOpacity(0.25), width: 1.5),
                ),
                child: Icon(categoryIcon, size: 38, color: categoryColor),
              ),
              const SizedBox(height: 16),
              Text(
                isHindi ? 'कोई $masterType रिकॉर्ड नहीं मिला' : 'No $masterType Records Found',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isHindi
                    ? 'नीचे दिए गए बटन से नया रिकॉर्ड जोड़ें या ऊपर से ताज़ा करें।'
                    : 'Get started by creating your first record in this master catalog.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(
                  isHindi ? '+ नया रिकॉर्ड जोड़ें' : '+ Add $masterType Record',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () => _showMasterFormModal(context, null),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllMasters,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: list.length,
        itemBuilder: (ctx, idx) {
          final item = list[idx];
          final id = item['id'] as int;
          final name = _resolveMasterName(item);
          final code = _resolveMasterCode(item);
          final desc = (item['description'] ?? '').toString();
          final isActive = item['isActive'] == true;
          final priority = item['priority'] ?? 0;

          return Card(
            elevation: 1,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isActive ? categoryColor.withOpacity(0.12) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActive ? categoryColor.withOpacity(0.3) : Colors.grey.shade300,
                  ),
                ),
                child: Icon(
                  categoryIcon,
                  color: isActive ? categoryColor : Colors.grey.shade500,
                  size: 22,
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        decoration: isActive ? TextDecoration.none : TextDecoration.lineThrough,
                        color: isActive
                            ? (isDark ? Colors.white : const Color(0xFF0F172A))
                            : Colors.grey.shade500,
                      ),
                    ),
                  ),
                  if (code.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: categoryColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        code,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: categoryColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Active/Inactive Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isActive ? Colors.green.shade50 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: isActive ? Colors.green.shade200 : Colors.red.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isActive ? Colors.green.shade700 : Colors.red.shade700,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isActive ? 'ACTIVE' : 'INACTIVE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isActive ? Colors.green.shade800 : Colors.red.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('Priority: $priority', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      const Spacer(),
                      // Audit details button
                      InkWell(
                        onTap: () => _showAuditDetails(context, item),
                        child: Text(
                          'Audit Info',
                          style: TextStyle(fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: isActive,
                    activeColor: Colors.green,
                    onChanged: (val) => _toggleActive(id, isActive),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (val) {
                      if (val == 'edit') {
                        _showMasterFormModal(context, item);
                      } else if (val == 'delete') {
                        _softDeleteMaster(id, name, isHindi);
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [Icon(Icons.edit, size: 18, color: primaryColor), const SizedBox(width: 8), Text(isHindi ? 'संपादित करें' : 'Edit')]),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [const Icon(Icons.delete, size: 18, color: Colors.red), const SizedBox(width: 8), Text(isHindi ? 'हटाएं' : 'Delete')]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // =========================================================================
  // ENTERPRISE ADD / EDIT MASTER FORM MODAL
  // =========================================================================
  void _showMasterFormModal(BuildContext context, Map<String, dynamic>? item) {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final themeProvider = Provider.of<TenantThemeProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isHindi = localeProvider.isHindi;
    final isEdit = item != null;
    final primaryColor = themeProvider.primaryColor;

    final tabIndex = _tabController.index;
    final tabConfig = _tabConfigs[tabIndex];
    final currentMasterType = tabConfig['type'] as String;
    final tabTitle = isHindi ? tabConfig['labelHi'] : tabConfig['labelEn'];

    final nameCtrl = TextEditingController(text: item != null ? _resolveMasterName(item) : '');
    final codeCtrl = TextEditingController(text: item != null ? _resolveMasterCode(item) : '');
    final descCtrl = TextEditingController(text: item != null ? _getValStr(item, ['description', 'Description']) : '');
    final priorityCtrl = TextEditingController(text: item != null ? _getValStr(item, ['priority', 'Priority'], fallback: '0') : '0');
    final typeCtrl = TextEditingController(text: item != null ? _getValStr(item, ['masterType', 'MasterType'], fallback: currentMasterType) : currentMasterType);

    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (modalCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 16,
              top: 20,
              left: 20,
              right: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(isEdit ? Icons.edit_rounded : Icons.add_circle_rounded, color: primaryColor, size: 28),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isEdit
                              ? (isHindi ? '$tabTitle संपादित करें (V_Masters)' : 'Edit $tabTitle')
                              : (isHindi ? 'नया $tabTitle जोड़ें (V_Masters)' : 'Add New $tabTitle'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Master Type Field
                  TextField(
                    controller: typeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Master Type (Domain Classification)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Name Field
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: '$tabTitle Name / Master Name *',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Code Field
                  TextField(
                    controller: codeCtrl,
                    decoration: InputDecoration(
                      labelText: '$tabTitle Code / Short Symbol',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Description
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description (Optional)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Priority Order
                  TextField(
                    controller: priorityCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Display Priority Order (0 = Default)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final nameText = nameCtrl.text.trim();
                              if (nameText.isEmpty) {
                                ToastHelper.showError(context, 'Master Name is required!');
                                return;
                              }

                              setModalState(() => isSubmitting = true);

                              try {
                                final baseUrl = ApiConfig.baseUrl;
                                final mType = typeCtrl.text.trim().isEmpty ? currentMasterType : typeCtrl.text.trim();
                                final mCode = codeCtrl.text.trim();

                                Map<String, dynamic> body = {
                                  'tenantId': auth.tenantId ?? 1,
                                  'masterType': mType,
                                  'masterName': nameText,
                                  'masterCode': mCode,
                                  'description': descCtrl.text.trim(),
                                  'priority': int.tryParse(priorityCtrl.text) ?? 0,
                                };

                                final itemId = item != null ? (item['id'] ?? item['ID']) : null;
                                final url = isEdit ? '$baseUrl/masters/$itemId' : '$baseUrl/masters';
                                final res = isEdit
                                    ? await http.put(Uri.parse(url), headers: _getHeaders(), body: jsonEncode(body))
                                    : await http.post(Uri.parse(url), headers: _getHeaders(), body: jsonEncode(body));

                                if (!modalCtx.mounted) return;

                                if (res.statusCode == 200 || res.statusCode == 201) {
                                  ToastHelper.showSuccess(modalCtx, '$tabTitle saved successfully into V_Masters!');
                                  Navigator.pop(modalCtx);
                                  _loadAllMasters();
                                } else {
                                  String errorMsg = 'Failed to save master record.';
                                  try {
                                    final err = jsonDecode(res.body);
                                    if (err is Map<String, dynamic>) {
                                      errorMsg = err['message'] ?? err['Message'] ?? err['error'] ?? errorMsg;
                                    }
                                  } catch (_) {
                                    if (res.body.isNotEmpty && res.body.length < 200) {
                                      errorMsg = res.body;
                                    }
                                  }
                                  ToastHelper.showError(modalCtx, errorMsg);
                                  setModalState(() => isSubmitting = false);
                                }
                              } catch (e) {
                                if (modalCtx.mounted) {
                                  ToastHelper.showError(modalCtx, 'Error: ${e.toString()}');
                                  setModalState(() => isSubmitting = false);
                                }
                              }
                            },
                      child: isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(
                              isEdit ? (isHindi ? 'अद्यतन करें' : 'Update Master') : (isHindi ? 'सहेजें' : 'Save Master'),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
