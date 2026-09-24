import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../providers/sync_provider.dart';
import '../providers/theme_provider.dart';
import '../database/sqlite_helper.dart';
import '../widgets/app_drawer.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Map<String, dynamic>> _products = [
    {'id': '1', 'name': 'Aashirvaad Atta 5kg', 'category': 'Groceries', 'price': 220.0, 'stock': 15, 'unit': 'pkt'},
    {'id': '2', 'name': 'Fortune Mustard Oil 1L', 'category': 'Oil', 'price': 145.0, 'stock': 3, 'unit': 'bottle'},
    {'id': '3', 'name': 'Tata Salt 1kg', 'category': 'Groceries', 'price': 28.0, 'stock': 40, 'unit': 'pkt'},
    {'id': '4', 'name': 'Surf Excel 1kg', 'category': 'Detergent', 'price': 130.0, 'stock': 0, 'unit': 'pkt'},
    {'id': '5', 'name': 'Sugar (चीनी) 1kg', 'category': 'Groceries', 'price': 42.0, 'stock': 50, 'unit': 'kg'},
  ];

  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);
      final fetchedProducts = await syncProvider.fetchProducts();
      
      if (fetchedProducts.isNotEmpty) {
        final List<Map<String, dynamic>> loadedList = fetchedProducts.map((p) => {
          'id': p.id.toString(),
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
          'barcode': p.barcode,
        }).toList();

        // Merge with defaults to avoid duplicates by name
        final existingNames = loadedList.map((e) => e['name'].toString().toLowerCase()).toSet();
        for (var d in _products) {
          if (!existingNames.contains(d['name'].toString().toLowerCase())) {
            loadedList.add(d);
          }
        }
        setState(() {
          _products = loadedList;
        });
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = Provider.of<LocaleProvider>(context).isHindi;
    final filtered = _products
        .where((p) =>
            p['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (p['category'] != null && p['category'].toString().toLowerCase().contains(_searchQuery.toLowerCase())) ||
            (p['batchNumber'] != null && p['batchNumber'].toString().toLowerCase().contains(_searchQuery.toLowerCase())) ||
            (p['rackNumber'] != null && p['rackNumber'].toString().toLowerCase().contains(_searchQuery.toLowerCase())) ||
            (p['barcode'] != null && p['barcode'].toString().toLowerCase().contains(_searchQuery.toLowerCase())))
        .toList();

    final themeProvider = Provider.of<TenantThemeProvider>(context);
    return Scaffold(
      backgroundColor: themeProvider.pageBgColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(
          isHindi ? 'सामान और स्टॉक' : 'Products & Inventory',
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
                      hintText: isHindi ? 'सामान, बैच, रैक, बारकोड खोजें...' : 'Search product, batch, rack, barcode...',
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
                    isHindi ? 'जोड़ें' : 'Add',
                    style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.buttonTextColor),
                  ),
                  onPressed: () => _showAddProductModal(context, isHindi),
                ),
              ],
            ),
          ),

          // Products Catalog List
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
                      final minStock = (item['minimumStock'] is num) ? (item['minimumStock'] as num).toInt() : 5;
                      final isOutOfStock = stock == 0;
                      final isLowStock = stock > 0 && stock <= minStock;

                      final batch = item['batchNumber']?.toString() ?? '';
                      final rack = item['rackNumber']?.toString() ?? '';
                      final exp = item['expiryDate']?.toString() ?? '';
                      final brand = item['brand']?.toString() ?? '';

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isOutOfStock
                                      ? Colors.red.shade100
                                      : (isLowStock ? Colors.orange.shade100 : Colors.blue.shade100),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.inventory_2_rounded,
                                  color: isOutOfStock
                                      ? Colors.red.shade800
                                      : (isLowStock ? Colors.orange.shade800 : Colors.blue.shade800),
                                ),
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
                                      '${item["category"]}${brand.isNotEmpty ? " • $brand" : ""} • ₹ ${item["price"]}/${item["unit"] ?? "pcs"}',
                                      style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                                    ),
                                    if (batch.isNotEmpty || rack.isNotEmpty || exp.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            if (batch.isNotEmpty)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                                                child: Text('Batch: $batch', style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                                              ),
                                            if (rack.isNotEmpty)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                                                child: Text('Rack: $rack', style: TextStyle(fontSize: 11, color: Colors.blue.shade900, fontWeight: FontWeight.bold)),
                                              ),
                                            if (exp.isNotEmpty)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(4)),
                                                child: Text('Exp: $exp', style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontWeight: FontWeight.bold)),
                                              ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isOutOfStock
                                          ? Colors.red.shade700
                                          : (isLowStock ? Colors.orange.shade800 : Colors.green.shade700),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      isOutOfStock
                                          ? (isHindi ? 'स्टॉक खत्म' : 'Out of Stock')
                                          : (isLowStock
                                              ? (isHindi ? 'कम ($stock)' : 'Low ($stock)')
                                              : (isHindi ? 'स्टॉक: $stock' : 'Stock: $stock')),
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddProductModal(BuildContext context, bool isHindi) {
    final themeProvider = Provider.of<TenantThemeProvider>(context, listen: false);
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final stockCtrl = TextEditingController();
    final batchCtrl = TextEditingController();
    final rackCtrl = TextEditingController();
    final expiryCtrl = TextEditingController();
    final hsnCtrl = TextEditingController();
    final barcodeCtrl = TextEditingController();
    final brandCtrl = TextEditingController();
    String selectedCategory = 'Groceries';
    String selectedUnit = 'pkt';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
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
                Text(
                  isHindi ? 'नया सामान जोड़ें (Enterprise)' : 'Add New Product',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: isHindi ? 'सामान नाम *' : 'Product Name *',
                    border: const OutlineInputBorder(),
                  ),
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
                        items: ['Groceries', 'Edible Oil', 'Detergent', 'Spices', 'Beverages', 'General']
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) => setModalState(() => selectedCategory = v ?? 'Groceries'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedUnit,
                        decoration: InputDecoration(
                          labelText: isHindi ? 'यूनिट' : 'Unit',
                          border: const OutlineInputBorder(),
                        ),
                        items: ['pkt', 'bottle', 'kg', 'g', 'ltr', 'pcs', 'box']
                            .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                            .toList(),
                        onChanged: (v) => setModalState(() => selectedUnit = v ?? 'pkt'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
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
                        controller: brandCtrl,
                        decoration: InputDecoration(
                          labelText: isHindi ? 'ब्रांड (Brand)' : 'Brand Name',
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
                        controller: batchCtrl,
                        decoration: InputDecoration(
                          labelText: isHindi ? 'बैच नंबर (Batch No)' : 'Batch No.',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: rackCtrl,
                        decoration: InputDecoration(
                          labelText: isHindi ? 'रैक नंबर (Rack No)' : 'Rack / Shelf No.',
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
                        controller: expiryCtrl,
                        decoration: InputDecoration(
                          labelText: isHindi ? 'एक्सपायरी डेट (YYYY-MM-DD)' : 'Expiry Date (YYYY-MM-DD)',
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
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeProvider.buttonBgColor,
                      foregroundColor: themeProvider.buttonTextColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      if (nameCtrl.text.isNotEmpty) {
                        final sellingP = double.tryParse(priceCtrl.text) ?? 0.0;
                        final newProduct = {
                          'id': '${_products.length + 1}',
                          'name': nameCtrl.text,
                          'category': selectedCategory,
                          'brand': brandCtrl.text,
                          'price': sellingP,
                          'purchasePrice': double.tryParse(costCtrl.text) ?? sellingP,
                          'sellingPrice': sellingP,
                          'mrp': sellingP,
                          'stock': int.tryParse(stockCtrl.text) ?? 10,
                          'unit': selectedUnit,
                          'batchNumber': batchCtrl.text,
                          'rackNumber': rackCtrl.text,
                          'expiryDate': expiryCtrl.text,
                          'hsnCode': hsnCtrl.text,
                          'barcode': barcodeCtrl.text,
                        };

                        final syncProvider = Provider.of<SyncProvider>(context, listen: false);
                        await syncProvider.saveOfflineProduct(newProduct);

                        setState(() {
                          _products.insert(0, newProduct);
                        });

                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isHindi
                                    ? 'सामान सुरक्षित रूप से सहेजा गया! (Offline saved)'
                                    : 'Product saved & synced to backend!',
                              ),
                              backgroundColor: Colors.green.shade700,
                            ),
                          );
                        }
                      }
                    },
                    child: Text(
                      isHindi ? 'सामान सेव करें' : 'Save Product',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
