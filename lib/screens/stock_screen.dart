import 'dart:convert';
import 'dart:html' as html;
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../providers/locale_provider.dart';
import '../providers/sync_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/app_drawer.dart';

Widget buildProductThumbnail(String imgUrl, {double size = 40}) {
  if (imgUrl.startsWith('data:image/')) {
    try {
      final parts = imgUrl.split(',');
      if (parts.length > 1) {
        final bytes = base64Decode(parts[1]);
        return Image.memory(bytes, width: size, height: size, fit: BoxFit.cover);
      }
    } catch (_) {}
  } else if (imgUrl.startsWith('http')) {
    return Image.network(
      imgUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Icon(Icons.inventory_2_rounded, size: size * 0.6, color: Colors.blue),
    );
  }
  return Icon(Icons.inventory_2_rounded, size: size * 0.6, color: Colors.blue);
}

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _availableItems = [];
  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/Items');
      final res = await http.get(url).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        final List<Map<String, dynamic>> fetched = [];
        if (data.isNotEmpty) {
          for (var item in data) {
            fetched.add({
              'id': (item['id'] ?? item['ID'] ?? '').toString(),
              'itemCode': item['itemCode'] ?? item['ItemCode'] ?? '',
              'name': item['name'] ?? item['Name'] ?? '',
              'category': item['category'] ?? item['Category'] ?? 'Groceries',
              'uom': item['unit'] ?? item['Unit'] ?? 'pcs',
              'format': (item['format'] ?? item['Format'] ?? 'Packed') == 'Loose' ? 'Loose' : 'Packed',
              'description': item['description'] ?? item['Description'] ?? '',
            });
          }
        }
        setState(() {
          _availableItems = fetched;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);
      final fetchedProducts = await syncProvider.fetchProducts();

      final List<Map<String, dynamic>> loadedList = fetchedProducts.map((p) => {
        'id': p.id.toString(),
        'itemId': p.itemId?.toString() ?? '',
        'productCode': p.productCode,
        'name': p.name,
        'category': p.category.isNotEmpty ? p.category : 'General',
        'brand': p.brand,
        'price': p.sellingPrice > 0 ? p.sellingPrice : p.mrp,
        'mrp': p.mrp,
        'purchasePrice': p.purchasePrice,
        'gstPercent': p.gstPercent,
        'stock': p.currentStock.toInt(),
        'minimumStock': p.minimumStock.toInt(),
        'unit': p.unit.isNotEmpty ? p.unit : 'pcs',
        'batchNumber': p.batchNumber,
        'rackNumber': p.rackNumber,
        'expiryDate': p.expiryDate,
        'hsnCode': p.hsnCode,
        'barcode': p.barcode.isNotEmpty ? p.barcode : '890${(100000000 + Random().nextInt(899999999))}',
        'imageUrl': p.imageUrl ?? '',
      }).toList();

      setState(() {
        _products = loadedList;
      });
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<String?> _pickAndCompressProductImage() async {
    if (kIsWeb) {
      final uploadInput = html.FileUploadInputElement();
      uploadInput.accept = 'image/*';
      uploadInput.click();

      await uploadInput.onChange.first;
      if (uploadInput.files?.isNotEmpty == true) {
        final file = uploadInput.files!.first;
        final reader = html.FileReader();
        reader.readAsDataUrl(file);
        await reader.onLoadEnd.first;
        final String dataUrl = reader.result as String;

        final img = html.ImageElement();
        img.src = dataUrl;
        await img.onLoad.first;

        final canvas = html.CanvasElement(width: 160, height: 160);
        final ctx = canvas.context2D;
        ctx.drawImageScaled(img, 0, 0, 160, 160);
        final compressedDataUrl = canvas.toDataUrl('image/jpeg', 0.6);
        return compressedDataUrl;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = Provider.of<LocaleProvider>(context).isHindi;
    final filtered = _products
        .where((p) =>
            p['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (p['category'] != null && p['category'].toString().toLowerCase().contains(_searchQuery.toLowerCase())) ||
            (p['barcode'] != null && p['barcode'].toString().toLowerCase().contains(_searchQuery.toLowerCase())))
        .toList();

    final themeProvider = Provider.of<TenantThemeProvider>(context);
    return Scaffold(
      backgroundColor: themeProvider.pageBgColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(
          isHindi ? 'स्टॉक इन (Stock In)' : 'Stock In & Inventory',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Search & Add Header
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: isHindi ? 'स्टॉक सामान, बारकोड खोजें...' : 'Search stock item, barcode...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    onChanged: (val) {
                      setState(() => _searchQuery = val);
                    },
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
                    isHindi ? '+ स्टॉक इन' : '+ Stock In',
                    style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.buttonTextColor),
                  ),
                  onPressed: () => _showAddProductModal(context, isHindi),
                ),
              ],
            ),
          ),

          // Stock Items List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: filtered.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                    itemBuilder: (ctx, index) {
                      final item = filtered[index];
                      final stock = (item['stock'] is num) ? (item['stock'] as num).toInt() : 0;
                      final isLowStock = stock > 0 && stock <= 5;
                      final isOutOfStock = stock <= 0;
                      final imgUrl = item['imageUrl']?.toString() ?? '';

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
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isOutOfStock
                                    ? Colors.red.shade50
                                    : (isLowStock ? Colors.orange.shade50 : Colors.blue.shade50),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: buildProductThumbnail(imgUrl, size: 48),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['name'] ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Category: ${item["category"]} • Rate: ₹${item["price"]}/${item["unit"] ?? "pcs"}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                                  ),
                                  if (item['barcode'] != null && item['barcode'].toString().isNotEmpty)
                                    Text(
                                      'Barcode: ${item['barcode']}',
                                      style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.purple, fontWeight: FontWeight.bold),
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isOutOfStock
                                        ? Colors.red.shade100
                                        : (isLowStock ? Colors.orange.shade100 : Colors.green.shade100),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isOutOfStock ? 'OUT OF STOCK' : 'Stock: $stock ${item["unit"] ?? ""}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isOutOfStock
                                          ? Colors.red.shade900
                                          : (isLowStock ? Colors.orange.shade900 : Colors.green.shade900),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₹ ${item["price"]}',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.black87),
                                ),
                              ],
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

  Future<Map<String, dynamic>?> _showQuickCreateItemDialog(BuildContext context, bool isHindi) async {
    final codeCtrl = TextEditingController(text: 'ITM-${1000 + Random().nextInt(8999)}');
    final nameCtrl = TextEditingController();
    final catCtrl = TextEditingController(text: 'Groceries');
    final uomCtrl = TextEditingController(text: 'pcs');
    String selectedFormat = 'Packed';

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dlgCtx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                isHindi ? 'नया सामान Catalog में जोड़ें' : '+ Create New Catalog Item',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: codeCtrl,
                      decoration: InputDecoration(
                        labelText: isHindi ? 'सामान कोड (Item Code)' : 'Item Code',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: isHindi ? 'सामान का नाम (Item Name) *' : 'Item Name *',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: catCtrl,
                      decoration: InputDecoration(
                        labelText: isHindi ? 'कैटेगरी (Category)' : 'Category',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: uomCtrl,
                      decoration: InputDecoration(
                        labelText: isHindi ? 'माप इकाई (UOM / Unit)' : 'Unit (e.g. kg, pkt, bottle, pcs)',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedFormat,
                      decoration: InputDecoration(
                        labelText: isHindi ? 'पैकिंग का प्रकार (Format)' : 'Format',
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Packed', child: Text('Packed Item (पैक्ड सामान)')),
                        DropdownMenuItem(value: 'Loose', child: Text('Loose / Adjustable Item (खुला सामान)')),
                      ],
                      onChanged: (v) => setDlgState(() => selectedFormat = v ?? 'Packed'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dlgCtx, null),
                  child: Text(isHindi ? 'रद्द करें' : 'Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    final payload = {
                      'itemCode': codeCtrl.text.trim(),
                      'name': nameCtrl.text.trim(),
                      'category': catCtrl.text.trim(),
                      'unit': uomCtrl.text.trim(),
                      'format': selectedFormat,
                      'description': 'Created via Quick Add in Stock In',
                    };
                    String createdId = Random().nextInt(10000).toString();
                    try {
                      final res = await http.post(
                        Uri.parse('${ApiConfig.baseUrl}/Items'),
                        headers: {'Content-Type': 'application/json'},
                        body: jsonEncode(payload),
                      );
                      if (res.statusCode == 200 || res.statusCode == 201) {
                        final data = jsonDecode(res.body);
                        createdId = (data['id'] ?? data['ID'] ?? createdId).toString();
                      }
                    } catch (_) {}

                    if (context.mounted) {
                      Navigator.pop(dlgCtx, {
                        'id': createdId,
                        'itemCode': payload['itemCode'],
                        'name': payload['name'],
                        'category': payload['category'],
                        'uom': payload['unit'],
                        'format': payload['format'],
                        'description': payload['description'],
                      });
                    }
                  },
                  child: Text(isHindi ? 'सेव करें' : 'Save & Select'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddProductModal(BuildContext context, bool isHindi) {
    final themeProvider = Provider.of<TenantThemeProvider>(context, listen: false);

    Map<String, dynamic>? selectedItemObj;
    String? uploadedCompressedPhotoUrl;

    final priceCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final mrpCtrl = TextEditingController();
    final gstCtrl = TextEditingController(text: '0');
    final stockCtrl = TextEditingController(text: '10');
    final minStockCtrl = TextEditingController(text: '5');
    final barcodeCtrl = TextEditingController(text: '890${100000000 + Random().nextInt(899999999)}');
    final hsnCtrl = TextEditingController();

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
                          isHindi ? 'स्टॉक इन एंट्री (Stock In)' : 'Stock In Inventory Entry',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.red),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 6),

                    // STEP 1: Select Item Dropdown at the Top
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade300, width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.inventory_2_rounded, color: Colors.blue, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    isHindi ? '1. सामान चुनें (Select Item) *' : '1. Select Item from Directory *',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue),
                                  ),
                                ],
                              ),
                              InkWell(
                                onTap: () async {
                                  final newItem = await _showQuickCreateItemDialog(context, isHindi);
                                  if (newItem != null) {
                                    setModalState(() {
                                      _availableItems.insert(0, newItem);
                                      selectedItemObj = newItem;
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade700,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.add, color: Colors.white, size: 15),
                                      const SizedBox(width: 2),
                                      Text(
                                        isHindi ? '+ नया सामान' : '+ New Item',
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_availableItems.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      isHindi
                                          ? 'Catalog में कोई सामान नहीं मिला। ऊपर "+ नया सामान" बटन दबाकर जोड़ें!'
                                          : 'No items in catalog. Click "+ New Item" above to create one!',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: (selectedItemObj != null && _availableItems.any((i) => i['id'].toString() == selectedItemObj!['id'].toString()))
                                  ? selectedItemObj!['id'].toString()
                                  : null,
                              hint: Text(isHindi ? '-- सामान चुनें --' : '-- Choose Item from Catalog --'),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              items: _availableItems.map((item) {
                                return DropdownMenuItem<String>(
                                  value: item['id'].toString(),
                                  child: Text(
                                    '${item['name']} (${item['category']} • ${item['uom']})',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  final found = _availableItems.firstWhere((i) => i['id'].toString() == val, orElse: () => {});
                                  if (found.isNotEmpty) {
                                    setModalState(() {
                                      selectedItemObj = found;
                                    });
                                  }
                                }
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // STEP 2: Display Read-Only Item Metadata or Prompt Warning
                    if (selectedItemObj == null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                isHindi
                                    ? 'कृपया ऊपर दिए गए ड्रॉपडाउन से सामान चुनें ताकि स्टॉक इन जानकारी दर्ज की जा सके।'
                                    : 'Please select an Item from the dropdown above to proceed with Stock In entry.',
                                style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      // Disabled / Read-Only Preview Card of Selected Item
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Selected Item Details (Read-Only)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(selectedItemObj!['name'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
                                Chip(
                                  label: Text(selectedItemObj!['format'] == 'Loose' ? 'LOOSE BULK' : 'PACKED', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                  backgroundColor: selectedItemObj!['format'] == 'Loose' ? Colors.orange.shade100 : Colors.blue.shade100,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                            Text(
                              'Item Code: ${selectedItemObj!['itemCode']}  •  Category: ${selectedItemObj!['category']}  •  UOM: ${selectedItemObj!['uom']}',
                              style: const TextStyle(fontSize: 11.5, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Commercial Inputs (Price, Cost, MRP, GST)
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: priceCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: isHindi ? 'बिक्री मूल्य (₹) *' : 'Selling Price (₹) *',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: costCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: isHindi ? 'खरीद मूल्य (₹)' : 'Purchase Cost (₹)',
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
                            child: TextField(
                              controller: mrpCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: isHindi ? 'MRP (₹)' : 'MRP (₹)',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: gstCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: isHindi ? 'GST %' : 'GST %',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Inventory Inputs (Stock Qty, Min Stock)
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: stockCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: isHindi ? 'स्टॉक मात्रा *' : 'Stock Qty *',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: minStockCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: isHindi ? 'न्यूनतम अलर्ट स्टॉक' : 'Min Stock Alert',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Barcode & HSN Code
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: barcodeCtrl,
                              decoration: InputDecoration(
                                labelText: isHindi ? 'बारकोड नंबर' : 'Barcode',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: hsnCtrl,
                              decoration: InputDecoration(
                                labelText: isHindi ? 'HSN कोड' : 'HSN Code',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Image Upload Button (Photo Upload with Compression < 20 KB)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Product Photo Upload (Auto-Compressed < 20 KB)',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (uploadedCompressedPhotoUrl != null && uploadedCompressedPhotoUrl!.isNotEmpty)
                                  Container(
                                    width: 54,
                                    height: 54,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.green, width: 2),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: buildProductThumbnail(uploadedCompressedPhotoUrl!, size: 54),
                                  )
                                else
                                  Container(
                                    width: 54,
                                    height: 54,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: const Icon(Icons.add_a_photo_rounded, color: Colors.grey),
                                  ),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.camera_alt_rounded),
                                    label: Text(
                                      uploadedCompressedPhotoUrl != null ? 'Change Photo (<20 KB)' : '📷 Upload Product Photo',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: () async {
                                      final base64Photo = await _pickAndCompressProductImage();
                                      if (base64Photo != null) {
                                        setModalState(() {
                                          uploadedCompressedPhotoUrl = base64Photo;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeProvider.buttonBgColor,
                            foregroundColor: themeProvider.buttonTextColor,
                          ),
                          onPressed: () async {
                            final double price = double.tryParse(priceCtrl.text) ?? 0.0;
                            final double stock = double.tryParse(stockCtrl.text) ?? 0.0;
                            if (price <= 0 || selectedItemObj == null) return;

                            final payload = {
                              'itemId': int.tryParse(selectedItemObj!['id'].toString()) ?? 0,
                              'productCode': selectedItemObj!['itemCode'],
                              'name': selectedItemObj!['name'],
                              'category': selectedItemObj!['category'],
                              'unit': selectedItemObj!['uom'],
                              'sellingPrice': price,
                              'purchasePrice': double.tryParse(costCtrl.text) ?? 0.0,
                              'mrp': double.tryParse(mrpCtrl.text) ?? price,
                              'gstPercent': double.tryParse(gstCtrl.text) ?? 0.0,
                              'currentStock': stock,
                              'openingStock': stock,
                              'minimumStock': double.tryParse(minStockCtrl.text) ?? 5.0,
                              'barcode': barcodeCtrl.text.trim(),
                              'hsnCode': hsnCtrl.text.trim(),
                              'imageUrl': uploadedCompressedPhotoUrl ?? '',
                            };

                            try {
                              final syncProvider = Provider.of<SyncProvider>(context, listen: false);
                              await syncProvider.saveOfflineProduct(payload);
                            } catch (_) {}

                            setState(() {
                              _products.insert(0, {
                                'id': DateTime.now().millisecondsSinceEpoch.toString(),
                                'itemId': selectedItemObj!['id'].toString(),
                                'name': selectedItemObj!['name'],
                                'category': selectedItemObj!['category'],
                                'unit': selectedItemObj!['uom'],
                                'price': price,
                                'stock': stock.toInt(),
                                'barcode': barcodeCtrl.text.trim(),
                                'imageUrl': uploadedCompressedPhotoUrl ?? '',
                              });
                            });

                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: Text(
                            isHindi ? 'स्टॉक इन सेव करें' : 'Submit Stock In',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: themeProvider.buttonTextColor),
                          ),
                        ),
                      ),
                    ],
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
