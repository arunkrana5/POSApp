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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 7,
      vsync: this,
      initialIndex: (widget.initialTabIndex >= 0 && widget.initialTabIndex < 7) ? widget.initialTabIndex : 0,
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
    super.dispose();
  }

  String _getAuthToken() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return auth.accessToken ?? '';
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
      _categories = allMasters.where((m) => _getValStr(m, ['masterType', 'MasterType']).toLowerCase() == 'itemcategory').toList();
      _uoms = allMasters.where((m) => _getValStr(m, ['masterType', 'MasterType']).toLowerCase() == 'unitofmeasurement').toList();
      _itemTypes = allMasters.where((m) => _getValStr(m, ['masterType', 'MasterType']).toLowerCase() == 'itemtype').toList();
      _brands = allMasters.where((m) => _getValStr(m, ['masterType', 'MasterType']).toLowerCase() == 'brand').toList();
      _paymentModes = allMasters.where((m) => _getValStr(m, ['masterType', 'MasterType']).toLowerCase() == 'paymentmode').toList();
      _taxes = allMasters.where((m) => _getValStr(m, ['masterType', 'MasterType']).toLowerCase() == 'tax').toList();
      _expenseCategories = allMasters.where((m) => _getValStr(m, ['masterType', 'MasterType']).toLowerCase() == 'expensecategory').toList();
    });
  }

  Future<void> _loadAllMasters() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final masterProvider = Provider.of<MasterProvider>(context, listen: false);

    // Eagerly populate from MasterProvider in-memory cache if available
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
    try {
      final baseUrl = ApiConfig.baseUrl;
      final headers = _getHeaders();
      final tenantId = auth.tenantId ?? 0;
      final qParam = tenantId > 0 ? '?tenantId=$tenantId' : '';

      final res = await http.get(Uri.parse('$baseUrl/masters$qParam'), headers: headers).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200 && mounted) {
        final List<dynamic> raw = jsonDecode(res.body);
        final allMasters = List<Map<String, dynamic>>.from(raw);

        if (allMasters.isNotEmpty) {
          _setMastersFromList(allMasters);
        } else {
          // Fallback to bulk all-dropdowns endpoint
          final fbRes = await http.get(Uri.parse('$baseUrl/masters/all-dropdowns$qParam'), headers: headers).timeout(const Duration(seconds: 8));
          if (fbRes.statusCode == 200 && mounted) {
            final fbData = jsonDecode(fbRes.body);
            if (fbData['allMasters'] != null) {
              _setMastersFromList(List<Map<String, dynamic>>.from(fbData['allMasters']));
            }
          }
        }

        // Keep MasterProvider synchronized
        try {
          masterProvider.fetchAllMasters(
            auth.accessToken ?? '',
            forceRefresh: true,
            tenantId: tenantId > 0 ? tenantId : null,
            tenantCode: auth.tenantCode,
          );
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Masters fetch notice: $e');
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
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            Text(isHindi ? 'हटाने की पुष्टि करें' : 'Confirm Delete'),
          ],
        ),
        content: Text(
          isHindi
              ? 'क्या आप वास्तव में master record "$name" को हटाना चाहते हैं?'
              : 'Are you sure you want to soft-delete master record "$name"?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isHindi ? 'रद्द करें' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isHindi ? 'हटाएं' : 'Delete', style: const TextStyle(color: Colors.white)),
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
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Colors.blue, size: 24),
            SizedBox(width: 8),
            Text('Audit Trail (11 Common Columns)', style: TextStyle(fontSize: 16)),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
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

  Widget _buildTabItem({
    required int index,
    required IconData icon,
    required String label,
    required int count,
    required Color primaryColor,
  }) {
    final isSelected = _tabController.index == index;
    return Tab(
      height: 42,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white30,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
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
              color: isSelected ? primaryColor : Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? primaryColor : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 13,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : Colors.white.withOpacity(0.28),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
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

    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        title: Text(
          isHindi ? 'मास्टर्स प्रबंधन (Unified Masters)' : 'Master Management',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            color: primaryColor,
            child: Theme(
              data: Theme.of(context).copyWith(
                tabBarTheme: const TabBarTheme(
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicatorSize: TabBarIndicatorSize.label,
                ),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: Colors.transparent,
                dividerColor: Colors.transparent,
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                tabs: [
                  _buildTabItem(index: 0, icon: Icons.category_rounded, label: isHindi ? 'श्रेणियां' : 'Categories', count: _categories.length, primaryColor: primaryColor),
                  _buildTabItem(index: 1, icon: Icons.square_foot_rounded, label: isHindi ? 'मापक इकाइयाँ' : 'UOMs', count: _uoms.length, primaryColor: primaryColor),
                  _buildTabItem(index: 2, icon: Icons.merge_type_rounded, label: isHindi ? 'सामान प्रकार' : 'Item Types', count: _itemTypes.length, primaryColor: primaryColor),
                  _buildTabItem(index: 3, icon: Icons.branding_watermark_rounded, label: isHindi ? 'ब्रांड्स' : 'Brands', count: _brands.length, primaryColor: primaryColor),
                  _buildTabItem(index: 4, icon: Icons.payments_rounded, label: isHindi ? 'भुगतान साधन' : 'Payment Modes', count: _paymentModes.length, primaryColor: primaryColor),
                  _buildTabItem(index: 5, icon: Icons.receipt_long_rounded, label: isHindi ? 'टैक्स / GST' : 'Taxes / GST', count: _taxes.length, primaryColor: primaryColor),
                  _buildTabItem(index: 6, icon: Icons.money_off_rounded, label: isHindi ? 'खर्च श्रेणियां' : 'Expense Categories', count: _expenseCategories.length, primaryColor: primaryColor),
                ],
              ),
            ),
          ),
        ),
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          // Filter & Search Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: isHindi ? 'खोजें (नाम, कोड)...' : 'Search master records...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: primaryColor, width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      fillColor: isDark ? Colors.grey.shade800 : Colors.white,
                      filled: true,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                  ),
                ),
                const SizedBox(width: 12),
                FilterChip(
                  label: Text(
                    isHindi ? 'सक्रिय केवल' : 'Active Only',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _activeOnly ? primaryColor : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                  selected: _activeOnly,
                  onSelected: (val) => setState(() => _activeOnly = val),
                  selectedColor: primaryColor.withOpacity(0.15),
                  checkmarkColor: primaryColor,
                  backgroundColor: isDark ? Colors.grey.shade800 : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: _activeOnly ? primaryColor : Colors.grey.shade300)),
                ),
              ],
            ),
          ),

          // Tab Content List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMasterList(_categories, 'ItemCategory', isHindi, isDark, primaryColor),
                      _buildMasterList(_uoms, 'UnitOfMeasurement', isHindi, isDark, primaryColor),
                      _buildMasterList(_itemTypes, 'ItemType', isHindi, isDark, primaryColor),
                      _buildMasterList(_brands, 'Brand', isHindi, isDark, primaryColor),
                      _buildMasterList(_paymentModes, 'PaymentMode', isHindi, isDark, primaryColor),
                      _buildMasterList(_taxes, 'Tax', isHindi, isDark, primaryColor),
                      _buildMasterList(_expenseCategories, 'ExpenseCategory', isHindi, isDark, primaryColor),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          isHindi ? 'नया मास्टर जोड़ें' : 'Add Master',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () => _showMasterFormModal(context, null),
      ),
    );
  }

  String _resolveMasterName(Map<String, dynamic> item) {
    final name = _getValStr(item, ['masterName', 'MasterName', 'name', 'Name', 'categoryName', 'uomName', 'itemTypeName', 'brandName']);
    if (name.isNotEmpty) return name;
    final id = item['id'] ?? item['ID'] ?? '';
    return 'Master Record #$id';
  }

  String _resolveMasterCode(Map<String, dynamic> item) {
    return _getValStr(item, ['masterCode', 'MasterCode', 'code', 'Code', 'symbol', 'Symbol', 'categoryCode', 'uomCode', 'itemTypeCode', 'brandCode']);
  }

  Widget _buildMasterList(List<Map<String, dynamic>> rawList, String masterType, bool isHindi, bool isDark, Color primaryColor) {
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
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.category_outlined, size: 42, color: primaryColor),
              ),
              const SizedBox(height: 16),
              Text(
                isHindi ? 'कोई $masterType रिकॉर्ड नहीं मिला' : 'No $masterType Records Found',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isHindi
                    ? 'नीचे दिए गए बटन से नया रिकॉर्ड जोड़ें या ऊपर से रिफ्रेश करें।'
                    : 'Get started by creating your first record in this master category.',
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
        padding: const EdgeInsets.all(12),
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
            elevation: 1.5,
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
            ),
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isActive ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActive ? Colors.green.shade200 : Colors.red.shade200,
                  ),
                ),
                child: Icon(
                  isActive ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
                  color: isActive ? Colors.green.shade700 : Colors.red.shade700,
                  size: 24,
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
                        color: isActive ? (isDark ? Colors.white : const Color(0xFF1E293B)) : Colors.grey,
                      ),
                    ),
                  ),
                  if (code.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: primaryColor.withOpacity(0.25)),
                      ),
                      child: Text(
                        code,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 4),
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
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          masterType,
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade800, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('Priority: $priority', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.info_outline_rounded, size: 20, color: Colors.blueGrey),
                    tooltip: 'Audit Info',
                    onPressed: () => _showAuditDetails(context, item),
                  ),
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

  void _showMasterFormModal(BuildContext context, Map<String, dynamic>? item) {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final themeProvider = Provider.of<TenantThemeProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isHindi = localeProvider.isHindi;
    final isEdit = item != null;
    final primaryColor = themeProvider.primaryColor;

    final tabIndex = _tabController.index;
    String currentMasterType = 'ItemCategory';
    String tabTitle = 'Category';

    if (tabIndex == 1) {
      currentMasterType = 'UnitOfMeasurement';
      tabTitle = 'Unit of Measurement';
    } else if (tabIndex == 2) {
      currentMasterType = 'ItemType';
      tabTitle = 'Item Type';
    } else if (tabIndex == 3) {
      currentMasterType = 'Brand';
      tabTitle = 'Brand';
    } else if (tabIndex == 4) {
      currentMasterType = 'PaymentMode';
      tabTitle = 'Payment Mode';
    } else if (tabIndex == 5) {
      currentMasterType = 'Tax';
      tabTitle = 'Tax / GST Rate';
    } else if (tabIndex == 6) {
      currentMasterType = 'ExpenseCategory';
      tabTitle = 'Expense Category';
    }

    final nameCtrl = TextEditingController(text: item != null ? _resolveMasterName(item) : '');
    final codeCtrl = TextEditingController(text: item != null ? _resolveMasterCode(item) : '');
    final descCtrl = TextEditingController(text: item != null ? _getValStr(item, ['description', 'Description']) : '');
    final priorityCtrl = TextEditingController(text: item != null ? '${_getValStr(item, ['priority', 'Priority'], fallback: '0')}' : '0');
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
                      labelText: 'Master Type (Domain Discriminator)',
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
                                  'TenantId': auth.tenantId ?? 1,
                                  'masterType': mType,
                                  'MasterType': mType,
                                  'masterName': nameText,
                                  'MasterName': nameText,
                                  'name': nameText,
                                  'Name': nameText,
                                  'masterCode': mCode,
                                  'MasterCode': mCode,
                                  'code': mCode,
                                  'Code': mCode,
                                  'description': descCtrl.text.trim(),
                                  'Description': descCtrl.text.trim(),
                                  'priority': int.tryParse(priorityCtrl.text) ?? 0,
                                  'Priority': int.tryParse(priorityCtrl.text) ?? 0,
                                };

                                final itemId = item != null ? (item['id'] ?? item['ID']) : null;
                                final url = isEdit ? '$baseUrl/masters/$itemId' : '$baseUrl/masters';
                                final res = isEdit
                                    ? await http.put(Uri.parse(url), headers: _getHeaders(), body: jsonEncode(body))
                                    : await http.post(Uri.parse(url), headers: _getHeaders(), body: jsonEncode(body));

                                if (res.statusCode == 200) {
                                  if (mounted) ToastHelper.showSuccess(context, '$tabTitle saved successfully into V_Masters!');
                                  Navigator.pop(modalCtx);
                                  _loadAllMasters();
                                } else {
                                  final err = jsonDecode(res.body);
                                  if (mounted) ToastHelper.showError(context, err['message'] ?? 'Failed to save master record.');
                                  setModalState(() => isSubmitting = false);
                                }
                              } catch (e) {
                                if (mounted) ToastHelper.showError(context, 'Error: ${e.toString()}');
                                setModalState(() => isSubmitting = false);
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
