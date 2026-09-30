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

class ItemsScreen extends StatefulWidget {
  final bool autoOpenAddModal;
  const ItemsScreen({super.key, this.autoOpenAddModal = false});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  final List<Map<String, dynamic>> _masterItems = [];

  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchItems();
    if (widget.autoOpenAddModal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final isHindi = Provider.of<LocaleProvider>(context, listen: false).isHindi;
          _showAddMasterItemModal(context, isHindi);
        }
      });
    }
  }

  Future<void> _fetchItems() async {
    setState(() => _isLoading = true);
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

      final qStr = tenantId > 0 ? '?tenantId=$tenantId' : '';
      final url = Uri.parse('${ApiConfig.baseUrl}/Items$qStr');
      final res = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        _masterItems.clear();
        if (data.isNotEmpty) {
          setState(() {
            for (var item in data) {
              _masterItems.add({
                'id': (item['id'] ?? item['ID'] ?? '').toString(),
                'itemCode': item['itemCode'] ?? item['ItemCode'] ?? '',
                'name': item['name'] ?? item['Name'] ?? '',
                'category': item['category'] ?? item['Category'] ?? 'Groceries',
                'uom': item['unit'] ?? item['Unit'] ?? 'pcs',
                'format': (item['format'] ?? item['Format'] ?? 'Packed') == 'Loose' ? 'Loose' : 'Packed',
                'description': item['description'] ?? item['Description'] ?? '',
              });
            }
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = Provider.of<LocaleProvider>(context).isHindi;
    final themeProvider = Provider.of<TenantThemeProvider>(context);

    final filteredMaster = _masterItems
        .where((item) =>
            item['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
            item['itemCode'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (item['category'] != null && item['category'].toString().toLowerCase().contains(_searchQuery.toLowerCase())))
        .toList();

    return Scaffold(
      backgroundColor: themeProvider.pageBgColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(
          isHindi ? 'सामान (Items)' : 'Items Catalog',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchItems,
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
          // Banner Notice Explaining Items Architecture
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: themeProvider.primaryColor.withOpacity(0.08),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: themeProvider.primaryColor, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isHindi
                        ? 'नोट: सामान (Items) में केवल मूल विवरण (नाम, कोड, UOM, कैटेगरी) सुरक्षित होते हैं। रेट, टैक्स और स्टॉक जानकारी Stock In मेनू में दर्ज होती है।'
                        : 'Note: Items hold core definitions (Code, Name, UOM, Category). Pricing, Tax, Barcode & Stock entry are managed under Stock In.',
                    style: TextStyle(fontSize: 11.5, color: themeProvider.textColor, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          // Search & Add Header
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: isHindi ? 'कोड, नाम, कैटेगरी खोजें...' : 'Search Item Code, Name, Category...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeProvider.buttonBgColor,
                    foregroundColor: themeProvider.buttonTextColor,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  icon: Icon(Icons.add_box_rounded, color: themeProvider.buttonTextColor),
                  label: Text(
                    isHindi ? '+ नया आइटम' : '+ Add Item',
                    style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.buttonTextColor),
                  ),
                  onPressed: () => _showAddMasterItemModal(context, isHindi),
                ),
              ],
            ),
          ),

          if (_isLoading)
            const LinearProgressIndicator(),

          // Master Items Catalog List
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
                    ),
                    padding: const EdgeInsets.all(12),
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
                                    style: TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: themeProvider.primaryColor),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isLoose ? Colors.orange.shade100 : themeProvider.primaryColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isLoose ? 'Loose Bulk' : 'Packed',
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isLoose ? Colors.orange.shade900 : themeProvider.primaryColor),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item['name'] ?? '',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Category: ${item['category']} | UOM: ${item['uom']}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                              if (item['description'] != null && item['description'].toString().isNotEmpty)
                                Text(
                                  item['description'],
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.edit_note_rounded, color: themeProvider.primaryColor),
                          onPressed: () => _showAddMasterItemModal(context, isHindi, item),
                        ),
                      ],
                    ),
                  );
                }

                if (isDesktop) {
                  return GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      mainAxisExtent: 96,
                    ),
                    itemCount: filteredMaster.length,
                    itemBuilder: (ctx, index) => buildItemCard(filteredMaster[index]),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: filteredMaster.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                  itemBuilder: (ctx, index) => buildItemCard(filteredMaster[index]),
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

    String categoryVal = existing?['category'] ?? 'Groceries';
    String uomVal = existing?['uom'] ?? 'pkt';
    String formatVal = existing?['format'] ?? 'Packed';

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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          existing != null
                              ? (isHindi ? 'सामान अपडेट करें' : 'Edit Item')
                              : (isHindi ? 'नया सामान जोड़ें' : 'Define New Item'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Format Toggle (Packed vs Loose Bulk)
                    Text(
                      isHindi ? 'सामान का प्रकार (Type/Format)' : 'Item Packaging Format',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            avatar: const Icon(Icons.inventory_2_rounded, size: 16),
                            label: Text(isHindi ? 'पैक्ड सामान (Packed)' : 'Packed Item'),
                            selected: formatVal == 'Packed',
                            selectedColor: Colors.blue.shade100,
                            onSelected: (sel) {
                              if (sel) setModalState(() => formatVal = 'Packed');
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ChoiceChip(
                            avatar: const Icon(Icons.scale_rounded, size: 16),
                            label: Text(isHindi ? 'खुला सामान (Loose)' : 'Loose Bulk'),
                            selected: formatVal == 'Loose',
                            selectedColor: Colors.orange.shade100,
                            onSelected: (sel) {
                              if (sel) setModalState(() => formatVal = 'Loose');
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Item Code & Name
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: codeCtrl,
                            decoration: InputDecoration(
                              labelText: isHindi ? 'आइटम कोड' : 'Item Code',
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

                    // Category & UOM Dropdowns
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: categoryVal,
                            decoration: InputDecoration(
                              labelText: isHindi ? 'कैटेगरी' : 'Category',
                              border: const OutlineInputBorder(),
                            ),
                            items: ['Groceries', 'Edible Oil', 'Detergent', 'Spices', 'Beverages', 'Dairy', 'Grains', 'General']
                                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setModalState(() => categoryVal = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: uomVal,
                            decoration: InputDecoration(
                              labelText: isHindi ? 'UOM (इकाई)' : 'UOM (Unit)',
                              border: const OutlineInputBorder(),
                            ),
                            items: ['pkt', 'bottle', 'kg', 'gm', 'ltr', 'pcs', 'box']
                                .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setModalState(() => uomVal = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Description / Notes
                    TextField(
                      controller: descCtrl,
                      decoration: InputDecoration(
                        labelText: isHindi ? 'विवरण / विवरण टिप्पणी' : 'Description / Notes',
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
                        onPressed: () async {
                          if (nameCtrl.text.trim().isEmpty) return;

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
                            'itemCode': codeCtrl.text.trim(),
                            'name': nameCtrl.text.trim(),
                            'category': categoryVal,
                            'unit': uomVal,
                            'format': formatVal,
                            'description': descCtrl.text.trim(),
                            'tenantId': tenantId > 0 ? tenantId : 1,
                          };

                          if (existing != null) {
                            try {
                              await http.put(
                                Uri.parse('${ApiConfig.baseUrl}/Items/${existing['id']}'),
                                headers: headers,
                                body: jsonEncode({...payload, 'id': int.tryParse(existing['id']) ?? 0}),
                              );
                            } catch (_) {}
                          } else {
                            try {
                              await http.post(
                                Uri.parse('${ApiConfig.baseUrl}/Items'),
                                headers: headers,
                                body: jsonEncode(payload),
                              );
                            } catch (_) {}
                          }

                          await _fetchItems();

                          if (modalCtx.mounted) Navigator.pop(modalCtx);
                        },
                        child: Text(
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
