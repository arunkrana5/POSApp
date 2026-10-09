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

  // Generic Master Lists stored per MasterType
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

      final res = await http.get(Uri.parse('$baseUrl/masters'), headers: headers).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200 && mounted) {
        final List<dynamic> raw = jsonDecode(res.body);
        final allMasters = List<Map<String, dynamic>>.from(raw);

        setState(() {
          _categories = allMasters.where((m) => (m['masterType'] ?? '').toString().toLowerCase() == 'itemcategory').toList();
          _uoms = allMasters.where((m) => (m['masterType'] ?? '').toString().toLowerCase() == 'unitofmeasurement').toList();
          _itemTypes = allMasters.where((m) => (m['masterType'] ?? '').toString().toLowerCase() == 'itemtype').toList();
          _brands = allMasters.where((m) => (m['masterType'] ?? '').toString().toLowerCase() == 'brand').toList();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  // Generic Toggle Active State API Call targeting V_Masters ID
  Future<void> _toggleActive(int id, bool currentActive) async {
    try {
      final baseUrl = ApiConfig.baseUrl;
      final res = await http.put(Uri.parse('$baseUrl/masters/$id/toggle-active'), headers: _getHeaders());
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

  void _showAuditDialog(Map<String, dynamic> item, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.indigo),
            const SizedBox(width: 8),
            Expanded(child: Text('$title Audit Info', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _auditRow('ID:', '${item['id']}'),
              _auditRow('Master Type:', '${item['masterType'] ?? 'N/A'}'),
              _auditRow('Name:', '${item['masterName'] ?? item['categoryName'] ?? item['uomName'] ?? item['itemTypeName'] ?? item['brandName'] ?? ''}'),
              _auditRow('Code:', '${item['masterCode'] ?? item['categoryCode'] ?? item['uomCode'] ?? item['itemTypeCode'] ?? item['brandCode'] ?? ''}'),
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

  @override
  Widget build(BuildContext context) {
    final isHindi = Provider.of<LocaleProvider>(context).isHindi;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(isHindi ? 'मास्टर प्रबंधन (Master Table)' : 'Master Management (Single V_Masters)'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: isHindi ? 'ताज़ा करें' : 'Refresh Masters',
            onPressed: _loadAllMasters,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(icon: const Icon(Icons.category), text: isHindi ? 'श्रेणियां' : 'Categories'),
            Tab(icon: const Icon(Icons.square_foot), text: isHindi ? 'मापक इकाइयाँ' : 'UOMs'),
            Tab(icon: const Icon(Icons.merge_type), text: isHindi ? 'प्रकार' : 'Item Types'),
            Tab(icon: const Icon(Icons.branding_watermark), text: isHindi ? 'ब्रांड्स' : 'Brands'),
          ],
        ),
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          // Filter & Search Header
          Container(
            padding: const EdgeInsets.all(12),
            color: isDark ? Colors.grey.shade900 : Colors.indigo.shade50,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: isHindi ? 'खोजें (नाम, कोड)...' : 'Search master records...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      fillColor: isDark ? Colors.grey.shade800 : Colors.white,
                      filled: true,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                  ),
                ),
                const SizedBox(width: 12),
                FilterChip(
                  label: Text(isHindi ? 'सक्रिय' : 'Active Only'),
                  selected: _activeOnly,
                  onSelected: (val) => setState(() => _activeOnly = val),
                  selectedColor: Colors.indigo.shade100,
                  checkmarkColor: Colors.indigo,
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
                      _buildMasterList(_categories, 'ItemCategory', isHindi, isDark),
                      _buildMasterList(_uoms, 'UnitOfMeasurement', isHindi, isDark),
                      _buildMasterList(_itemTypes, 'ItemType', isHindi, isDark),
                      _buildMasterList(_brands, 'Brand', isHindi, isDark),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(isHindi ? 'नया मास्टर जोड़ें' : 'Add Master'),
        onPressed: () => _showMasterFormModal(context, null),
      ),
    );
  }

  String _resolveMasterName(Map<String, dynamic> item) {
    final keys = ['masterName', 'MasterName', 'name', 'Name', 'categoryName', 'CategoryName', 'uomName', 'UOMName', 'itemTypeName', 'ItemTypeName', 'brandName', 'BrandName'];
    for (var k in keys) {
      if (item[k] != null && item[k].toString().trim().isNotEmpty) {
        return item[k].toString().trim();
      }
    }
    final id = item['id'] ?? item['ID'] ?? '';
    return 'Master Record #$id';
  }

  String _resolveMasterCode(Map<String, dynamic> item) {
    final keys = ['masterCode', 'MasterCode', 'code', 'Code', 'categoryCode', 'CategoryCode', 'uomCode', 'UOMCode', 'symbol', 'Symbol', 'itemTypeCode', 'ItemTypeCode', 'brandCode', 'BrandCode'];
    for (var k in keys) {
      if (item[k] != null && item[k].toString().trim().isNotEmpty) {
        return item[k].toString().trim();
      }
    }
    return '';
  }

  Widget _buildMasterList(List<Map<String, dynamic>> rawList, String masterType, bool isHindi, bool isDark) {
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              isHindi ? 'कोई रिकॉर्ड नहीं मिला' : 'No master records found',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
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
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            color: isDark ? Colors.grey.shade800 : Colors.white,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: CircleAvatar(
                backgroundColor: isActive ? Colors.green.shade100 : Colors.red.shade100,
                child: Icon(
                  isActive ? Icons.check_circle : Icons.pause_circle_filled,
                  color: isActive ? Colors.green.shade800 : Colors.red.shade800,
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        decoration: isActive ? TextDecoration.none : TextDecoration.lineThrough,
                        color: isActive ? null : Colors.grey,
                      ),
                    ),
                  ),
                  if (code.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.indigo.shade200),
                      ),
                      child: Text(code, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo.shade800)),
                    ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                        child: Text('Type: $masterType', style: const TextStyle(fontSize: 10, color: Colors.black87, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Text('Priority: $priority', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.info_outline, color: Colors.blue),
                    tooltip: 'Audit Info',
                    onPressed: () => _showAuditDialog(item, name),
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
                        child: Row(children: [const Icon(Icons.edit, size: 18, color: Colors.indigo), const SizedBox(width: 8), Text(isHindi ? 'संपादित करें' : 'Edit')]),
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
    final isHindi = Provider.of<LocaleProvider>(context, listen: false).isHindi;
    final isEdit = item != null;

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
    }

    final nameCtrl = TextEditingController(text: item != null ? (item['masterName'] ?? item['categoryName'] ?? item['uomName'] ?? item['itemTypeName'] ?? item['brandName'] ?? '') : '');
    final codeCtrl = TextEditingController(text: item != null ? (item['masterCode'] ?? item['categoryCode'] ?? item['uomCode'] ?? item['itemTypeCode'] ?? item['brandCode'] ?? '') : '');
    final descCtrl = TextEditingController(text: item != null ? (item['description'] ?? '') : '');
    final priorityCtrl = TextEditingController(text: item != null ? '${item['priority'] ?? 0}' : '0');
    final typeCtrl = TextEditingController(text: item != null ? (item['masterType'] ?? currentMasterType) : currentMasterType);

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
                      Icon(isEdit ? Icons.edit : Icons.add_circle, color: Colors.indigo, size: 28),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isEdit
                              ? (isHindi ? '$tabTitle संपादित करें (V_Masters)' : 'Edit $tabTitle (Single V_Masters)')
                              : (isHindi ? 'नया $tabTitle जोड़ें (V_Masters)' : 'Add New $tabTitle (Single V_Masters)'),
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
                      labelText: 'Master Type (Domain Name)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Name Field
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: '$tabTitle Name *',
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
                        backgroundColor: Colors.indigo,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (nameCtrl.text.trim().isEmpty) {
                                ToastHelper.showError(context, 'Master Name is required!');
                                return;
                              }

                              setModalState(() => isSubmitting = true);

                              try {
                                final baseUrl = ApiConfig.baseUrl;
                                Map<String, dynamic> body = {
                                  'masterType': typeCtrl.text.trim().isEmpty ? currentMasterType : typeCtrl.text.trim(),
                                  'masterName': nameCtrl.text.trim(),
                                  'masterCode': codeCtrl.text.trim(),
                                  'description': descCtrl.text.trim(),
                                  'priority': int.tryParse(priorityCtrl.text) ?? 0,
                                };

                                final url = isEdit ? '$baseUrl/masters/${item['id']}' : '$baseUrl/masters';
                                final res = isEdit
                                    ? await http.put(Uri.parse(url), headers: _getHeaders(), body: jsonEncode(body))
                                    : await http.post(Uri.parse(url), headers: _getHeaders(), body: jsonEncode(body));

                                if (res.statusCode == 200) {
                                  ToastHelper.showSuccess(context, '$tabTitle saved successfully into V_Masters!');
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
