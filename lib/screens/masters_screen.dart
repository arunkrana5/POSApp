import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
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

  // Master lists
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _uoms = [];
  List<Map<String, dynamic>> _itemTypes = [];
  List<Map<String, dynamic>> _brands = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTabIndex);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() => _searchQuery = '');
      }
    });
    _loadAllMasters();
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
    final token = _getAuthToken();
    return {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _loadAllMasters() async {
    setState(() => _isLoading = true);
    try {
      final baseUrl = ApiConfig.baseUrl;
      final headers = _getHeaders();

      final catRes = await http.get(Uri.parse('$baseUrl/masters/categories'), headers: headers).timeout(const Duration(seconds: 5));
      final uomRes = await http.get(Uri.parse('$baseUrl/masters/uoms'), headers: headers).timeout(const Duration(seconds: 5));
      final typeRes = await http.get(Uri.parse('$baseUrl/masters/item-types'), headers: headers).timeout(const Duration(seconds: 5));
      final brandRes = await http.get(Uri.parse('$baseUrl/masters/brands'), headers: headers).timeout(const Duration(seconds: 5));

      if (mounted) {
        setState(() {
          if (catRes.statusCode == 200) {
            _categories = List<Map<String, dynamic>>.from(jsonDecode(catRes.body));
          }
          if (uomRes.statusCode == 200) {
            _uoms = List<Map<String, dynamic>>.from(jsonDecode(uomRes.body));
          }
          if (typeRes.statusCode == 200) {
            _itemTypes = List<Map<String, dynamic>>.from(jsonDecode(typeRes.body));
          }
          if (brandRes.statusCode == 200) {
            _brands = List<Map<String, dynamic>>.from(jsonDecode(brandRes.body));
          }
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  // Generic Toggle Active State API Call
  Future<void> _toggleActive(String endpoint, int id, bool currentActive) async {
    try {
      final baseUrl = ApiConfig.baseUrl;
      final res = await http.put(Uri.parse('$baseUrl/masters/$endpoint/$id/toggle-active'), headers: _getHeaders());
      if (res.statusCode == 200) {
        ToastHelper.showSuccess(context, 'Status updated successfully.');
        _loadAllMasters();
      } else {
        ToastHelper.showError(context, 'Failed to update status.');
      }
    } catch (e) {
      ToastHelper.showError(context, 'Error updating status: ${e.toString()}');
    }
  }

  // Generic Soft Delete API Call
  Future<void> _softDeleteMaster(String endpoint, int id, String name, bool isHindi) async {
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
        final res = await http.delete(Uri.parse('$baseUrl/masters/$endpoint/$id'), headers: _getHeaders());
        if (res.statusCode == 200) {
          ToastHelper.showSuccess(context, 'Record deleted successfully.');
          _loadAllMasters();
        } else {
          ToastHelper.showError(context, 'Failed to delete record.');
        }
      } catch (e) {
        ToastHelper.showError(context, 'Delete failed: ${e.toString()}');
      }
    }
  }

  // Show Audit Info Dialog
  void _showAuditDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.info_rounded, color: Colors.indigo),
            SizedBox(width: 8),
            Text('Audit & Metadata Info', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _auditRow('Record ID', item['id']?.toString() ?? '-'),
            _auditRow('Is Active', (item['isActive'] ?? true) ? 'Yes (Active)' : 'No (Inactive)'),
            _auditRow('Priority Order', item['priority']?.toString() ?? '0'),
            _auditRow('Created By User ID', item['createdBy']?.toString() ?? '1'),
            _auditRow('Created Date (UTC)', item['createdDate']?.toString().replaceAll('T', ' ') ?? '-'),
            _auditRow('Modified By User ID', item['modifiedBy']?.toString() ?? '1'),
            _auditRow('Modified Date (UTC)', item['modifiedDate']?.toString().replaceAll('T', ' ') ?? '-'),
          ],
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = Provider.of<LocaleProvider>(context).isHindi;
    final themeProvider = Provider.of<TenantThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.pageBgColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(
          isHindi ? 'मास्टर्स प्रबंधन' : 'Master Management Hub',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(icon: const Icon(Icons.category_rounded), text: isHindi ? 'श्रेणी (Category)' : 'Categories'),
            Tab(icon: const Icon(Icons.square_foot_rounded), text: isHindi ? 'इकाई (UOM)' : 'Units (UOM)'),
            Tab(icon: const Icon(Icons.dashboard_customize_rounded), text: isHindi ? 'आइटम प्रकार' : 'Item Types'),
            Tab(icon: const Icon(Icons.branding_watermark_rounded), text: isHindi ? 'ब्रांड्स' : 'Brands'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filter & Search Header Panel
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: themeProvider.cardBgColor, border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: isHindi ? 'मास्टर नाम या कोड खोजें...' : 'Search master by name or code...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(isHindi ? 'केवल सक्रिय' : 'Active Only', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  selected: _activeOnly,
                  onSelected: (val) => setState(() => _activeOnly = val),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: themeProvider.buttonBgColor, foregroundColor: themeProvider.buttonTextColor),
                  icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                  label: Text(isHindi ? 'नया जोड़ें' : 'Add Master', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  onPressed: () => _showAddEditModal(context, _tabController.index, isHindi),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMasterList('categories', _categories, 'CategoryName', isHindi),
                      _buildMasterList('uoms', _uoms, 'UOMName', isHindi),
                      _buildMasterList('item-types', _itemTypes, 'ItemTypeName', isHindi),
                      _buildMasterList('brands', _brands, 'BrandName', isHindi),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasterList(String endpoint, List<Map<String, dynamic>> items, String nameKey, bool isHindi) {
    final filtered = items.where((i) {
      final name = (i[nameKey] ?? '').toString().toLowerCase();
      final code = (i['categoryCode'] ?? i['uomCode'] ?? i['itemTypeCode'] ?? i['brandCode'] ?? '').toString().toLowerCase();
      final matchesSearch = name.contains(_searchQuery.toLowerCase()) || code.contains(_searchQuery.toLowerCase());
      final matchesActive = _activeOnly ? (i['isActive'] == true) : true;
      return matchesSearch && matchesActive;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(isHindi ? 'कोई मास्टर रिकॉर्ड नहीं मिला' : 'No master records found', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: filtered.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 8),
      itemBuilder: (ctx, index) {
        final item = filtered[index];
        final id = (item['id'] as num).toInt();
        final name = (item[nameKey] ?? 'Unnamed').toString();
        final code = (item['categoryCode'] ?? item['uomCode'] ?? item['itemTypeCode'] ?? item['brandCode'] ?? '').toString();
        final desc = (item['description'] ?? '').toString();
        final symbol = (item['symbol'] ?? '').toString();
        final precision = item['decimalPrecision']?.toString() ?? '';
        final isActive = item['isActive'] == true;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isActive ? Colors.grey.shade200 : Colors.red.shade100),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4)],
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isActive ? Colors.indigo.shade50 : Colors.red.shade50,
              child: Text(
                code.isNotEmpty ? code.substring(0, code.length > 2 ? 2 : code.length).toUpperCase() : name.substring(0, 1).toUpperCase(),
                style: TextStyle(fontWeight: FontWeight.bold, color: isActive ? Colors.indigo : Colors.red),
              ),
            ),
            title: Row(
              children: [
                Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isActive ? Colors.black87 : Colors.grey)),
                if (symbol.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                    child: Text('Symbol: $symbol', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                  ),
                ],
                if (precision.isNotEmpty && precision != '0') ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(4)),
                    child: Text('Decimals: $precision', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple)),
                  ),
                ],
              ],
            ),
            subtitle: Text(
              code.isNotEmpty ? 'Code: $code ${desc.isNotEmpty ? "• $desc" : ""}' : (desc.isNotEmpty ? desc : 'No description'),
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: isActive,
                  activeColor: Colors.green,
                  onChanged: (_) => _toggleActive(endpoint, id, isActive),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline_rounded, size: 20, color: Colors.grey),
                  tooltip: 'Audit Details',
                  onPressed: () => _showAuditDialog(item),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 20, color: Colors.blue),
                  tooltip: 'Edit',
                  onPressed: () => _showAddEditModal(context, _tabController.index, isHindi, item),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                  tooltip: 'Delete',
                  onPressed: () => _softDeleteMaster(endpoint, id, name, isHindi),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddEditModal(BuildContext context, int tabIndex, bool isHindi, [Map<String, dynamic>? item]) {
    final isEdit = item != null;
    final nameCtrl = TextEditingController(text: item?['categoryName'] ?? item?['uomName'] ?? item?['itemTypeName'] ?? item?['brandName'] ?? '');
    final codeCtrl = TextEditingController(text: item?['categoryCode'] ?? item?['uomCode'] ?? item?['itemTypeCode'] ?? item?['brandCode'] ?? '');
    final symbolCtrl = TextEditingController(text: item?['symbol'] ?? '');
    final precisionCtrl = TextEditingController(text: (item?['decimalPrecision'] ?? 0).toString());
    final descCtrl = TextEditingController(text: item?['description'] ?? '');
    final priorityCtrl = TextEditingController(text: (item?['priority'] ?? 0).toString());

    String tabTitle;
    String endpoint;
    if (tabIndex == 0) {
      tabTitle = isHindi ? 'श्रेणी (Category)' : 'Item Category';
      endpoint = 'categories';
    } else if (tabIndex == 1) {
      tabTitle = isHindi ? 'इकाई (UOM)' : 'Unit of Measurement';
      endpoint = 'uoms';
    } else if (tabIndex == 2) {
      tabTitle = isHindi ? 'आइटम प्रकार' : 'Item Type';
      endpoint = 'item-types';
    } else {
      tabTitle = isHindi ? 'ब्रांड' : 'Brand';
      endpoint = 'brands';
    }

    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${isEdit ? (isHindi ? "संपादित करें" : "Edit") : (isHindi ? "नया जोड़ें" : "Add New")} $tabTitle',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.indigo),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(modalCtx)),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 10),

                  // Name Input
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: '$tabTitle Name *',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Code Input
                  TextField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Code / Identifier (Optional)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // UOM Specific Fields (Symbol & Decimal Precision)
                  if (tabIndex == 1) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: symbolCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Symbol (e.g. kg, pcs, L)',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: precisionCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Decimal Precision (0-3)',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

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
                        backgroundColor: Colors.indigo,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (nameCtrl.text.trim().isEmpty) {
                                ToastHelper.showError(context, 'Name is required!');
                                return;
                              }

                              setModalState(() => isSubmitting = true);

                              try {
                                final baseUrl = ApiConfig.baseUrl;
                                Map<String, dynamic> body = {};

                                if (tabIndex == 0) {
                                  body = {
                                    'categoryName': nameCtrl.text.trim(),
                                    'categoryCode': codeCtrl.text.trim(),
                                    'description': descCtrl.text.trim(),
                                    'priority': int.tryParse(priorityCtrl.text) ?? 0,
                                  };
                                } else if (tabIndex == 1) {
                                  body = {
                                    'uomName': nameCtrl.text.trim(),
                                    'uomCode': codeCtrl.text.trim(),
                                    'symbol': symbolCtrl.text.trim(),
                                    'decimalPrecision': int.tryParse(precisionCtrl.text) ?? 0,
                                    'description': descCtrl.text.trim(),
                                    'priority': int.tryParse(priorityCtrl.text) ?? 0,
                                  };
                                } else if (tabIndex == 2) {
                                  body = {
                                    'itemTypeName': nameCtrl.text.trim(),
                                    'itemTypeCode': codeCtrl.text.trim(),
                                    'description': descCtrl.text.trim(),
                                    'priority': int.tryParse(priorityCtrl.text) ?? 0,
                                  };
                                } else {
                                  body = {
                                    'brandName': nameCtrl.text.trim(),
                                    'brandCode': codeCtrl.text.trim(),
                                    'description': descCtrl.text.trim(),
                                    'priority': int.tryParse(priorityCtrl.text) ?? 0,
                                  };
                                }

                                final url = isEdit ? '$baseUrl/masters/$endpoint/${item['id']}' : '$baseUrl/masters/$endpoint';
                                final res = isEdit
                                    ? await http.put(Uri.parse(url), headers: _getHeaders(), body: jsonEncode(body))
                                    : await http.post(Uri.parse(url), headers: _getHeaders(), body: jsonEncode(body));

                                if (res.statusCode == 200) {
                                  ToastHelper.showSuccess(context, '$tabTitle saved successfully!');
                                  Navigator.pop(modalCtx);
                                  _loadAllMasters();
                                } else {
                                  final err = jsonDecode(res.body);
                                  ToastHelper.showError(context, err['message'] ?? 'Failed to save master record.');
                                  setModalState(() => isSubmitting = false);
                                }
                              } catch (e) {
                                ToastHelper.showError(context, 'Error: ${e.toString()}');
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
