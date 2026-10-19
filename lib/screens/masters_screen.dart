import 'dart:async';
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
  bool _isLoading = false;

  // Master records loaded dynamically from DB for the tenant
  List<Map<String, dynamic>> _allLoadedMasters = [];
  List<String> _distinctMasterTypes = [];
  List<Map<String, dynamic>> _tabConfigs = [];

  // Known metadata lookup for core types (preserves icons, Hindi translations, and brand colors)
  static final Map<String, Map<String, dynamic>> _knownMasterMeta = {
    'itemcategory': {
      'type': 'ItemCategory',
      'labelEn': 'Categories',
      'labelHi': 'श्रेणियां',
      'descEn': 'Grocery, Electronics, Clothing...',
      'icon': Icons.category_rounded,
      'color': const Color(0xFF6366F1), // Indigo
      'sortOrder': 1,
    },
    'unitofmeasurement': {
      'type': 'UnitOfMeasurement',
      'labelEn': 'UOM (Units)',
      'labelHi': 'मापक इकाइयाँ',
      'descEn': 'kg, gm, litre, ml, pcs, box...',
      'icon': Icons.straighten_rounded,
      'color': const Color(0xFFF59E0B), // Amber
      'sortOrder': 2,
    },
    'itemtype': {
      'type': 'ItemType',
      'labelEn': 'Item Types',
      'labelHi': 'सामान प्रकार',
      'descEn': 'Packed Goods, Loose Goods, Service...',
      'icon': Icons.widgets_rounded,
      'color': const Color(0xFF06B6D4), // Cyan
      'sortOrder': 3,
    },
    'brand': {
      'type': 'Brand',
      'labelEn': 'Brands',
      'labelHi': 'ब्रांड्स',
      'descEn': 'Tata, Amul, Nestle, Britannia...',
      'icon': Icons.verified_rounded,
      'color': const Color(0xFF3B82F6), // Blue
      'sortOrder': 4,
    },
    'paymentmode': {
      'type': 'PaymentMode',
      'labelEn': 'Payment Modes',
      'labelHi': 'भुगतान साधन',
      'descEn': 'Cash, UPI, Card, Udhaar, NetBanking...',
      'icon': Icons.payments_rounded,
      'color': const Color(0xFF10B981), // Emerald
      'sortOrder': 5,
    },
    'tax': {
      'type': 'Tax',
      'labelEn': 'Taxes / GST',
      'labelHi': 'टैक्स / GST',
      'descEn': 'GST 0%, GST 5%, GST 12%, GST 18%...',
      'icon': Icons.percent_rounded,
      'color': const Color(0xFFEC4899), // Pink
      'sortOrder': 6,
    },
    'expensecategory': {
      'type': 'ExpenseCategory',
      'labelEn': 'Expense Categories',
      'labelHi': 'खर्च श्रेणियां',
      'descEn': 'Rent, Electricity, Salary, Transport...',
      'icon': Icons.account_balance_wallet_rounded,
      'color': const Color(0xFF8B5CF6), // Purple
      'sortOrder': 7,
    },
  };

  static const List<Color> _paletteColors = [
    Color(0xFF6366F1), // Indigo
    Color(0xFFF59E0B), // Amber
    Color(0xFF06B6D4), // Cyan
    Color(0xFF3B82F6), // Blue
    Color(0xFF10B981), // Emerald
    Color(0xFFEC4899), // Pink
    Color(0xFF8B5CF6), // Purple
    Color(0xFF14B8A6), // Teal
    Color(0xFFF97316), // Orange
    Color(0xFF64748B), // Slate
  ];

  static const List<IconData> _paletteIcons = [
    Icons.folder_special_rounded,
    Icons.label_rounded,
    Icons.layers_rounded,
    Icons.inventory_2_rounded,
    Icons.tune_rounded,
    Icons.view_module_rounded,
    Icons.bookmark_rounded,
    Icons.grid_view_rounded,
  ];

  static const List<String> _defaultInitialTypes = [
    'ItemCategory',
    'UnitOfMeasurement',
    'ItemType',
    'Brand',
    'PaymentMode',
    'Tax',
    'ExpenseCategory',
  ];

  static String _formatTypeLabel(String type) {
    if (type.isEmpty) return '';
    if (type.toUpperCase() == type) return type;
    final spaced = type.replaceAllMapped(RegExp(r'(?<=[a-z])([A-Z])'), (m) => ' ${m.group(1)}');
    final formatted = spaced.replaceAll('_', ' ').replaceAll('-', ' ').trim();
    return formatted.isEmpty ? type : formatted;
  }

  int _getTypeSortOrder(String type) {
    final lower = type.trim().toLowerCase();
    if (_knownMasterMeta.containsKey(lower)) {
      return _knownMasterMeta[lower]!['sortOrder'] as int;
    }
    return 100;
  }

  Map<String, dynamic> _buildConfigForType(String rawType, int index) {
    final lower = rawType.trim().toLowerCase();
    if (_knownMasterMeta.containsKey(lower)) {
      final known = _knownMasterMeta[lower]!;
      return {
        'type': rawType,
        'labelEn': known['labelEn'],
        'labelHi': known['labelHi'],
        'descEn': known['descEn'],
        'icon': known['icon'],
        'color': known['color'],
      };
    }

    final formatted = _formatTypeLabel(rawType);
    final color = _paletteColors[index % _paletteColors.length];
    final icon = _paletteIcons[index % _paletteIcons.length];

    return {
      'type': rawType,
      'labelEn': formatted,
      'labelHi': formatted,
      'descEn': '$formatted Master Records',
      'icon': icon,
      'color': color,
    };
  }

  @override
  void initState() {
    super.initState();
    _distinctMasterTypes = List<String>.from(_defaultInitialTypes);
    _tabConfigs = List.generate(
      _distinctMasterTypes.length,
      (i) => _buildConfigForType(_distinctMasterTypes[i], i),
    );

    _tabController = TabController(
      length: _tabConfigs.length,
      vsync: this,
      initialIndex: (widget.initialTabIndex >= 0 && widget.initialTabIndex < _tabConfigs.length)
          ? widget.initialTabIndex
          : 0,
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
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

  void _setDynamicTabConfigs(List<String> types, List<Map<String, dynamic>> allMasters) {
    if (!mounted) return;

    final Map<String, String> distinctMap = {};
    for (var t in types) {
      final trimmed = t.trim();
      if (trimmed.isNotEmpty) {
        final key = trimmed.toLowerCase();
        if (!distinctMap.containsKey(key)) {
          distinctMap[key] = trimmed;
        }
      }
    }

    for (var m in allMasters) {
      final t = _getValStr(m, ['masterType', 'MasterType', 'type', 'Type']).trim();
      if (t.isNotEmpty) {
        final key = t.toLowerCase();
        if (!distinctMap.containsKey(key)) {
          distinctMap[key] = t;
        }
      }
    }

    if (distinctMap.isEmpty) {
      for (var t in _defaultInitialTypes) {
        distinctMap[t.toLowerCase()] = t;
      }
    }

    final sortedTypes = distinctMap.values.toList();
    sortedTypes.sort((a, b) {
      final orderA = _getTypeSortOrder(a);
      final orderB = _getTypeSortOrder(b);
      if (orderA != orderB) return orderA.compareTo(orderB);
      return a.toLowerCase().compareTo(b.toLowerCase());
    });

    final newConfigs = List.generate(
      sortedTypes.length,
      (idx) => _buildConfigForType(sortedTypes[idx], idx),
    );

    final oldIndex = _tabController.index;
    final lengthChanged = _tabController.length != newConfigs.length;

    setState(() {
      _allLoadedMasters = allMasters;
      _distinctMasterTypes = sortedTypes;
      _tabConfigs = newConfigs;

      if (lengthChanged) {
        _tabController.dispose();
        final newIndex = (oldIndex >= 0 && oldIndex < newConfigs.length) ? oldIndex : 0;
        _tabController = TabController(
          length: newConfigs.length,
          vsync: this,
          initialIndex: newIndex,
        );
        _tabController.addListener(() {
          if (mounted) setState(() {});
        });
      }
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
      _setDynamicTabConfigs(masterProvider.masterTypes, all);
    }

    setState(() => _isLoading = true);
    List<Map<String, dynamic>> loadedMasters = [];
    List<String> loadedTypes = [];

    try {
      final baseUrl = ApiConfig.baseUrl;
      final headers = _getHeaders();
      final tenantId = auth.tenantId ?? 0;
      final qParam = tenantId > 0 ? '?tenantId=$tenantId' : '';

      // Step 1: Fetch distinct master types from DB for this tenant
      try {
        final typesRes = await http.get(Uri.parse('$baseUrl/masters/types$qParam'), headers: headers).timeout(const Duration(seconds: 8));
        if (typesRes.statusCode == 200) {
          final dynamic rawTypes = jsonDecode(typesRes.body);
          if (rawTypes is List) {
            loadedTypes = rawTypes.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
          }
        }
      } catch (e) {
        debugPrint('Fetch /masters/types error: $e');
      }

      // Step 2: Try primary /masters endpoint
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

      // Step 3: Resilient fallback to /masters/all-dropdowns if primary had 0 records or error
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

      // Step 4: Populate state with dynamic distinct types & masters
      if (loadedMasters.isNotEmpty || loadedTypes.isNotEmpty) {
        _setDynamicTabConfigs(loadedTypes, loadedMasters);
      } else if (masterProvider.hasFetched && masterProvider.allMasters.isNotEmpty) {
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
        _setDynamicTabConfigs(masterProvider.masterTypes, all);
      }

      // Step 5: Keep MasterProvider background cache sync'd
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

    final code = _resolveMasterCode(item);
    if (code.isNotEmpty) return code;

    final desc = _getValStr(item, ['description', 'Description', 'desc', 'Desc']);
    if (desc.isNotEmpty) return desc;

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

  List<Map<String, dynamic>> _getListForType(String masterType) {
    final lower = masterType.trim().toLowerCase();
    return _allLoadedMasters.where((m) {
      final t = _getValStr(m, ['masterType', 'MasterType', 'type', 'Type']).trim().toLowerCase();
      if (t == lower) return true;
      if (lower == 'itemcategory') return t == 'category' || t == 'categories';
      if (lower == 'unitofmeasurement') return t == 'uom' || t == 'unit' || t == 'units';
      if (lower == 'itemtype') return t == 'itemtypes' || t == 'format';
      if (lower == 'brand') return t == 'brands';
      if (lower == 'paymentmode') return t == 'paymentmodes' || t == 'payment';
      if (lower == 'tax') return t == 'taxes' || t == 'gst';
      if (lower == 'expensecategory') return t == 'expensecategories' || t == 'expense' || t == 'expenses';
      return false;
    }).toList();
  }

  List<Map<String, dynamic>> _getListForTab(int index) {
    if (index >= 0 && index < _tabConfigs.length) {
      return _getListForType(_tabConfigs[index]['type'] as String);
    }
    return [];
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

    final currentTabIndex = (_tabConfigs.isNotEmpty && _tabController.index < _tabConfigs.length)
        ? _tabController.index
        : 0;
    final currentTabConfig = _tabConfigs.isNotEmpty
        ? _tabConfigs[currentTabIndex]
        : _buildConfigForType('ItemCategory', 0);
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
              isHindi
                  ? '${_tabConfigs.length} मास्टर वर्गीकरण (Dynamic Masters)'
                  : '${_tabConfigs.length} Master Classifications (Dynamic Masters)',
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
          // 1. ENTERPRISE HORIZONTAL SCROLLABLE MASTER PILLS (DYNAMIC)
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
          // 3. TAB CONTENT LIST (CARDS VIEW DYNAMIC FOR ALL MASTERS)
          // =========================================================
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: List.generate(_tabConfigs.length, (idx) {
                      final config = _tabConfigs[idx];
                      final type = config['type'] as String;
                      final categoryColor = config['color'] as Color;
                      final categoryIcon = config['icon'] as IconData;
                      return MasterTabListView(
                        key: ValueKey('master_tab_${type}_$idx'),
                        masterType: type,
                        categoryColor: categoryColor,
                        categoryIcon: categoryIcon,
                        isHindi: isHindi,
                        isDark: isDark,
                        primaryColor: primaryColor,
                        searchQuery: _searchQuery,
                        activeOnly: _activeOnly,
                        onAddRecord: () => _showMasterFormModal(context, null),
                        onEdit: (item) => _showMasterFormModal(context, item),
                        onDelete: (id, name) => _softDeleteMaster(id, name, isHindi),
                        onToggleActive: (id, active) => _toggleActive(id, active),
                        onAuditDetails: (item) => _showAuditDetails(context, item),
                      );
                    }),
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
  // ENTERPRISE ADD / EDIT MASTER FORM MODAL WITH DYNAMIC MASTER TYPES
  // =========================================================================
  void _showMasterFormModal(BuildContext context, Map<String, dynamic>? item) {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final themeProvider = Provider.of<TenantThemeProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isHindi = localeProvider.isHindi;
    final isEdit = item != null;
    final primaryColor = themeProvider.primaryColor;

    final currentTabIndex = _tabConfigs.isNotEmpty ? _tabController.index.clamp(0, _tabConfigs.length - 1) : 0;
    final currentTabConfig = _tabConfigs.isNotEmpty ? _tabConfigs[currentTabIndex] : null;
    final defaultMasterType = currentTabConfig != null ? (currentTabConfig['type'] as String) : 'ItemCategory';

    String selectedType = item != null
        ? _getValStr(item, ['masterType', 'MasterType'], fallback: defaultMasterType)
        : defaultMasterType;

    bool isCustomType = false;
    final customTypeCtrl = TextEditingController();

    // Ensure selectedType is in options
    List<String> typeOptions = List<String>.from(_distinctMasterTypes);
    if (selectedType.isNotEmpty && !typeOptions.any((t) => t.toLowerCase() == selectedType.toLowerCase())) {
      typeOptions.add(selectedType);
    }
    if (typeOptions.isEmpty) {
      typeOptions = List<String>.from(_defaultInitialTypes);
    }

    final nameCtrl = TextEditingController(text: item != null ? _resolveMasterName(item) : '');
    final codeCtrl = TextEditingController(text: item != null ? _resolveMasterCode(item) : '');
    final descCtrl = TextEditingController(text: item != null ? _getValStr(item, ['description', 'Description']) : '');
    final priorityCtrl = TextEditingController(text: item != null ? _getValStr(item, ['priority', 'Priority'], fallback: '0') : '0');

    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (modalCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final effectiveType = isCustomType ? customTypeCtrl.text.trim() : selectedType;
          final titleType = effectiveType.isNotEmpty ? _formatTypeLabel(effectiveType) : (isHindi ? 'मास्टर' : 'Master');

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
                              ? (isHindi ? '$titleType संपादित करें' : 'Edit $titleType')
                              : (isHindi ? 'नया $titleType जोड़ें' : 'Add New $titleType'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Dynamic Master Type Selector Dropdown
                  DropdownButtonFormField<String>(
                    value: isCustomType ? '__NEW_TYPE__' : selectedType,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: isHindi ? 'मास्टर प्रकार (Master Type) *' : 'Master Type (Classification) *',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      prefixIcon: const Icon(Icons.category_outlined, size: 20),
                    ),
                    items: [
                      ...typeOptions.map((t) {
                        final meta = _knownMasterMeta[t.toLowerCase()];
                        final label = meta != null
                            ? (isHindi ? meta['labelHi'] : meta['labelEn'])
                            : _formatTypeLabel(t);
                        final icon = meta != null ? meta['icon'] as IconData : Icons.label_outline_rounded;
                        final color = meta != null ? meta['color'] as Color : primaryColor;

                        return DropdownMenuItem<String>(
                          value: t,
                          child: Row(
                            children: [
                              Icon(icon, size: 16, color: color),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  label == t ? t : '$t ($label)',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      DropdownMenuItem<String>(
                        value: '__NEW_TYPE__',
                        child: Row(
                          children: [
                            const Icon(Icons.add_circle_outline, size: 16, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isHindi ? '+ नया मास्टर प्रकार जोड़ें...' : '+ Add New Master Type...',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onChanged: isEdit
                        ? null // In edit mode, Master Type is immutable to preserve foreign relations
                        : (val) {
                            if (val == '__NEW_TYPE__') {
                              setModalState(() {
                                isCustomType = true;
                              });
                            } else if (val != null) {
                              setModalState(() {
                                isCustomType = false;
                                selectedType = val;
                              });
                            }
                          },
                  ),

                  // If user selected "+ Add New Master Type...", show custom type input
                  if (isCustomType) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: customTypeCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: isHindi ? 'नए मास्टर प्रकार का नाम दर्ज करें *' : 'Enter New Master Type Name *',
                        hintText: 'e.g. SupplierType, Warehouse, Department',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.edit_note_rounded, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      onChanged: (_) => setModalState(() {}),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Name Field
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: isHindi ? '$titleType नाम *' : '$titleType Name *',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Code Field
                  TextField(
                    controller: codeCtrl,
                    decoration: InputDecoration(
                      labelText: isHindi ? '$titleType कोड / संक्षिप्त संकेत' : '$titleType Code / Short Symbol',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Description
                  TextField(
                    controller: descCtrl,
                    decoration: InputDecoration(
                      labelText: isHindi ? 'विवरण (वैकल्पिक)' : 'Description (Optional)',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Priority Order
                  TextField(
                    controller: priorityCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: isHindi ? 'प्राथमिकता क्रम (0 = डिफ़ॉल्ट)' : 'Display Priority Order (0 = Default)',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                              final finalMasterType = isCustomType ? customTypeCtrl.text.trim() : selectedType.trim();
                              if (finalMasterType.isEmpty) {
                                ToastHelper.showError(context, isHindi ? 'मास्टर प्रकार आवश्यक है!' : 'Master Type is required!');
                                return;
                              }

                              final nameText = nameCtrl.text.trim();
                              if (nameText.isEmpty) {
                                ToastHelper.showError(context, isHindi ? 'मास्टर नाम आवश्यक है!' : 'Master Name is required!');
                                return;
                              }

                              setModalState(() => isSubmitting = true);

                              try {
                                final baseUrl = ApiConfig.baseUrl;
                                final mCode = codeCtrl.text.trim();

                                Map<String, dynamic> body = {
                                  'tenantId': auth.tenantId ?? 1,
                                  'masterType': finalMasterType,
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
                                  ToastHelper.showSuccess(modalCtx, '$titleType saved successfully into V_Masters!');
                                  Navigator.pop(modalCtx);
                                  await _loadAllMasters();

                                  // Automatically switch to the newly created/updated master type tab!
                                  final newTypeIdx = _tabConfigs.indexWhere((c) => (c['type'] as String).toLowerCase() == finalMasterType.toLowerCase());
                                  if (newTypeIdx >= 0 && mounted) {
                                    _tabController.animateTo(newTypeIdx);
                                  }
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

class MasterTabListView extends StatefulWidget {
  final String masterType;
  final Color categoryColor;
  final IconData categoryIcon;
  final bool isHindi;
  final bool isDark;
  final Color primaryColor;
  final String searchQuery;
  final bool activeOnly;
  final VoidCallback onAddRecord;
  final Function(Map<String, dynamic>) onEdit;
  final Future<void> Function(int, String) onDelete;
  final Future<void> Function(int, bool) onToggleActive;
  final Function(Map<String, dynamic>) onAuditDetails;

  const MasterTabListView({
    super.key,
    required this.masterType,
    required this.categoryColor,
    required this.categoryIcon,
    required this.isHindi,
    required this.isDark,
    required this.primaryColor,
    required this.searchQuery,
    required this.activeOnly,
    required this.onAddRecord,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
    required this.onAuditDetails,
  });

  @override
  State<MasterTabListView> createState() => _MasterTabListViewState();
}

class _MasterTabListViewState extends State<MasterTabListView> {
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _items = [];
  int _currentPage = 1;
  final int _pageSize = 25;
  bool _hasMore = true;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int _totalCount = 0;
  int get totalCount => _totalCount;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchItems(reset: true);
  }

  @override
  void didUpdateWidget(covariant MasterTabListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery || widget.activeOnly != oldWidget.activeOnly) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) _fetchItems(reset: true);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
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

      final queryParams = <String, String>{
        'page': _currentPage.toString(),
        'pageSize': _pageSize.toString(),
        'paged': 'true',
        'masterType': widget.masterType,
      };
      if (tenantId > 0) queryParams['tenantId'] = tenantId.toString();
      if (tenantCode.isNotEmpty) queryParams['tenantCode'] = tenantCode;
      if (widget.searchQuery.trim().isNotEmpty) queryParams['search'] = widget.searchQuery.trim();
      if (widget.activeOnly) queryParams['activeOnly'] = 'true';

      final url = Uri.parse('${ApiConfig.baseUrl}/masters').replace(queryParameters: queryParams);
      final res = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final dynamic raw = jsonDecode(res.body);
        final List<dynamic> data = raw is List ? raw : (raw['items'] as List? ?? []);
        final int total = raw is Map && raw['totalCount'] != null ? raw['totalCount'] as int : (_items.length + data.length);
        final bool serverHasMore = raw is Map && raw['hasMore'] != null ? raw['hasMore'] as bool : (data.length >= _pageSize);

        final List<Map<String, dynamic>> loaded = List<Map<String, dynamic>>.from(data);

        if (mounted) {
          setState(() {
            if (reset) {
              _items.clear();
            }
            final existingIds = _items.map((i) => i['id'] ?? i['ID']).toSet();
            for (var item in loaded) {
              final id = item['id'] ?? item['ID'];
              if (!existingIds.contains(id)) {
                _items.add(item);
                existingIds.add(id);
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

  String _resolveMasterName(Map<String, dynamic> item) {
    for (var k in ['masterName', 'MasterName', 'name', 'Name', 'categoryName', 'uomName', 'brandName', 'taxName']) {
      if (item[k] != null && item[k].toString().trim().isNotEmpty) return item[k].toString().trim();
    }
    return 'Master #${item['id'] ?? item['ID'] ?? ''}';
  }

  String _resolveMasterCode(Map<String, dynamic> item) {
    for (var k in ['masterCode', 'MasterCode', 'code', 'Code', 'symbol', 'Symbol']) {
      if (item[k] != null && item[k].toString().trim().isNotEmpty) return item[k].toString().trim();
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
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
                  color: widget.categoryColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: widget.categoryColor.withOpacity(0.25), width: 1.5),
                ),
                child: Icon(widget.categoryIcon, size: 38, color: widget.categoryColor),
              ),
              const SizedBox(height: 16),
              Text(
                widget.isHindi ? 'कोई ${widget.masterType} रिकॉर्ड नहीं मिला' : 'No ${widget.masterType} Records Found',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.isHindi
                    ? 'नीचे दिए गए बटन से नया रिकॉर्ड जोड़ें या ऊपर से ताज़ा करें।'
                    : 'Get started by creating your first record in this master catalog.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(
                  widget.isHindi ? '+ नया रिकॉर्ड जोड़ें' : '+ Add ${widget.masterType} Record',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: widget.onAddRecord,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchItems(reset: true),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: _items.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (ctx, idx) {
          if (idx == _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final item = _items[idx];
          final id = (item['id'] ?? item['ID']) as int;
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
                color: widget.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            color: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isActive ? widget.categoryColor.withOpacity(0.12) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActive ? widget.categoryColor.withOpacity(0.3) : Colors.grey.shade300,
                  ),
                ),
                child: Icon(
                  widget.categoryIcon,
                  color: isActive ? widget.categoryColor : Colors.grey.shade500,
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
                            ? (widget.isDark ? Colors.white : const Color(0xFF0F172A))
                            : Colors.grey.shade500,
                      ),
                    ),
                  ),
                  if (code.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: widget.categoryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: widget.categoryColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        code,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: widget.categoryColor,
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
                      InkWell(
                        onTap: () => widget.onAuditDetails(item),
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
                    onChanged: (val) async {
                      await widget.onToggleActive(id, isActive);
                      _fetchItems(reset: true);
                    },
                  ),
                  PopupMenuButton<String>(
                    onSelected: (val) async {
                      if (val == 'edit') {
                        widget.onEdit(item);
                      } else if (val == 'delete') {
                        await widget.onDelete(id, name);
                        _fetchItems(reset: true);
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [Icon(Icons.edit, size: 18, color: widget.primaryColor), const SizedBox(width: 8), Text(widget.isHindi ? 'संपादित करें' : 'Edit')]),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [const Icon(Icons.delete, size: 18, color: Colors.red), const SizedBox(width: 8), Text(widget.isHindi ? 'हटाएं' : 'Delete')]),
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
}
