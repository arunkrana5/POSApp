import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../providers/sync_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/app_drawer.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Map<String, dynamic>> _products = [
    {'id': '1', 'name': 'Aashirvaad Atta 5kg', 'category': 'Groceries', 'price': 220.0, 'stock': 15, 'unit': 'pkt', 'barcode': '890102030101', 'imageUrl': 'https://images.unsplash.com/photo-1574316071802-0d684efa7bf5?w=150&auto=format&fit=crop&q=80'},
    {'id': '2', 'name': 'Fortune Mustard Oil 1L', 'category': 'Oil', 'price': 145.0, 'stock': 3, 'unit': 'bottle', 'barcode': '890102030102', 'imageUrl': ''},
    {'id': '3', 'name': 'Tata Salt 1kg', 'category': 'Groceries', 'price': 28.0, 'stock': 40, 'unit': 'pkt', 'barcode': '890102030103', 'imageUrl': ''},
    {'id': '4', 'name': 'Surf Excel 1kg', 'category': 'Detergent', 'price': 130.0, 'stock': 0, 'unit': 'pkt', 'barcode': '890102030104', 'imageUrl': ''},
    {'id': '5', 'name': 'Sugar (चीनी) 1kg', 'category': 'Groceries', 'price': 42.0, 'stock': 50, 'unit': 'kg', 'barcode': '890102030105', 'imageUrl': ''},
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
          'barcode': p.barcode.isNotEmpty ? p.barcode : '890${(100000000 + Random().nextInt(899999999))}',
          'imageUrl': p.imageUrl,
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
                      final barcode = item['barcode']?.toString() ?? '';
                      final imgUrl = item['imageUrl']?.toString() ?? '';

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
                              // Product Image Thumbnail or Inventory Icon
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: isOutOfStock
                                      ? Colors.red.shade50
                                      : (isLowStock ? Colors.orange.shade50 : Colors.blue.shade50),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: (imgUrl.isNotEmpty && Uri.tryParse(imgUrl)?.hasAbsolutePath == true)
                                    ? Image.network(
                                        imgUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Icon(
                                          Icons.inventory_2_rounded,
                                          color: isOutOfStock
                                              ? Colors.red.shade800
                                              : (isLowStock ? Colors.orange.shade800 : Colors.blue.shade800),
                                        ),
                                      )
                                    : Icon(
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
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          if (barcode.isNotEmpty)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(4)),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.qr_code_2_rounded, size: 12, color: Colors.purple.shade900),
                                                  const SizedBox(width: 3),
                                                  Text(barcode, style: TextStyle(fontSize: 11, color: Colors.purple.shade900, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                            ),
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
    final codeCtrl = TextEditingController(text: 'PRD-${1000 + Random().nextInt(8999)}');
    final priceCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final stockCtrl = TextEditingController();
    final batchCtrl = TextEditingController();
    final rackCtrl = TextEditingController();
    final expiryCtrl = TextEditingController();
    final hsnCtrl = TextEditingController();
    final barcodeCtrl = TextEditingController(text: '890${100000000 + Random().nextInt(899999999)}');
    final brandCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final imgUrlCtrl = TextEditingController();
    String selectedCategory = 'Groceries';
    String selectedUnit = 'pkt';
    String selectedItemFormat = 'Packed'; // Packed vs Loose
    String? selectedMasterItem;

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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isHindi ? 'सामान मास्टर और स्टॉक इन (Item Master)' : 'Item Master & Stock In Entry',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.red),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Item Master Linkage Dropdown
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.inventory_rounded, color: Colors.blue, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            isHindi ? 'मास्टर आइटम से चुनें (Stock In Quick Link):' : 'Select from Item Master (Stock In Quick Link):',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: selectedMasterItem,
                        hint: Text(isHindi ? '-- मास्टर लिस्ट से ऑटो-फिल करें --' : '-- Auto-fill details from Item Master --'),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: _products
                            .map((p) => p['name']?.toString() ?? '')
                            .where((name) => name.isNotEmpty)
                            .toSet()
                            .map((name) => DropdownMenuItem(value: name, child: Text(name, style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            final match = _products.firstWhere((p) => p['name'] == val, orElse: () => {});
                            if (match.isNotEmpty) {
                              setModalState(() {
                                selectedMasterItem = val;
                                nameCtrl.text = match['name']?.toString() ?? '';
                                if (match['productCode'] != null) codeCtrl.text = match['productCode'].toString();
                                if (match['category'] != null) selectedCategory = match['category'].toString();
                                if (match['unit'] != null) {
                                  selectedUnit = match['unit'].toString();
                                  if (['kg', 'g', 'gm', 'ltr', 'ml'].contains(selectedUnit.toLowerCase())) {
                                    selectedItemFormat = 'Loose';
                                  }
                                }
                                if (match['price'] != null) priceCtrl.text = match['price'].toString();
                                if (match['purchasePrice'] != null) costCtrl.text = match['purchasePrice'].toString();
                                if (match['brand'] != null) brandCtrl.text = match['brand'].toString();
                                if (match['hsnCode'] != null) hsnCtrl.text = match['hsnCode'].toString();
                                if (match['barcode'] != null) barcodeCtrl.text = match['barcode'].toString();
                              });
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Item Type Format Switch (Packed vs Loose Bulk)
                Row(
                  children: [
                    const Text('Item Format / Type: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Row(children: [Icon(Icons.inventory_2_rounded, size: 16), SizedBox(width: 4), Text('Packed Item')]),
                      selected: selectedItemFormat == 'Packed',
                      selectedColor: Colors.blue.shade700,
                      labelStyle: TextStyle(color: selectedItemFormat == 'Packed' ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                      onSelected: (sel) {
                        if (sel) {
                          setModalState(() {
                            selectedItemFormat = 'Packed';
                            if (['kg', 'ltr', 'gm', 'ml'].contains(selectedUnit)) selectedUnit = 'pkt';
                          });
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Row(children: [Icon(Icons.scale_rounded, size: 16), SizedBox(width: 4), Text('Loose Bulk (Weight)')]),
                      selected: selectedItemFormat == 'Loose',
                      selectedColor: Colors.orange.shade800,
                      labelStyle: TextStyle(color: selectedItemFormat == 'Loose' ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                      onSelected: (sel) {
                        if (sel) {
                          setModalState(() {
                            selectedItemFormat = 'Loose';
                            selectedUnit = 'kg';
                          });
                        }
                      },
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
                          labelText: isHindi ? 'आइटम कोड' : 'Item Code',
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
                          labelText: isHindi ? 'सामान का नाम *' : 'Item / Product Name *',
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
                        value: selectedUnit,
                        decoration: InputDecoration(
                          labelText: isHindi ? 'UOM (यूनिट)' : 'UOM (Unit)',
                          border: const OutlineInputBorder(),
                        ),
                        items: (selectedItemFormat == 'Loose'
                                ? ['kg', 'gm', 'ltr', 'ml']
                                : ['pkt', 'pcs', 'bottle', 'box', 'bag', 'kg', 'ltr'])
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
                // Barcode input with auto-generate button
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: barcodeCtrl,
                        decoration: InputDecoration(
                          labelText: isHindi ? 'बारकोड (Barcode)' : 'Barcode Number',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.qr_code_scanner),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                      ),
                      icon: const Icon(Icons.autorenew_rounded, size: 18),
                      label: Text(isHindi ? 'जेनरेट' : 'Gen Barcode', style: const TextStyle(fontSize: 12)),
                      onPressed: () {
                        setModalState(() {
                          barcodeCtrl.text = '890${100000000 + Random().nextInt(899999999)}';
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: imgUrlCtrl,
                  decoration: InputDecoration(
                    labelText: isHindi ? 'सामान का फोटो/लोगो URL (Image URL)' : 'Product Image / Logo URL',
                    hintText: 'https://example.com/photo.jpg',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.image_rounded),
                  ),
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
                        readOnly: true,
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: DateTime.now().add(const Duration(days: 180)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 3650)),
                          );
                          if (picked != null) {
                            final yyyy = picked.year.toString();
                            final mm = picked.month.toString().padLeft(2, '0');
                            final dd = picked.day.toString().padLeft(2, '0');
                            setModalState(() {
                              expiryCtrl.text = '$yyyy-$mm-$dd';
                            });
                          }
                        },
                        decoration: InputDecoration(
                          labelText: isHindi ? 'एक्सपायरी डेट (Expiry Date)' : 'Expiry Date',
                          hintText: 'Select date',
                          prefixIcon: const Icon(Icons.calendar_today_rounded),
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
                        final costP = double.tryParse(costCtrl.text) ?? sellingP;
                        final stockQty = int.tryParse(stockCtrl.text) ?? 10;
                        final expStr = expiryCtrl.text.trim();

                        final newProduct = {
                          'id': '${_products.length + 1}',
                          'name': nameCtrl.text.trim(),
                          'category': selectedCategory,
                          'brand': brandCtrl.text.trim(),
                          'price': sellingP,
                          'purchasePrice': costP,
                          'sellingPrice': sellingP,
                          'mrp': sellingP,
                          'stock': stockQty,
                          'currentStock': stockQty,
                          'openingStock': stockQty,
                          'minimumStock': 5,
                          'unit': selectedUnit,
                          'batchNumber': batchCtrl.text.trim(),
                          'rackNumber': rackCtrl.text.trim(),
                          'expiryDate': expStr.isNotEmpty ? expStr : null,
                          'hsnCode': hsnCtrl.text.trim(),
                          'barcode': barcodeCtrl.text.trim(),
                          'imageUrl': imgUrlCtrl.text.trim(),
                        };

                        try {
                          final syncProvider = Provider.of<SyncProvider>(context, listen: false);
                          await syncProvider.saveOfflineProduct(newProduct);
                        } catch (_) {}

                        setState(() {
                          _products.insert(0, newProduct);
                        });

                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isHindi
                                    ? 'सामान और बारकोड सफलतापूर्वक सहेजा गया!'
                                    : 'Product with Barcode & Image saved & synced!',
                              ),
                              backgroundColor: Colors.green.shade700,
                            ),
                          );
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isHindi
                                  ? 'कृपया सामान का नाम भरें'
                                  : 'Please enter product name',
                            ),
                            backgroundColor: Colors.amber.shade800,
                          ),
                        );
                      }
                    },
                    child: Text(
                      isHindi ? 'सामान सहेजें' : 'Save Product',
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
