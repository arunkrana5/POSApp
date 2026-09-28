import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/app_drawer.dart';

class ItemMasterScreen extends StatefulWidget {
  const ItemMasterScreen({super.key});

  @override
  State<ItemMasterScreen> createState() => _ItemMasterScreenState();
}

class _ItemMasterScreenState extends State<ItemMasterScreen> {
  static final List<Map<String, dynamic>> _masterItems = [
    {
      'id': '1',
      'itemCode': 'ITM-1001',
      'name': 'Aashirvaad Atta 5kg',
      'category': 'Groceries',
      'uom': 'pkt',
      'format': 'Packed',
      'description': 'Premium Whole Wheat Atta 5kg bag',
    },
    {
      'id': '2',
      'itemCode': 'ITM-1002',
      'name': 'Fortune Mustard Oil 1L',
      'category': 'Edible Oil',
      'uom': 'bottle',
      'format': 'Packed',
      'description': 'Kachi Ghani Mustard Oil 1L Bottle',
    },
    {
      'id': '3',
      'itemCode': 'ITM-1003',
      'name': 'Tata Salt 1kg',
      'category': 'Groceries',
      'uom': 'pkt',
      'format': 'Packed',
      'description': 'Vacuum Evaporated Iodized Salt 1kg',
    },
    {
      'id': '4',
      'itemCode': 'ITM-1004',
      'name': 'Surf Excel 1kg',
      'category': 'Detergent',
      'uom': 'pkt',
      'format': 'Packed',
      'description': 'Easy Wash Detergent Powder 1kg',
    },
    {
      'id': '5',
      'itemCode': 'ITM-1005',
      'name': 'Loose Sugar (चीनी)',
      'category': 'Groceries',
      'uom': 'kg',
      'format': 'Loose',
      'description': 'Refined Loose White Sugar per kg',
    },
    {
      'id': '6',
      'itemCode': 'ITM-1006',
      'name': 'Toor Dal (अरहर दाल)',
      'category': 'Groceries',
      'uom': 'kg',
      'format': 'Loose',
      'description': 'Unpolished Pure Toor Dal per kg',
    },
  ];

  String _searchQuery = '';

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
          isHindi ? 'सामान मास्टर (Item Master)' : 'Item Master Catalog',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Banner Notice Explaining Item Master Architecture
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.blue, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isHindi
                        ? 'नोट: आइटम मास्टर में केवल मूल विवरण (नाम, कोड, UOM, कैटेगरी) सुरक्षित होते हैं। रेट, टैक्स और स्टॉक जानकारी Stock In मेनू में दर्ज होती है।'
                        : 'Note: Item Master holds core definitions (Code, Name, UOM, Category). Pricing, Tax, Barcode & Stock entry are managed under Stock In.',
                    style: TextStyle(fontSize: 11.5, color: Colors.blue.shade900, fontWeight: FontWeight.w600),
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

          // Master Items Catalog List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: filteredMaster.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 8),
              itemBuilder: (ctx, index) {
                final item = filteredMaster[index];
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
                          color: isLoose ? Colors.orange.shade50 : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isLoose ? Colors.orange.shade200 : Colors.blue.shade200),
                        ),
                        child: Icon(
                          isLoose ? Icons.scale_rounded : Icons.inventory_2_rounded,
                          color: isLoose ? Colors.orange.shade800 : Colors.blue.shade800,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  item['itemCode'] ?? 'ITM-000',
                                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.blue),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isLoose ? Colors.orange.shade100 : Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isLoose ? 'Loose Bulk' : 'Packed',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isLoose ? Colors.orange.shade900 : Colors.blue.shade900),
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
                        icon: const Icon(Icons.edit_note_rounded, color: Colors.blue),
                        onPressed: () => _showAddMasterItemModal(context, isHindi, item),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddMasterItemModal(BuildContext context, bool isHindi, [Map<String, dynamic>? existing]) {
    final themeProvider = Provider.of<TenantThemeProvider>(context, listen: false);
    final codeCtrl = TextEditingController(text: existing?['itemCode'] ?? 'ITM-${1000 + Random().nextInt(8999)}');
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final descCtrl = TextEditingController(text: existing?['description'] ?? '');
    String selectedCategory = existing?['category'] ?? 'Groceries';
    String selectedUOM = existing?['uom'] ?? 'pkt';
    String selectedFormat = existing?['format'] ?? 'Packed';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
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
                          ? (isHindi ? 'मास्टर आइटम एडिट करें' : 'Edit Master Item')
                          : (isHindi ? 'नया मास्टर आइटम (Define Item)' : 'Create New Master Item'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.red),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
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
                      flex: 3,
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
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedCategory,
                        decoration: InputDecoration(
                          labelText: isHindi ? 'कैटेगरी' : 'Category',
                          border: const OutlineInputBorder(),
                        ),
                        items: ['Groceries', 'Edible Oil', 'Detergent', 'Spices', 'Beverages', 'Dairy', 'Grains', 'General']
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) => setModalState(() => selectedCategory = v ?? 'Groceries'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedUOM,
                        decoration: InputDecoration(
                          labelText: isHindi ? 'UOM (यूनिट)' : 'UOM (Unit)',
                          border: const OutlineInputBorder(),
                        ),
                        items: ['pkt', 'pcs', 'bottle', 'box', 'bag', 'kg', 'gm', 'ltr', 'ml']
                            .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                            .toList(),
                        onChanged: (v) => setModalState(() => selectedUOM = v ?? 'pkt'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Format Switch (Packed vs Loose)
                Row(
                  children: [
                    const Text('Format / Type: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Packed Item'),
                      selected: selectedFormat == 'Packed',
                      selectedColor: Colors.blue.shade700,
                      labelStyle: TextStyle(color: selectedFormat == 'Packed' ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                      onSelected: (sel) {
                        if (sel) {
                          setModalState(() {
                            selectedFormat = 'Packed';
                            if (['kg', 'ltr', 'gm', 'ml'].contains(selectedUOM)) selectedUOM = 'pkt';
                          });
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Loose Bulk (Weight)'),
                      selected: selectedFormat == 'Loose',
                      selectedColor: Colors.orange.shade800,
                      labelStyle: TextStyle(color: selectedFormat == 'Loose' ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                      onSelected: (sel) {
                        if (sel) {
                          setModalState(() {
                            selectedFormat = 'Loose';
                            selectedUOM = 'kg';
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: isHindi ? 'विवरण / डिस्क्रिप्शन' : 'Item Description / Specifications',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeProvider.buttonBgColor,
                      foregroundColor: themeProvider.buttonTextColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      if (nameCtrl.text.isNotEmpty) {
                        setState(() {
                          if (existing != null) {
                            existing['itemCode'] = codeCtrl.text;
                            existing['name'] = nameCtrl.text;
                            existing['category'] = selectedCategory;
                            existing['uom'] = selectedUOM;
                            existing['format'] = selectedFormat;
                            existing['description'] = descCtrl.text;
                          } else {
                            _masterItems.insert(0, {
                              'id': '${_masterItems.length + 1}',
                              'itemCode': codeCtrl.text,
                              'name': nameCtrl.text,
                              'category': selectedCategory,
                              'uom': selectedUOM,
                              'format': selectedFormat,
                              'description': descCtrl.text,
                            });
                          }
                        });
                        Navigator.pop(ctx);
                      }
                    },
                    child: Text(
                      existing != null ? (isHindi ? 'अपडेट करें' : 'Update Item') : (isHindi ? 'मास्टर में सेव करें' : 'Save to Item Master'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
