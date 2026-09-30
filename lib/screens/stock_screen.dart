import 'dart:convert';
import 'dart:html' as html;
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';
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
      final prefs = await SharedPreferences.getInstance();
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final token = (auth.accessToken != null && auth.accessToken!.isNotEmpty)
          ? auth.accessToken!
          : (prefs.getString('auth_token') ?? '');
      final tenantId = (auth.tenantId != null && auth.tenantId! > 0)
          ? auth.tenantId!
          : (prefs.getInt('tenant_id') ?? 0);
      final tenantCode = (auth.tenantCode != null && auth.tenantCode!.isNotEmpty)
          ? auth.tenantCode!
          : (prefs.getString('tenant_code') ?? '');

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
        if (mounted) {
          setState(() {
            _availableItems = fetched;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadProducts() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final token = (auth.accessToken != null && auth.accessToken!.isNotEmpty)
          ? auth.accessToken!
          : (prefs.getString('auth_token') ?? '');
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);
      final fetchedProducts = await syncProvider.fetchProducts(token);

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

      if (mounted) {
        setState(() {
          _products = loadedList;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
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
                : filtered.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 64, color: themeProvider.primaryColor.withOpacity(0.5)),
                                const SizedBox(height: 16),
                                Text(
                                  isHindi ? 'स्टॉक लिस्ट खाली है' : 'No Active Inventory / Stock Items Found',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _availableItems.isNotEmpty
                                      ? (isHindi
                                          ? 'आपके पास Catalog में ${_availableItems.length} सामान मौजूद हैं! ऊपर "+ स्टॉक इन" बटन दबाकर नया स्टॉक जोड़ें।'
                                          : 'You have ${_availableItems.length} item(s) in your Catalog! Click "+ Stock In" to add stock & prices for them.')
                                      : (isHindi
                                          ? 'सामान जोड़ने के लिए ऊपर "+ स्टॉक इन" दबाएं।'
                                          : 'Click "+ Stock In" above to add item stock.'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13.5, color: Colors.grey.shade700),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: themeProvider.buttonBgColor,
                                    foregroundColor: themeProvider.buttonTextColor,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  ),
                                  icon: Icon(Icons.add_box_rounded, color: themeProvider.buttonTextColor),
                                  label: Text(
                                    isHindi ? '+ पहला स्टॉक इन करें' : '+ Perform Stock In Now',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.buttonTextColor),
                                  ),
                                  onPressed: () => _showAddProductModal(context, isHindi),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final isDesktop = constraints.maxWidth >= 750;

                          Widget buildStockCard(Map<String, dynamic> item) {
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
                                      mainAxisAlignment: MainAxisAlignment.center,
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
                                    mainAxisAlignment: MainAxisAlignment.center,
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
                              itemCount: filtered.length,
                              itemBuilder: (ctx, index) => buildStockCard(filtered[index]),
                            );
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            itemCount: filtered.length,
                            separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                            itemBuilder: (ctx, index) => buildStockCard(filtered[index]),
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

  void _showAddProductModal(BuildContext context, bool isHindi) {
    final themeProvider = Provider.of<TenantThemeProvider>(context, listen: false);

    Map<String, dynamic>? selectedCatalogItem;
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

                    // Dropdown Header Row with redirect button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isHindi ? '1. Catalog सामान चुनें *' : '1. Select Catalog Item *',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: themeProvider.primaryColor),
                        ),
                        InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.pushNamed(context, '/items', arguments: {'openAddModal': true});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: themeProvider.buttonBgColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.add_circle_outline, color: Colors.white, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  isHindi ? '+ Catalog में सामान जोड़ें' : '+ Add Item in Catalog',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Dropdown for selecting catalog item
                    if (_availableItems.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.amber, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                isHindi
                                    ? 'Catalog में अभी कोई सामान मौजूद नहीं है। ऊपर "+ Catalog में सामान जोड़ें" दबाकर नया सामान बनाएं!'
                                    : 'No items in catalog yet. Click "+ Add Item in Catalog" above to define an item first!',
                                style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: (selectedCatalogItem != null && _availableItems.any((i) => i['id'].toString() == selectedCatalogItem!['id'].toString()))
                            ? selectedCatalogItem!['id'].toString()
                            : null,
                        hint: Text(isHindi ? '-- Catalog से सामान चुनें --' : '-- Select Item from Catalog --'),
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
                                selectedCatalogItem = found;
                              });
                            }
                          }
                        },
                      ),
                    const SizedBox(height: 12),

                    // Inputs Section - Show when item is selected
                    if (selectedCatalogItem == null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.arrow_upward_rounded, color: Colors.blueGrey, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isHindi
                                    ? 'स्टॉक दर्ज करने के लिए कृपया ऊपर दिए गए ड्रॉपडाउन से सामान चुनें।'
                                    : 'Please select a Catalog Item from the dropdown above to enter stock & prices.',
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.blueGrey),
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      // Item Preview Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: themeProvider.primaryColor.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: themeProvider.primaryColor.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  selectedCatalogItem!['name'] ?? '',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                Chip(
                                  label: Text(
                                    selectedCatalogItem!['format'] == 'Loose' ? 'LOOSE BULK' : 'PACKED',
                                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                  backgroundColor: selectedCatalogItem!['format'] == 'Loose' ? Colors.orange.shade100 : Colors.blue.shade100,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Code: ${selectedCatalogItem!['itemCode']}  •  Category: ${selectedCatalogItem!['category']}  •  UOM: ${selectedCatalogItem!['uom']}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
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

                      // Inventory Inputs (Stock Qty, Min Stock Alert)
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

                      // Image Upload Button
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
                            if (selectedCatalogItem == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isHindi ? 'कृपया ड्रॉपडाउन से सामान चुनें!' : 'Please select an item from the dropdown!'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            final double price = double.tryParse(priceCtrl.text) ?? 0.0;
                            final double stock = double.tryParse(stockCtrl.text) ?? 0.0;
                            if (price <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isHindi ? 'कृपया मान्य बिक्री मूल्य (₹) दर्ज करें!' : 'Please enter a valid Selling Price (₹)!'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            try {
                              final prefs = await SharedPreferences.getInstance();
                              final auth = Provider.of<AuthProvider>(context, listen: false);
                              final token = (auth.accessToken != null && auth.accessToken!.isNotEmpty)
                                  ? auth.accessToken!
                                  : (prefs.getString('auth_token') ?? '');
                              final tenantId = (auth.tenantId != null && auth.tenantId! > 0)
                                  ? auth.tenantId!
                                  : (prefs.getInt('tenant_id') ?? 0);
                              final tenantCode = (auth.tenantCode != null && auth.tenantCode!.isNotEmpty)
                                  ? auth.tenantCode!
                                  : (prefs.getString('tenant_code') ?? '');

                              final headers = <String, String>{
                                'Content-Type': 'application/json',
                                if (token.isNotEmpty) 'Authorization': 'Bearer $token',
                                if (tenantId > 0) 'X-Tenant-Id': tenantId.toString(),
                                if (tenantCode.isNotEmpty) 'X-Tenant-Code': tenantCode,
                              };

                              final stockPayload = {
                                'tenantId': tenantId > 0 ? tenantId : 1,
                                'tenantCode': tenantCode,
                                'itemId': int.tryParse(selectedCatalogItem!['id'].toString()) ?? 0,
                                'productCode': selectedCatalogItem!['itemCode'] ?? '',
                                'name': selectedCatalogItem!['name'] ?? '',
                                'category': selectedCatalogItem!['category'] ?? 'Groceries',
                                'unit': selectedCatalogItem!['uom'] ?? 'pcs',
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

                              final res = await http.post(
                                Uri.parse('${ApiConfig.baseUrl}/stock'),
                                headers: headers,
                                body: jsonEncode(stockPayload),
                              ).timeout(const Duration(seconds: 12));

                              if (res.statusCode == 200 || res.statusCode == 201) {
                                if (mounted) {
                                  setState(() {
                                    _products.insert(0, {
                                      'id': DateTime.now().millisecondsSinceEpoch.toString(),
                                      'itemId': selectedCatalogItem!['id'].toString(),
                                      'productCode': selectedCatalogItem!['itemCode'],
                                      'name': selectedCatalogItem!['name'],
                                      'category': selectedCatalogItem!['category'],
                                      'unit': selectedCatalogItem!['uom'],
                                      'price': price,
                                      'stock': stock.toInt(),
                                      'barcode': barcodeCtrl.text.trim(),
                                      'imageUrl': uploadedCompressedPhotoUrl ?? '',
                                    });
                                  });
                                }

                                if (ctx.mounted) Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(isHindi ? 'स्टॉक इन सफलतापूर्वक दर्ज हो गया!' : 'Stock in entry saved successfully!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                _loadProducts();
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to save stock: Status ${res.statusCode}'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Save error: ${e.toString()}'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          child: Text(
                            isHindi ? 'स्टॉक इन सेव करें' : 'Save Stock In Entry',
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
