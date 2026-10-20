import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/invoice_printer.dart';
import '../utils/whatsapp_helper.dart';
import '../providers/sync_provider.dart';
import '../providers/theme_provider.dart';
import '../database/sqlite_helper.dart';
import '../widgets/app_drawer.dart';
import '../utils/toast_helper.dart';
import '../providers/master_provider.dart';
import '../widgets/paginated_server_dropdown.dart';

import 'package:shared_preferences/shared_preferences.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  Widget _buildProductThumbnail(String imgUrl, {double height = 110, double? width, BoxFit fit = BoxFit.contain}) {
    final clean = imgUrl.trim();
    final placeholder = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: height * 0.38, color: Colors.blueGrey.shade300),
          const SizedBox(height: 4),
          Text(
            'VillageShop',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Colors.blueGrey.shade400,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );

    if (clean.isEmpty) {
      return placeholder;
    }

    if (clean.startsWith('data:image/')) {
      try {
        final parts = clean.split(',');
        if (parts.length > 1) {
          final bytes = base64Decode(parts[1].trim());
          return Image.memory(
            bytes,
            height: height,
            width: width ?? double.infinity,
            fit: fit,
            errorBuilder: (_, __, ___) => placeholder,
          );
        }
      } catch (_) {}
    } else if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return Image.network(
        clean,
        height: height,
        width: width ?? double.infinity,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => placeholder,
      );
    } else {
      try {
        final bytes = base64Decode(clean);
        return Image.memory(
          bytes,
          height: height,
          width: width ?? double.infinity,
          fit: fit,
          errorBuilder: (_, __, ___) => placeholder,
        );
      } catch (_) {}
    }
    return placeholder;
  }

  Widget _buildTileThumbnail(String imgUrl, {double size = 44}) {
    return _buildProductThumbnail(imgUrl, height: size, width: size, fit: BoxFit.cover);
  }

  final List<Map<String, dynamic>> _availableProducts = [];

  final List<String> _customerList = [
    'Walk-in Customer',
  ];

  final Map<String, String> _customerPhoneMap = {};
  final Map<String, dynamic> _customerIdMap = {};

  final TextEditingController _customerPhoneController = TextEditingController();
  final List<Map<String, dynamic>> _cartItems = [];
  String _selectedPaymentMode = 'Cash';
  String _selectedCustomer = 'Walk-in Customer';
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customerPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    try {
      final dbCustomers = await SQLiteHelper.instance.getCustomers();
      if (dbCustomers.isNotEmpty && mounted) {
        setState(() {
          for (var c in dbCustomers) {
            final n = c['name']?.toString() ?? '';
            final p = (c['phone'] ?? c['mobile'] ?? '').toString();
            final id = c['id'];
            if (n.isNotEmpty) {
              if (!_customerList.contains(n)) {
                _customerList.add(n);
              }
              if (p.isNotEmpty) {
                _customerPhoneMap[n] = p;
              }
              if (id != null) {
                _customerIdMap[n] = id;
              }
            }
          }
          if (_selectedCustomer != 'Walk-in Customer' && _customerPhoneController.text.isEmpty) {
            _customerPhoneController.text = _customerPhoneMap[_selectedCustomer] ?? '';
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadProducts() async {
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
        'productCode': p.productCode,
        'name': p.name,
        'category': p.category.isNotEmpty ? p.category : 'General',
        'brand': p.brand,
        'price': p.sellingPrice > 0 ? p.sellingPrice : (p.mrp > 0 ? p.mrp : p.purchasePrice),
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
        'imageUrl': p.imageUrl,
      }).toList();

      if (mounted) {
        setState(() {
          _availableProducts.clear();
          _availableProducts.addAll(loadedList);
        });
      }
    } catch (_) {}
  }

  double get _subtotal {
    return _cartItems.fold(0.0, (sum, item) => sum + (item['price'] * item['qty']));
  }

  void _showLooseItemQuantityDialog(Map<String, dynamic> product, TenantThemeProvider themeProvider, [int? cartIndex]) {
    final unit = (product['unit']?.toString() ?? 'kg').toLowerCase();
    final stockRate = (product['price'] as num).toDouble();
    double currentPrice = stockRate;
    double currentWeight = 1.0;
    if (cartIndex != null && cartIndex >= 0 && cartIndex < _cartItems.length) {
      currentWeight = (_cartItems[cartIndex]['qty'] as num).toDouble();
      currentPrice = ((_cartItems[cartIndex]['price'] ?? stockRate) as num).toDouble();
    }

    final rateController = TextEditingController(
      text: currentPrice.toStringAsFixed(currentPrice == currentPrice.roundToDouble() ? 0 : 2),
    );
    final weightController = TextEditingController(
      text: currentWeight.toStringAsFixed(currentWeight == currentWeight.roundToDouble() ? 0 : 3),
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final calcRate = double.tryParse(rateController.text) ?? 0.0;
          final calcWeight = double.tryParse(weightController.text) ?? 0.0;
          final calcTotal = calcWeight * calcRate;
          final isRateModified = (calcRate - stockRate).abs() > 0.001;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.scale_rounded, color: Colors.orange, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product['name'] ?? 'Loose Item', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(
                        isRateModified
                            ? 'Stock Rate: ₹$stockRate / ${product['unit']} (Custom rate active)'
                            : 'Rate: ₹$stockRate / ${product['unit']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isRateModified ? Colors.amber.shade900 : Colors.grey.shade700,
                          fontWeight: isRateModified ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Editable Rate Input Field
                  TextField(
                    controller: rateController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Selling Rate (₹ per ${product['unit']}) *',
                      hintText: 'e.g. $stockRate',
                      prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 18, color: Colors.green),
                      suffixText: 'per ${product['unit']}',
                      helperText: isRateModified
                          ? '⚡ Custom Rate: ₹${calcRate.toStringAsFixed(2)} (Stock was ₹${stockRate.toStringAsFixed(2)})'
                          : 'Autofilled from stock inventory',
                      helperStyle: TextStyle(
                        color: isRateModified ? Colors.amber.shade900 : Colors.grey.shade600,
                        fontWeight: isRateModified ? FontWeight.bold : FontWeight.normal,
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),

                  const Text('Enter Qty / Weight:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      0.100, 0.250, 0.500, 1.000, 2.000, 5.000
                    ].map((w) => ActionChip(
                      label: Text(w < 1 ? '${(w * 1000).toInt()} gm' : '$w $unit', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      backgroundColor: (calcWeight == w) ? Colors.orange.shade100 : Colors.grey.shade100,
                      onPressed: () {
                        setDialogState(() {
                          weightController.text = w.toStringAsFixed(w == w.roundToDouble() ? 0 : 3);
                        });
                      },
                    )).toList(),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Exact Quantity (${product['unit']})',
                      hintText: 'e.g. 0.750 or 1.5',
                      prefixIcon: const Icon(Icons.edit_rounded, size: 18),
                      suffixText: product['unit'],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Amount:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('₹ ${calcTotal.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.green.shade800)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              if (cartIndex != null && cartIndex >= 0)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _cartItems.removeAt(cartIndex);
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Remove Item', style: TextStyle(color: Colors.red)),
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: themeProvider.buttonBgColor, foregroundColor: themeProvider.buttonTextColor),
                onPressed: () {
                  final w = double.tryParse(weightController.text) ?? 0.0;
                  final r = double.tryParse(rateController.text) ?? 0.0;
                  if (w <= 0 || r < 0) return;
                  setState(() {
                    if (cartIndex != null && cartIndex >= 0) {
                      _cartItems[cartIndex]['qty'] = w;
                      _cartItems[cartIndex]['price'] = r;
                      _cartItems[cartIndex]['stockRate'] = stockRate;
                    } else {
                      final existingIdx = _cartItems.indexWhere((item) => item['id'] == product['id']);
                      if (existingIdx >= 0) {
                        _cartItems[existingIdx]['qty'] = w;
                        _cartItems[existingIdx]['price'] = r;
                        _cartItems[existingIdx]['stockRate'] = stockRate;
                      } else {
                        _cartItems.add({
                          'id': product['id'],
                          'name': product['name'],
                          'price': r,
                          'stockRate': stockRate,
                          'unit': product['unit'],
                          'qty': w,
                          'isLoose': true,
                        });
                      }
                    }
                  });
                  Navigator.pop(ctx);
                },
                child: Text(cartIndex != null ? 'Update Item' : 'Add Loose Item', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditCartItemDialog(int index, TenantThemeProvider themeProvider) {
    if (index < 0 || index >= _cartItems.length) return;
    final item = _cartItems[index];
    final isHindi = Provider.of<LocaleProvider>(context, listen: false).isHindi;
    final unit = (item['unit']?.toString() ?? 'pcs');
    final stockRate = (item['stockRate'] as num?)?.toDouble() ?? (item['price'] as num).toDouble();
    final currentRate = (item['price'] as num).toDouble();
    final currentQty = (item['qty'] as num).toDouble();

    final rateCtrl = TextEditingController(
      text: currentRate.toStringAsFixed(currentRate == currentRate.roundToDouble() ? 0 : 2),
    );
    final qtyCtrl = TextEditingController(
      text: currentQty.toStringAsFixed(currentQty == currentQty.roundToDouble() ? 0 : 3),
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final calcRate = double.tryParse(rateCtrl.text) ?? 0.0;
          final calcQty = double.tryParse(qtyCtrl.text) ?? 0.0;
          final calcTotal = calcRate * calcQty;
          final isModified = (calcRate - stockRate).abs() > 0.001;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isModified ? Colors.amber.shade100 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.edit_note_rounded,
                    color: isModified ? Colors.amber.shade900 : Colors.blue.shade700,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isHindi ? 'दर और मात्रा बदलें' : 'Edit Rate & Quantity',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        item['name'] ?? 'Item',
                        style: TextStyle(fontSize: 13, color: themeProvider.primaryColor, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stock Reference & Reset pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isModified ? Colors.amber.shade50 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isModified ? Colors.amber.shade200 : Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Stock Rate: ₹${stockRate.toStringAsFixed(2)} / $unit',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.w600),
                        ),
                        if (isModified)
                          InkWell(
                            onTap: () {
                              setDialogState(() {
                                rateCtrl.text = stockRate.toStringAsFixed(stockRate == stockRate.roundToDouble() ? 0 : 2);
                              });
                            },
                            child: const Text(
                              'Reset to Stock',
                              style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 1. EDITABLE RATE FIELD
                  TextField(
                    controller: rateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: isHindi ? 'बिक्री दर (Rate ₹ per $unit) *' : 'Selling Rate (₹ per $unit) *',
                      hintText: 'Enter new rate',
                      prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 20, color: Colors.green),
                      suffixText: 'per $unit',
                      helperText: isModified
                          ? '⚡ Custom Rate: ₹${calcRate.toStringAsFixed(2)} (Stock was ₹${stockRate.toStringAsFixed(2)})'
                          : 'Autofilled from stock inventory',
                      helperStyle: TextStyle(
                        color: isModified ? Colors.amber.shade900 : Colors.grey.shade600,
                        fontWeight: isModified ? FontWeight.bold : FontWeight.normal,
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: themeProvider.primaryColor, width: 2),
                      ),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 14),

                  // 2. QUANTITY FIELD WITH STEPPERS
                  Row(
                    children: [
                      IconButton.filledTonal(
                        icon: const Icon(Icons.remove, size: 18),
                        onPressed: () {
                          final current = double.tryParse(qtyCtrl.text) ?? 1.0;
                          if (current > 1) {
                            setDialogState(() {
                              qtyCtrl.text = (current - 1).toStringAsFixed(0);
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: qtyCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            labelText: isHindi ? 'मात्रा (Quantity)' : 'Quantity ($unit)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          ),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.add, size: 18),
                        onPressed: () {
                          final current = double.tryParse(qtyCtrl.text) ?? 0.0;
                          setDialogState(() {
                            qtyCtrl.text = (current + 1).toStringAsFixed(0);
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 3. INSTANT CALCULATION PREVIEW CARD
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade300, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isHindi ? 'कुल लाइन मूल्य:' : 'Calculated Line Total:',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            Text(
                              '₹ ${calcTotal.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.green.shade900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Formula: $calcQty $unit × ₹${calcRate.toStringAsFixed(2)} = ₹${calcTotal.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 11, color: Colors.green.shade800, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _cartItems.removeAt(index);
                  });
                  Navigator.pop(ctx);
                },
                child: Text(isHindi ? 'हटाएं' : 'Remove', style: const TextStyle(color: Colors.red)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(isHindi ? 'रद्द करें' : 'Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeProvider.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: (calcRate < 0 || calcQty <= 0)
                    ? null
                    : () {
                        setState(() {
                          _cartItems[index]['price'] = calcRate;
                          _cartItems[index]['qty'] = calcQty;
                          _cartItems[index]['stockRate'] = stockRate;
                        });
                        Navigator.pop(ctx);
                        ToastHelper.showSuccess(
                          context,
                          'Rate updated to ₹${calcRate.toStringAsFixed(2)} for ${item['name']}',
                        );
                      },
                child: Text(
                  isHindi ? 'दर अपडेट करें' : 'Update Rate',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCartDetailsSheet(TenantThemeProvider themeProvider) {
    final isHindi = Provider.of<LocaleProvider>(context, listen: false).isHindi;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final currentTax = themeProvider.enableTaxCalculation
              ? (_subtotal * (themeProvider.defaultTaxPercent / 100))
              : 0.0;
          final currentGrand = _subtotal + currentTax;

          return Padding(
            padding: EdgeInsets.only(
              top: 16,
              left: 16,
              right: 16,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 16,
            ),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.75,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.shopping_cart_rounded, color: themeProvider.primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            isHindi ? 'कार्ट में सामान (${_cartItems.length})' : 'Cart Items (${_cartItems.length})',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.delete_sweep_rounded, size: 18, color: Colors.red),
                        label: Text(isHindi ? 'कार्ट खाली करें' : 'Clear All', style: const TextStyle(color: Colors.red, fontSize: 12)),
                        onPressed: () {
                          setState(() => _cartItems.clear());
                          Navigator.pop(sheetCtx);
                        },
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: _cartItems.isEmpty
                        ? Center(child: Text(isHindi ? 'कार्ट खाली है' : 'Cart is empty'))
                        : ListView.separated(
                            itemCount: _cartItems.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (c, idx) {
                              final it = _cartItems[idx];
                              final rate = (it['price'] as num).toDouble();
                              final qty = (it['qty'] as num).toDouble();
                              final stockR = (it['stockRate'] as num?)?.toDouble() ?? rate;
                              final isMod = (rate - stockR).abs() > 0.001;
                              final lineTot = rate * qty;

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        it['name'] ?? 'Item',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ),
                                    if (isMod)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.amber.shade300),
                                        ),
                                        child: Text(
                                          'Edited Rate',
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Row(
                                  children: [
                                    // Rate with Edit button
                                    InkWell(
                                      onTap: () {
                                        Navigator.pop(sheetCtx);
                                        _showEditCartItemDialog(idx, themeProvider);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.blue.shade200),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Rate: ₹${rate.toStringAsFixed(2)} / ${it['unit']}',
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(Icons.edit, size: 12, color: Colors.blue),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('× $qty = ₹${lineTot.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.red),
                                      onPressed: () {
                                        setState(() {
                                          _updateQuantity(idx, -1, themeProvider);
                                        });
                                        setSheetState(() {});
                                      },
                                    ),
                                    Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, size: 20, color: Colors.green),
                                      onPressed: () {
                                        setState(() {
                                          _updateQuantity(idx, 1, themeProvider);
                                        });
                                        setSheetState(() {});
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isHindi ? 'कुल राशि:' : 'Total Amount:', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      Text('₹ ${currentGrand.toStringAsFixed(2)}', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.green.shade800)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeProvider.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(sheetCtx),
                      child: Text(isHindi ? 'बिलिंग जारी रखें' : 'Continue Billing', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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

  void _addToCart(Map<String, dynamic> product, TenantThemeProvider themeProvider) {
    final unit = (product['unit']?.toString() ?? '').toLowerCase();
    final isLoose = product['isLoose'] == true || ['kg', 'g', 'gm', 'ltr', 'ml'].contains(unit);
    if (isLoose) {
      final existingIndex = _cartItems.indexWhere((item) => item['id'] == product['id']);
      _showLooseItemQuantityDialog(product, themeProvider, existingIndex >= 0 ? existingIndex : null);
      return;
    }

    final availableStock = (product['stock'] as num).toInt();
    final existingIndex = _cartItems.indexWhere((item) => item['id'] == product['id']);
    final currentQtyInCart = existingIndex >= 0 ? (_cartItems[existingIndex]['qty'] as num).toInt() : 0;

    if (!themeProvider.allowNegativeStock && (currentQtyInCart + 1) > availableStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Out of stock! (${product['name']}).',
          ),
          backgroundColor: Colors.red.shade800,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final stockRate = (product['price'] as num).toDouble();

    setState(() {
      if (existingIndex >= 0) {
        _cartItems[existingIndex]['qty'] += 1;
      } else {
        _cartItems.add({
          'id': product['id'],
          'name': product['name'],
          'price': stockRate,
          'stockRate': stockRate,
          'unit': product['unit'],
          'qty': 1,
          'isLoose': false,
        });
      }
    });
  }

  void _updateQuantity(int index, dynamic delta, TenantThemeProvider themeProvider) {
    final item = _cartItems[index];
    final unit = (item['unit']?.toString() ?? '').toLowerCase();
    final isLoose = item['isLoose'] == true || ['kg', 'g', 'gm', 'ltr', 'ml'].contains(unit);

    if (isLoose && delta != null && delta is! num) {
      final prodIndex = _availableProducts.indexWhere((p) => p['id'] == item['id']);
      final prod = prodIndex >= 0 ? _availableProducts[prodIndex] : item;
      _showLooseItemQuantityDialog(prod, themeProvider, index);
      return;
    }

    if (delta is num && delta > 0 && !themeProvider.allowNegativeStock) {
      final cartItem = _cartItems[index];
      final prodIndex = _availableProducts.indexWhere((p) => p['id'] == cartItem['id']);
      if (prodIndex >= 0) {
        final availableStock = (_availableProducts[prodIndex]['stock'] as num).toInt();
        final currentQty = (cartItem['qty'] as num).toInt();
        if (currentQty + delta > availableStock) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Cannot add more. Low stock guard active!'),
              backgroundColor: Colors.red.shade800,
              duration: const Duration(seconds: 2),
            ),
          );
          return;
        }
      }
    }

    setState(() {
      if (delta is num) {
        _cartItems[index]['qty'] += delta;
        if (_cartItems[index]['qty'] <= 0) {
          _cartItems.removeAt(index);
        }
      }
    });
  }

  void _showInvoiceReceiptModal({
    required BuildContext context,
    required bool isHindi,
    required TenantThemeProvider themeProvider,
    required String invoiceNo,
    required String customerName,
    required String customerPhone,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double taxAmount,
    double discountAmount = 0.0,
    required double grandTotal,
    required String paymentMode,
  }) {
    final String initialPhone = (customerPhone.isNotEmpty && customerPhone != '9876543210')
        ? customerPhone
        : (_customerPhoneMap[customerName] ?? '');
    final phoneCtrl = TextEditingController(text: initialPhone);

    bool isPrintingAction = false;
    bool isSendingWhatsApp = false;

    final calcDisc = discountAmount > 0.001
        ? discountAmount
        : (((subtotal + taxAmount) - grandTotal) > 0.001 ? ((subtotal + taxAmount) - grandTotal) : 0.0);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          if (phoneCtrl.text.isEmpty && customerName != 'Walk-in Customer') {
            Future.microtask(() async {
              try {
                final syncProvider = Provider.of<SyncProvider>(context, listen: false);
                final customers = await syncProvider.fetchCustomers();
                var matched = customers.firstWhere(
                  (c) => (c['name'] ?? '').toString().trim().toLowerCase() == customerName.trim().toLowerCase(),
                  orElse: () => {},
                );
                if (matched.isEmpty) {
                  final dbCusts = await SQLiteHelper.instance.getCustomers();
                  matched = dbCusts.firstWhere(
                    (c) => (c['name'] ?? '').toString().trim().toLowerCase() == customerName.trim().toLowerCase(),
                    orElse: () => {},
                  );
                }
                final p = (matched['phone'] ?? matched['mobile'] ?? '').toString().trim();
                if (p.isNotEmpty && phoneCtrl.text.isEmpty && modalCtx.mounted) {
                  phoneCtrl.text = p;
                  _customerPhoneMap[customerName] = p;
                  setModalState(() {});
                }
              } catch (_) {}
            });
          }

          return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Stack(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.red, size: 26),
                  tooltip: isHindi ? 'बंद करें' : 'Close Invoice',
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
              Center(
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
                    const SizedBox(height: 4),
                    Text(
                      isHindi ? 'बिल सहेजा गया & तैयार!' : 'Sale Completed Successfully!',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    Text(
                      invoiceNo,
                      style: const TextStyle(fontSize: 13, color: Colors.blue, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isHindi ? 'ग्राहक:' : 'Customer:', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isHindi ? 'भुगतान मोड़:' : 'Payment Mode:', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        paymentMode,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: paymentMode == 'Udhaar' ? Colors.red.shade700 : Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(isHindi ? 'सामान विवरण:' : 'Purchased Items:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      children: items.map((it) {
                        final name = (it['productName'] ?? it['name'] ?? 'Item').toString();
                        final qty = it['qty'] ?? it['quantity'] ?? 1;
                        final price = ((it['price'] ?? it['unitPrice'] ?? it['rate'] ?? 0.0) as num).toDouble();
                        final tot = ((it['total'] ?? it['totalAmount'] ?? (qty * price)) as num).toDouble();
                        final stockRate = (it['stockRate'] as num?)?.toDouble() ?? price;
                        final isMod = (price - stockRate).abs() > 0.001;
                        final unit = (it['unit'] ?? 'pcs').toString();
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(text: '$qty $unit × $name '),
                                      TextSpan(
                                        text: '(@ ₹${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)})',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: isMod ? FontWeight.bold : FontWeight.w500,
                                          color: isMod ? Colors.amber.shade900 : Colors.blueGrey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              Text('₹ ${tot.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(isHindi ? 'सकल योग (Gross Subtotal):' : 'Gross Subtotal:', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                            Text('₹ ${(subtotal > 0 ? subtotal : (grandTotal + calcDisc)).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        if (calcDisc > 0.001) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(isHindi ? 'छूट / डिस्काउंट:' : 'Discount / Off:', style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                              Text('- ₹ ${calcDisc.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                            ],
                          ),
                        ],
                        if (taxAmount > 0.001) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(isHindi ? 'टैक्स (GST):' : 'Tax / GST:', style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                              Text('+ ₹ ${taxAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                            ],
                          ),
                        ],
                        const Divider(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(isHindi ? 'कुल देय राशि:' : 'Net Grand Total:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(
                              '₹ ${grandTotal.toStringAsFixed(2)}',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.green.shade800),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  Text(
                    isHindi ? 'व्हाट्सएप रसीद भेजें:' : 'Send WhatsApp Invoice Receipt:',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: isHindi ? 'मोबाइल नंबर' : 'Mobile Number',
                      prefixIcon: const Icon(Icons.phone, color: Colors.green),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Row 1: Print Action
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: isPrintingAction
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.print_rounded, size: 18),
                    label: Text(
                      isPrintingAction ? (isHindi ? 'लोड हो रहा है...' : 'Opening...') : (isHindi ? 'प्रिंट रसीद (Print Bill)' : 'Print Receipt'),
                    ),
                    onPressed: isPrintingAction
                        ? null
                        : () {
                            setModalState(() => isPrintingAction = true);
                            try {
                              InvoicePrinter.showPrintPreviewModal(
                                context,
                                tenantName: themeProvider.tenantName,
                                appTitle: themeProvider.appTitle,
                                logoUrl: themeProvider.logoUrl,
                                supportPhone: themeProvider.supportPhone,
                                invoiceNo: invoiceNo,
                                customerName: customerName,
                                customerPhone: phoneCtrl.text.trim(),
                                paymentMode: paymentMode,
                                createdAt: DateTime.now().toString().split('.')[0],
                                subtotal: subtotal > 0 ? subtotal : (grandTotal + calcDisc),
                                taxAmount: taxAmount,
                                discountAmount: calcDisc,
                                grandTotal: grandTotal,
                                items: items,
                              );
                            } finally {
                              if (modalCtx.mounted) {
                                setModalState(() => isPrintingAction = false);
                              }
                            }
                          },
                  ),
                ),
                const SizedBox(height: 8),

                // Row 2: WhatsApp Share Options (Both Free Direct App & Server Cloud API)
                Row(
                  children: [
                    // Option 1: WhatsApp App (Free & Unlimited Auto-fill)
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                        ),
                        icon: const Icon(Icons.chat_rounded, size: 17),
                        label: Text(
                          isHindi ? 'व्हाट्सएप ऐप (फ़्री)' : 'WhatsApp App',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        onPressed: () {
                          final cleanPhone = phoneCtrl.text.trim();
                          if (cleanPhone.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter customer mobile number')),
                            );
                            return;
                          }
                          final calcDisc = discountAmount > 0.001 ? discountAmount : ((subtotal + taxAmount) - grandTotal);
                          final messageText = WhatsAppHelper.formatInvoiceMessage(
                            tenantName: themeProvider.tenantName,
                            invoiceNo: invoiceNo,
                            customerName: customerName,
                            paymentMode: paymentMode,
                            createdAt: DateTime.now().toString().split('.')[0],
                            subtotal: subtotal > 0 ? subtotal : grandTotal,
                            discountAmount: calcDisc > 0.001 ? calcDisc : 0.0,
                            taxAmount: taxAmount,
                            grandTotal: grandTotal,
                            items: items,
                          );
                          WhatsAppHelper.openWhatsApp(
                            context: context,
                            phone: cleanPhone,
                            message: messageText,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Option 2: Server Cloud API (Green API Direct)
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                        ),
                        icon: isSendingWhatsApp
                            ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.cloud_upload_rounded, size: 17),
                        label: Text(
                          isSendingWhatsApp
                              ? (isHindi ? 'भेज रहा है...' : 'Sending...')
                              : (isHindi ? 'क्लाउड API' : 'Cloud API'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        onPressed: isSendingWhatsApp
                            ? null
                            : () async {
                                final cleanPhone = phoneCtrl.text.trim();
                                if (cleanPhone.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter a valid customer mobile number')),
                                  );
                                  return;
                                }
                                setModalState(() => isSendingWhatsApp = true);

                                final calcDisc = discountAmount > 0.001 ? discountAmount : ((subtotal + taxAmount) - grandTotal);
                                final messageText = WhatsAppHelper.formatInvoiceMessage(
                                  tenantName: themeProvider.tenantName,
                                  invoiceNo: invoiceNo,
                                  customerName: customerName,
                                  paymentMode: paymentMode,
                                  createdAt: DateTime.now().toString().split('.')[0],
                                  subtotal: subtotal > 0 ? subtotal : grandTotal,
                                  discountAmount: calcDisc > 0.001 ? calcDisc : 0.0,
                                  taxAmount: taxAmount,
                                  grandTotal: grandTotal,
                                  items: items,
                                );

                                try {
                                  await WhatsAppHelper.sendCloudWhatsApp(
                                    context: context,
                                    phone: cleanPhone,
                                    message: messageText,
                                  );
                                } finally {
                                  if (modalCtx.mounted) {
                                    setModalState(() => isSendingWhatsApp = false);
                                  }
                                }
                              },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Row 3: New Bill Action
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeProvider.buttonBgColor,
                      foregroundColor: themeProvider.buttonTextColor,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                    },
                    child: Text(
                      isHindi ? '+ नया बिल बनाएँ' : '+ New Bill',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final isHindi = Provider.of<LocaleProvider>(context).isHindi;
    final themeProvider = Provider.of<TenantThemeProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Set<String> categorySet = {'All'};
    for (final p in _availableProducts) {
      final cat = (p['category']?.toString() ?? '').trim();
      if (cat.isNotEmpty) {
        categorySet.add(cat);
      }
    }
    final categories = categorySet.toList();
    categories.remove('All');
    categories.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    categories.insert(0, 'All');

    final cleanQuery = _searchQuery.trim().toLowerCase();
    final filteredProducts = _availableProducts.where((p) {
      final matchesCat = _selectedCategory == 'All' ||
          (p['category']?.toString().trim().toLowerCase() == _selectedCategory.toLowerCase());
      if (!matchesCat) return false;

      if (cleanQuery.isEmpty) return true;

      final name = p['name']?.toString().toLowerCase() ?? '';
      final category = p['category']?.toString().toLowerCase() ?? '';
      final brand = p['brand']?.toString().toLowerCase() ?? '';
      final barcode = p['barcode']?.toString().toLowerCase() ?? '';
      final productCode = p['productCode']?.toString().toLowerCase() ?? '';
      final batch = p['batchNumber']?.toString().toLowerCase() ?? '';
      final rack = p['rackNumber']?.toString().toLowerCase() ?? '';

      return name.contains(cleanQuery) ||
          category.contains(cleanQuery) ||
          brand.contains(cleanQuery) ||
          barcode.contains(cleanQuery) ||
          productCode.contains(cleanQuery) ||
          batch.contains(cleanQuery) ||
          rack.contains(cleanQuery);
    }).toList();

    final taxAmount = themeProvider.enableTaxCalculation
        ? _subtotal * (themeProvider.defaultTaxPercent / 100.0)
        : 0.0;
    final grandTotal = _subtotal + taxAmount;

    return Scaffold(
      backgroundColor: themeProvider.pageBgColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(
          isHindi ? 'नया बिल' : 'New Bill',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _cartItems.isNotEmpty,
              label: Text('${_cartItems.length}'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            tooltip: isHindi ? 'कार्ट देखें व दर बदलें' : 'View & Edit Cart Rates',
            onPressed: _cartItems.isEmpty ? null : () => _showCartDetailsSheet(themeProvider),
          ),
          IconButton(
            icon: const Icon(Icons.cleaning_services_rounded),
            tooltip: 'Clear Cart',
            onPressed: _cartItems.isEmpty
                ? null
                : () {
                    setState(() {
                      _cartItems.clear();
                    });
                  },
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              // Customer & Payment Method Selector Header
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.white,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: PaginatedServerDropdown.customers(
                            label: isHindi ? 'ग्राहक' : 'Customer',
                            hint: isHindi ? 'ग्राहक चुनें' : 'Select Customer',
                            selectedId: _customerIdMap[_selectedCustomer],
                            selectedTitle: _selectedCustomer,
                            includeWalkIn: true,
                            allowClear: true,
                            prefixIcon: const Icon(Icons.person_rounded, size: 20),
                            onChanged: (cust, id, title) {
                              setState(() {
                                if (title == null || title.isEmpty || id == null || id == 0 || title == 'Walk-in Customer') {
                                  _selectedCustomer = 'Walk-in Customer';
                                  _customerPhoneController.text = '';
                                } else {
                                  _selectedCustomer = title;
                                  final phone = (cust?['phone'] ?? cust?['mobile'] ?? '').toString();
                                  _customerPhoneController.text = phone;
                                  _customerIdMap[title] = id;
                                  _customerPhoneMap[title] = phone;
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeProvider.buttonBgColor,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                          onPressed: () {
                            _showAddCustomerDialog(context, isHindi);
                          },
                          child: Icon(Icons.person_add_rounded, color: themeProvider.buttonTextColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _customerPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: isHindi ? 'ग्राहक मोबाइल नंबर' : 'Customer Phone Number',
                        hintText: _selectedCustomer == 'Walk-in Customer' ? 'Type mobile number (optional)' : 'Auto-filled from master',
                        prefixIcon: const Icon(Icons.phone_rounded, size: 18, color: Colors.green),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 10),

                  ],
                ),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: isHindi ? 'सामान, ब्रांड या बारकोड खोजें...' : 'Search items, brand or barcode...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: themeProvider.cardBgColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: themeProvider.textColor.withOpacity(0.1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: themeProvider.textColor.withOpacity(0.12)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: themeProvider.buttonBgColor, width: 1.5),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                  },
                ),
              ),

              // Category Filter Chips (Flipkart / Amazon Style)
              if (categories.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (ctx, idx) {
                        final cat = categories[idx];
                        final isSelected = _selectedCategory.toLowerCase() == cat.toLowerCase();
                        return FilterChip(
                          showCheckmark: false,
                          avatar: isSelected
                              ? Icon(
                                  cat == 'All' ? Icons.apps_rounded : Icons.check_circle_rounded,
                                  size: 14,
                                  color: themeProvider.buttonTextColor,
                                )
                              : null,
                          label: Text(
                            cat,
                            style: TextStyle(
                              fontFamily: themeProvider.fontFamily,
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected
                                  ? themeProvider.buttonTextColor
                                  : themeProvider.textColor.withOpacity(0.85),
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() {
                              _selectedCategory = cat;
                            });
                          },
                          backgroundColor: themeProvider.cardBgColor,
                          selectedColor: themeProvider.buttonBgColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected
                                  ? themeProvider.buttonBgColor
                                  : (isDark ? Colors.white24 : Colors.grey.shade300),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        );
                      },
                    ),
                  ),
                ),

              // Product Catalog Grid (Flipkart/Amazon-Inspired)
              Expanded(
                flex: 5,
                child: filteredProducts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 54, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              isHindi ? 'कोई सामान नहीं मिला' : 'No products found',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: themeProvider.textColor.withOpacity(0.8),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isHindi
                                  ? 'फ़िल्टर या खोज बदल कर देखें'
                                  : 'Try adjusting your search or category filter',
                              style: TextStyle(
                                fontSize: 12,
                                color: themeProvider.textColor.withOpacity(0.5),
                              ),
                            ),
                            if (_searchQuery.isNotEmpty || _selectedCategory != 'All') ...[
                              const SizedBox(height: 14),
                              OutlinedButton.icon(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                    _selectedCategory = 'All';
                                  });
                                },
                                icon: const Icon(Icons.refresh_rounded, size: 16),
                                label: Text(isHindi ? 'फ़िल्टर हटाएं' : 'Reset Filters'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: themeProvider.buttonBgColor,
                                  side: BorderSide(color: themeProvider.buttonBgColor),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (ctx, constraints) {
                          int crossAxisCount = 2;
                          if (constraints.maxWidth >= 1050) {
                            crossAxisCount = 5;
                          } else if (constraints.maxWidth >= 800) {
                            crossAxisCount = 4;
                          } else if (constraints.maxWidth >= 550) {
                            crossAxisCount = 3;
                          } else {
                            crossAxisCount = 2;
                          }

                          return GridView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              mainAxisExtent: 176,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: filteredProducts.length,
                            itemBuilder: (ctx, index) {
                              final product = filteredProducts[index];
                              final cartIndex = _cartItems.indexWhere((item) => item['id'] == product['id']);
                              final bool isInCart = cartIndex >= 0;
                              final num qtyInCart = isInCart ? _cartItems[cartIndex]['qty'] : 0;
                              final unit = (product['unit']?.toString() ?? 'pcs').toLowerCase();
                              final isLoose = product['isLoose'] == true || ['kg', 'g', 'gm', 'ltr', 'ml'].contains(unit);
                              final double price = (product['price'] as num?)?.toDouble() ?? 0.0;
                              final double mrp = (product['mrp'] as num?)?.toDouble() ?? 0.0;
                              final int stock = (product['stock'] as num?)?.toInt() ?? 0;
                              final int minStock = (product['minimumStock'] as num?)?.toInt() ?? 5;
                              final String brand = (product['brand']?.toString() ?? '').trim();
                              final String imgUrl = product['imageUrl']?.toString() ?? '';
                              final String barcode = product['barcode']?.toString() ?? '';
                              final hasDiscount = mrp > price && mrp > 0;
                              final int discountPercent = hasDiscount ? (((mrp - price) / mrp) * 100).round() : 0;
                              final isOutOfStock = !themeProvider.allowNegativeStock && stock <= 0;
                              final isLowStock = !isOutOfStock && stock > 0 && stock <= minStock;

                              return InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () {
                                  if (isLoose) {
                                    _showLooseItemQuantityDialog(product, themeProvider, isInCart ? cartIndex : null);
                                  } else {
                                    _addToCart(product, themeProvider);
                                  }
                                },
                                onLongPress: () {
                                  if (isLoose) {
                                    _showLooseItemQuantityDialog(product, themeProvider, isInCart ? cartIndex : null);
                                  } else if (isInCart) {
                                    _showEditCartItemDialog(cartIndex, themeProvider);
                                  } else {
                                    _addToCart(product, themeProvider);
                                    final newIdx = _cartItems.indexWhere((it) => it['id'] == product['id']);
                                    if (newIdx >= 0) {
                                      _showEditCartItemDialog(newIdx, themeProvider);
                                    }
                                  }
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: themeProvider.cardBgColor,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isInCart
                                          ? themeProvider.buttonBgColor
                                          : (isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade300),
                                      width: isInCart ? 1.6 : 1.0,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isInCart
                                            ? themeProvider.buttonBgColor.withOpacity(0.08)
                                            : Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Top Image Box (Compact: 68px, no wasted space)
                                      Container(
                                        height: 68,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFF8FAFC),
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                                        ),
                                        child: Stack(
                                          children: [
                                            Center(
                                              child: Padding(
                                                padding: const EdgeInsets.all(4.0),
                                                child: _buildProductThumbnail(imgUrl, height: 60, fit: BoxFit.contain),
                                              ),
                                            ),
                                            // Discount Badge (Top Left)
                                            if (hasDiscount && discountPercent > 0)
                                              Positioned(
                                                top: 4,
                                                left: 4,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF16A34A),
                                                    borderRadius: BorderRadius.circular(3),
                                                  ),
                                                  child: Text(
                                                    '$discountPercent% OFF',
                                                    style: const TextStyle(
                                                      fontSize: 8.5,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            // Loose / Out of stock Badge (Top Right)
                                            Positioned(
                                              top: 4,
                                              right: 4,
                                              child: isLoose
                                                  ? Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                                      decoration: BoxDecoration(
                                                        color: Colors.orange.shade700,
                                                        borderRadius: BorderRadius.circular(3),
                                                      ),
                                                      child: const Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(Icons.scale_rounded, size: 8, color: Colors.white),
                                                          SizedBox(width: 2),
                                                          Text(
                                                            'Loose',
                                                            style: TextStyle(
                                                              fontSize: 8,
                                                              fontWeight: FontWeight.bold,
                                                              color: Colors.white,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    )
                                                  : (isOutOfStock
                                                      ? Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                                          decoration: BoxDecoration(
                                                            color: Colors.red.shade700,
                                                            borderRadius: BorderRadius.circular(3),
                                                          ),
                                                          child: const Text(
                                                            'Out',
                                                            style: TextStyle(
                                                              fontSize: 8,
                                                              fontWeight: FontWeight.bold,
                                                              color: Colors.white,
                                                            ),
                                                          ),
                                                        )
                                                      : const SizedBox.shrink()),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Bottom Details Box (Compact, high-density POS layout)
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(7, 4, 7, 6),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              // Title, Brand & Unit
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  if (brand.isNotEmpty)
                                                    Text(
                                                      brand.toUpperCase(),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 8.5,
                                                        fontWeight: FontWeight.w600,
                                                        letterSpacing: 0.4,
                                                        color: themeProvider.textColor.withOpacity(0.5),
                                                      ),
                                                    ),
                                                  Text(
                                                    product['name'] ?? '',
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontFamily: themeProvider.fontFamily,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 11.5 * themeProvider.fontSizeScale,
                                                      height: 1.15,
                                                      color: themeProvider.textColor,
                                                    ),
                                                  ),
                                                  if (barcode.isNotEmpty)
                                                    Text(
                                                      '║▌$barcode',
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 8,
                                                        fontFamily: 'monospace',
                                                        color: Colors.purple,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                ],
                                              ),

                                              // Bottom Row: [Price + Stock Qty] on Left, [Compact Add Button/Stepper] on Right
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  // Price, MRP & Available Stock
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Row(
                                                          crossAxisAlignment: CrossAxisAlignment.baseline,
                                                          textBaseline: TextBaseline.alphabetic,
                                                          children: [
                                                            Flexible(
                                                              child: FittedBox(
                                                                fit: BoxFit.scaleDown,
                                                                alignment: Alignment.centerLeft,
                                                                child: Text(
                                                                  '${themeProvider.currencySymbol}$price',
                                                                  style: TextStyle(
                                                                    fontFamily: themeProvider.fontFamily,
                                                                    fontSize: 13.5 * themeProvider.fontSizeScale,
                                                                    fontWeight: FontWeight.w800,
                                                                    color: themeProvider.amountColor,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            if (hasDiscount) ...[
                                                              const SizedBox(width: 3),
                                                              Text(
                                                                '${themeProvider.currencySymbol}$mrp',
                                                                style: TextStyle(
                                                                  fontSize: 9.5,
                                                                  color: themeProvider.textColor.withOpacity(0.4),
                                                                  decoration: TextDecoration.lineThrough,
                                                                ),
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                        const SizedBox(height: 1),
                                                        Text(
                                                          isOutOfStock
                                                              ? 'Out of stock'
                                                              : 'Stock: $stock $unit',
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: TextStyle(
                                                            fontSize: 9,
                                                            fontWeight: (stock <= minStock || isOutOfStock)
                                                                ? FontWeight.bold
                                                                : FontWeight.w500,
                                                            color: isOutOfStock
                                                                ? Colors.red.shade700
                                                                : (stock <= minStock
                                                                    ? Colors.amber.shade900
                                                                    : (isDark
                                                                        ? Colors.greenAccent.shade200
                                                                        : Colors.green.shade700)),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),

                                                  // Compact Add Button or Inline Stepper
                                                  if (!isInCart)
                                                    SizedBox(
                                                      height: 25,
                                                      child: ElevatedButton(
                                                        onPressed: isOutOfStock
                                                            ? null
                                                            : () {
                                                                if (isLoose) {
                                                                  _showLooseItemQuantityDialog(product, themeProvider);
                                                                } else {
                                                                  _addToCart(product, themeProvider);
                                                                }
                                                              },
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: isOutOfStock
                                                              ? Colors.grey.shade300
                                                              : themeProvider.buttonBgColor,
                                                          foregroundColor: isOutOfStock
                                                              ? Colors.grey.shade600
                                                              : themeProvider.buttonTextColor,
                                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 0),
                                                          elevation: 0,
                                                          minimumSize: const Size(44, 25),
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.circular(5),
                                                          ),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                              isLoose ? Icons.scale_rounded : Icons.add_rounded,
                                                              size: 13,
                                                            ),
                                                            const SizedBox(width: 2),
                                                            Text(
                                                              isOutOfStock ? 'OUT' : 'ADD',
                                                              style: const TextStyle(
                                                                fontSize: 10,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    )
                                                  else
                                                    Container(
                                                      height: 25,
                                                      decoration: BoxDecoration(
                                                        color: themeProvider.buttonBgColor,
                                                        borderRadius: BorderRadius.circular(5),
                                                      ),
                                                      child: isLoose
                                                          ? InkWell(
                                                              onTap: () => _showLooseItemQuantityDialog(product, themeProvider, cartIndex),
                                                              child: Padding(
                                                                padding: const EdgeInsets.symmetric(horizontal: 5),
                                                                child: Row(
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  children: [
                                                                    Icon(Icons.scale_rounded, size: 11, color: themeProvider.buttonTextColor),
                                                                    const SizedBox(width: 2),
                                                                    Text(
                                                                      '${qtyInCart.toStringAsFixed(qtyInCart.truncateToDouble() == qtyInCart ? 0 : 2)} $unit',
                                                                      style: TextStyle(
                                                                        fontSize: 10,
                                                                        fontWeight: FontWeight.bold,
                                                                        color: themeProvider.buttonTextColor,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(width: 2),
                                                                    Icon(Icons.edit, size: 9, color: themeProvider.buttonTextColor.withOpacity(0.8)),
                                                                  ],
                                                                ),
                                                              ),
                                                            )
                                                          : Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                InkWell(
                                                                  onTap: () => _updateQuantity(cartIndex, -1, themeProvider),
                                                                  child: Container(
                                                                    width: 22,
                                                                    height: 25,
                                                                    alignment: Alignment.center,
                                                                    child: Icon(Icons.remove, size: 12, color: themeProvider.buttonTextColor),
                                                                  ),
                                                                ),
                                                                Padding(
                                                                  padding: const EdgeInsets.symmetric(horizontal: 3),
                                                                  child: Text(
                                                                    '$qtyInCart',
                                                                    style: TextStyle(
                                                                      fontSize: 11,
                                                                      fontWeight: FontWeight.bold,
                                                                      color: themeProvider.buttonTextColor,
                                                                    ),
                                                                  ),
                                                                ),
                                                                InkWell(
                                                                  onTap: () => _updateQuantity(cartIndex, 1, themeProvider),
                                                                  child: Container(
                                                                    width: 22,
                                                                    height: 25,
                                                                    alignment: Alignment.center,
                                                                    child: Icon(Icons.add, size: 12, color: themeProvider.buttonTextColor),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                    ),
                                                ],
                                              ),
                                            ],
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
                      ),
              ),

          // Cart Footer & Checkout Panel
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: themeProvider.cardBgColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, -4)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_cartItems.isNotEmpty)
                  SizedBox(
                    height: 42,
                    child: Row(
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          icon: const Icon(Icons.table_chart_outlined, size: 20, color: Colors.indigo),
                          tooltip: isHindi ? 'पूरी कार्ट देखें' : 'View Cart Table',
                          onPressed: () => _showCartDetailsSheet(themeProvider),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _cartItems.length,
                            separatorBuilder: (ctx, i) => const SizedBox(width: 6),
                            itemBuilder: (ctx, index) {
                              final item = _cartItems[index];
                              final rate = (item['price'] as num).toDouble();
                              final stockRate = (item['stockRate'] as num?)?.toDouble() ?? rate;
                              final isModified = (rate - stockRate).abs() > 0.001;

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isModified ? Colors.amber.shade50 : themeProvider.buttonBgColor.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isModified ? Colors.amber.shade600 : themeProvider.buttonBgColor.withOpacity(0.3),
                                    width: isModified ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    InkWell(
                                      onTap: () => _showEditCartItemDialog(index, themeProvider),
                                      child: Text(
                                        item['name'],
                                        style: TextStyle(
                                          fontFamily: themeProvider.fontFamily,
                                          fontSize: 12 * themeProvider.fontSizeScale,
                                          fontWeight: FontWeight.bold,
                                          color: themeProvider.textColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: () => _showEditCartItemDialog(index, themeProvider),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isModified ? Colors.amber.shade100 : Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: isModified ? Colors.amber.shade700 : Colors.blue.shade200,
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '₹${rate.toStringAsFixed(rate.truncateToDouble() == rate ? 0 : 2)}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isModified ? Colors.amber.shade900 : Colors.blue.shade900,
                                              ),
                                            ),
                                            const SizedBox(width: 3),
                                            Icon(
                                              Icons.edit,
                                              size: 11,
                                              color: isModified ? Colors.amber.shade900 : Colors.blue.shade700,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: () => _updateQuantity(index, -1, themeProvider),
                                      child: Icon(Icons.remove_circle_outline, size: 18, color: Colors.red.shade700),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                      child: Text(
                                        '${item["qty"]}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => _updateQuantity(index, 1, themeProvider),
                                      child: Icon(Icons.add_circle_outline, size: 18, color: Colors.green.shade700),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (themeProvider.enableTaxCalculation)
                          Text(
                            'Subtotal: ${themeProvider.currencySymbol}${_subtotal.toStringAsFixed(2)} | GST (${themeProvider.defaultTaxPercent}%): ${themeProvider.currencySymbol}${taxAmount.toStringAsFixed(2)}',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                          )
                        else
                          Text(
                            isHindi ? 'कुल योग' : 'Grand Total',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                        Text(
                          '${themeProvider.currencySymbol} ${grandTotal.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _selectedPaymentMode == 'Udhaar' ? Colors.red.shade700 : Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedPaymentMode == 'Udhaar' ? Colors.red.shade700 : themeProvider.buttonBgColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: Icon(Icons.receipt_long_rounded, color: themeProvider.buttonTextColor),
                        label: Text(
                          isHindi ? 'बिल सेव करें' : 'Complete Sale',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: themeProvider.buttonTextColor),
                        ),
                        onPressed: _cartItems.isEmpty
                            ? null
                            : () {
                                _showCheckoutPaymentModal(
                                  context: context,
                                  isHindi: isHindi,
                                  themeProvider: themeProvider,
                                  subtotal: _subtotal,
                                  taxAmount: taxAmount,
                                  grandTotal: grandTotal,
                                );
                              },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);
}

  void _showUpiPaymentScannerModal({
    required BuildContext context,
    required bool isHindi,
    required TenantThemeProvider themeProvider,
    required String invoiceNo,
    required String customerSnapshot,
    required String phoneSnapshot,
    required List<Map<String, dynamic>> cartSnapshot,
    required double subtotalSnapshot,
    required double taxSnapshot,
    required double discountSnapshot,
    required double netPayableSnapshot,
    required String modeSnapshot,
    required Function(String selectedUpiId, String selectedAccountName, String selectedBankName) onPaymentConfirmed,
  }) {
    final upiList = themeProvider.upiAccounts;
    String selectedUpiId = themeProvider.getDefaultUpiId();

    bool isConfirming = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final selectedAcc = upiList.firstWhere(
            (a) => (a['upiId'] ?? '').toString().toLowerCase() == selectedUpiId.toLowerCase(),
            orElse: () => {
              'upiId': selectedUpiId,
              'accountName': themeProvider.tenantName,
              'bankName': '',
              'label': 'Shop UPI',
            },
          );

          final selectedAccountName = (selectedAcc['accountName'] != null && selectedAcc['accountName'].toString().trim().isNotEmpty)
              ? selectedAcc['accountName'].toString().trim()
              : themeProvider.tenantName;
          final selectedBankName = (selectedAcc['bankName'] ?? '').toString().trim();

          final upiPayload = 'upi://pay?pa=$selectedUpiId&pn=${Uri.encodeComponent(selectedAccountName)}&am=${netPayableSnapshot.toStringAsFixed(2)}&cu=INR&tn=Bill_$invoiceNo';
          final qrUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=240x240&data=${Uri.encodeComponent(upiPayload)}';

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.qr_code_scanner_rounded, color: Colors.indigo, size: 26),
                    const SizedBox(width: 8),
                    Text(
                      isHindi ? 'UPI भुगतान (Scan QR)' : 'UPI Scan & Pay',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Select Shop UPI ID Dropdown
                  if (upiList.length > 1) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.purple.shade200),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: upiList.any((a) => a['upiId'] == selectedUpiId) ? selectedUpiId : upiList.first['upiId'].toString(),
                          isExpanded: true,
                          items: upiList.map((a) {
                            final uid = (a['upiId'] ?? '').toString();
                            final lbl = (a['label'] ?? 'UPI Account').toString();
                            final acN = (a['accountName'] ?? '').toString();
                            final bN = (a['bankName'] ?? '').toString();
                            final displayName = '$lbl - ${acN.isNotEmpty ? acN : themeProvider.tenantName}${bN.isNotEmpty ? " ($bN)" : ""} ($uid)';
                            return DropdownMenuItem<String>(
                              value: uid,
                              child: Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() => selectedUpiId = val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    isHindi ? 'कृपया ग्राहक से QR कोड स्कैन करवा कर भुगतान लें:' : 'Ask customer to scan QR code to complete payment:',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.indigo.shade200, width: 1.5),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                    ),
                    child: Column(
                      children: [
                        Image.network(
                          qrUrl,
                          width: 200,
                          height: 200,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Container(
                            width: 200,
                            height: 200,
                            color: Colors.grey.shade100,
                            child: const Icon(Icons.qr_code_2_rounded, size: 80, color: Colors.indigo),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '₹ ${netPayableSnapshot.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                        const SizedBox(height: 4),
                        // Dynamic Account Name & Bank Name
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'A/c Name: $selectedAccountName',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black87),
                              ),
                              if (selectedBankName.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Bank: $selectedBankName',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                                ),
                              ],
                              const SizedBox(height: 2),
                              Text(
                                'UPI ID: $selectedUpiId',
                                style: const TextStyle(fontSize: 11, color: Colors.purple, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.account_balance_wallet_rounded, size: 16, color: Colors.indigo),
                      SizedBox(width: 4),
                      Text('GPay • PhonePe • Paytm • BHIM', style: TextStyle(fontSize: 11, color: Colors.indigo, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(isHindi ? 'रद्द करें' : 'Cancel'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: isConfirming
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_rounded, size: 20),
                label: Text(isConfirming ? 'Processing...' : (isHindi ? 'भुगतान प्राप्त हुआ (बिल बनाएं)' : 'Payment Done (Create Invoice)')),
                onPressed: isConfirming
                    ? null
                    : () {
                        setModalState(() => isConfirming = true);
                        Navigator.pop(ctx);
                        onPaymentConfirmed(selectedUpiId, selectedAccountName, selectedBankName);
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCheckoutPaymentModal({
    required BuildContext context,
    required bool isHindi,
    required TenantThemeProvider themeProvider,
    required double subtotal,
    required double taxAmount,
    required double grandTotal,
  }) {
    final discountCtrl = TextEditingController(text: '0');
    final paidCtrl = TextEditingController(text: grandTotal.toStringAsFixed(0));
    final cashCtrl = TextEditingController(text: (grandTotal / 2).toStringAsFixed(0));
    final upiCtrl = TextEditingController(text: (grandTotal / 2).toStringAsFixed(0));
    
    String selectedMode = _selectedPaymentMode;
    String? modalErrorMessage;
    bool isProcessingSale = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final masterProvider = Provider.of<MasterProvider>(context, listen: false);
            final masterModes = masterProvider.paymentModes.map((pm) => pm.masterName).where((name) {
              if (name.toLowerCase() == 'upi' && !themeProvider.enableOnlinePayment) return false;
              if (name.toLowerCase() == 'udhaar' && !themeProvider.enableUdhaar) return false;
              return true;
            }).toList();
            final availableModes = [
              ...masterModes.isEmpty ? ['Cash', if (themeProvider.enableOnlinePayment) 'UPI', if (themeProvider.enableUdhaar) 'Udhaar'] : masterModes,
              'Split',
            ].toSet().toList();

            final discount = double.tryParse(discountCtrl.text) ?? 0.0;
            final netPayable = (grandTotal - discount).clamp(0.0, double.infinity);
            
            double cashAmt = 0.0;
            double upiAmt = 0.0;
            double totalPaid = 0.0;
            double remainingUdhaar = 0.0;

            if (selectedMode == 'Udhaar') {
              totalPaid = 0.0;
              cashAmt = 0.0;
              upiAmt = 0.0;
              remainingUdhaar = netPayable;
            } else if (selectedMode == 'Split') {
              // Split Mode
              cashAmt = double.tryParse(cashCtrl.text) ?? 0.0;
              upiAmt = double.tryParse(upiCtrl.text) ?? 0.0;
              totalPaid = cashAmt + upiAmt;
              remainingUdhaar = (netPayable - totalPaid).clamp(0.0, double.infinity);
            } else {
              totalPaid = double.tryParse(paidCtrl.text) ?? netPayable;
              if (selectedMode == 'UPI') {
                cashAmt = 0.0;
                upiAmt = totalPaid;
              } else if (selectedMode == 'Cash') {
                cashAmt = totalPaid;
                upiAmt = 0.0;
              } else {
                cashAmt = 0.0;
                upiAmt = 0.0;
              }
              remainingUdhaar = (netPayable - totalPaid).clamp(0.0, double.infinity);
            }

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
                          isHindi ? 'भुगतान एवं रसीद सेटलमेंट' : 'Payment Settlement & Bill Checkout',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: themeProvider.primaryColor),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(modalCtx)),
                      ],
                    ),
                    const Divider(),
                    if (modalErrorMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade400),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                modalErrorMessage!,
                                style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),

                    // Customer & Mode Info Header
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Customer: $_selectedCustomer', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text('Phone: ${_customerPhoneController.text.isEmpty ? "Walk-in" : _customerPhoneController.text}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: themeProvider.primaryColor.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                            child: Text(selectedMode.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.primaryColor, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Payment Mode Selection Chips Inside Modal
                    const Text('Select Payment Mode:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: availableModes.map((m) {
                        final isSelected = selectedMode == m;
                        return ChoiceChip(
                          label: Text(
                            m == 'Udhaar' ? (isHindi ? 'उधार' : 'Udhaar') : (m == 'Split' ? (isHindi ? 'मिक्स (Cash+UPI)' : 'Split Payment') : m),
                            style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87),
                          ),
                          selected: isSelected,
                          selectedColor: m == 'Udhaar' ? Colors.red.shade700 : (m == 'Split' ? Colors.purple.shade700 : themeProvider.buttonBgColor),
                          onSelected: (val) {
                            if (val) {
                              setModalState(() {
                                selectedMode = m;
                                _selectedPaymentMode = m;
                                if (m == 'Udhaar') {
                                  paidCtrl.text = '0';
                                } else if (m == 'Split') {
                                  cashCtrl.text = (netPayable / 2).toStringAsFixed(0);
                                  upiCtrl.text = (netPayable - (double.tryParse(cashCtrl.text) ?? 0)).toStringAsFixed(0);
                                } else {
                                  paidCtrl.text = netPayable.toStringAsFixed(0);
                                }
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Amount Breakdown
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Subtotal: ₹${subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13)),
                        if (taxAmount > 0) Text('GST: ₹${taxAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Round Off & Discount Field
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: discountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: isHindi ? 'छूट / राउंड ऑफ' : 'Discount / Round Off (₹)',
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            onChanged: (val) {
                              setModalState(() {
                                final d = double.tryParse(val) ?? 0.0;
                                final net = (grandTotal - d).clamp(0.0, double.infinity);
                                if (selectedMode == 'Split') {
                                  cashCtrl.text = (net / 2).toStringAsFixed(0);
                                  upiCtrl.text = (net - (double.tryParse(cashCtrl.text) ?? 0)).toStringAsFixed(0);
                                } else if (selectedMode != 'Udhaar') {
                                  paidCtrl.text = net.toStringAsFixed(0);
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () {
                            setModalState(() {
                              final roundTotal = grandTotal.floorToDouble();
                              final autoDiscount = grandTotal - roundTotal;
                              discountCtrl.text = autoDiscount.toStringAsFixed(2);
                              if (selectedMode == 'Split') {
                                cashCtrl.text = (roundTotal / 2).toStringAsFixed(0);
                                upiCtrl.text = (roundTotal - (double.tryParse(cashCtrl.text) ?? 0)).toStringAsFixed(0);
                              } else if (selectedMode != 'Udhaar') {
                                paidCtrl.text = roundTotal.toStringAsFixed(0);
                              }
                            });
                          },
                          child: Text(isHindi ? 'राउंड ऑफ ₹${grandTotal.floor()}' : 'Round to ₹${grandTotal.floor()}'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Dynamic Payment Amount Inputs based on Mode
                    if (selectedMode != 'Udhaar' && selectedMode != 'Split') ...[
                      TextField(
                        controller: paidCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: isHindi ? 'प्राप्त राशि (${selectedMode})' : 'Amount Paid by Customer (${selectedMode} ₹)',
                          border: const OutlineInputBorder(),
                          prefixIcon: Icon(selectedMode == 'UPI' ? Icons.qr_code_rounded : Icons.payments_rounded, color: Colors.green),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        onChanged: (_) => setModalState(() {}),
                      ),
                      const SizedBox(height: 14),
                    ] else if (selectedMode == 'Split') ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: cashCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Cash Received (₹)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.money_rounded, color: Colors.green),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              ),
                              onChanged: (_) => setModalState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: upiCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'UPI Received (₹)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.qr_code_2_rounded, color: Colors.indigo),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              ),
                              onChanged: (_) => setModalState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Net Payable & Udhaar Notice Banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: remainingUdhaar > 0 ? Colors.red.shade50 : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: remainingUdhaar > 0 ? Colors.red.shade200 : Colors.green.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(isHindi ? 'नेट देय राशि:' : 'Net Payable Total:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text('₹ ${netPayable.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: themeProvider.primaryColor)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(isHindi ? 'कुल प्राप्त राशि:' : 'Total Received:', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              Text('₹ ${totalPaid.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)),
                            ],
                          ),
                          if (remainingUdhaar > 0) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.info_outline, size: 16, color: Colors.red),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    isHindi
                                        ? 'नोट: ₹ ${remainingUdhaar.toStringAsFixed(2)} बकाया ग्राहक (${_selectedCustomer}) के उधार खाते में जुड़ जाएगा।'
                                        : 'Notice: Remaining ₹ ${remainingUdhaar.toStringAsFixed(2)} will be added to Customer (${_selectedCustomer}) Udhaar ledger balance.',
                                    style: TextStyle(fontSize: 11, color: Colors.red.shade900, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: remainingUdhaar > 0 ? Colors.red.shade700 : themeProvider.buttonBgColor,
                          foregroundColor: themeProvider.buttonTextColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: isProcessingSale
                            ? null
                            : () async {
                                final customerSnapshot = _selectedCustomer;

                                // Validation: Walk-in Customer Udhaar Protection
                                if (customerSnapshot == 'Walk-in Customer' && (selectedMode == 'Udhaar' || remainingUdhaar > 0.001)) {
                                  final errMsg = isHindi
                                      ? 'Walk-in (बिना पंजीकृत ग्राहक) को उधार पर सामान नहीं बेचा जा सकता! कृपया ग्राहक चुनें।'
                                      : 'Udhaar / Credit sale is not allowed for Walk-in Customer! Please select or add a registered customer.';
                                  setModalState(() {
                                    isProcessingSale = false;
                                    modalErrorMessage = errMsg;
                                  });
                                  ToastHelper.showError(context, errMsg);
                                  return;
                                }

                                Future<void> executeSaleInsertion([String? upiIdUsed, String? acNameUsed, String? bNameUsed]) async {
                                  setModalState(() {
                                    isProcessingSale = true;
                                    modalErrorMessage = null;
                                  });

                                  try {
                                    final invoiceNo = 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
                                    final cartSnapshot = _cartItems.map((item) {
                                      final rawId = item['id'];
                                      final parsedId = rawId is num ? rawId.toInt() : (int.tryParse(rawId?.toString() ?? '') ?? 0);
                                      final qtyVal = (item['qty'] as num?)?.toDouble() ?? 1.0;
                                      final priceVal = (item['price'] as num?)?.toDouble() ?? 0.0;
                                      final stockRate = (item['stockRate'] as num?)?.toDouble() ?? priceVal;
                                      final isModified = (priceVal - stockRate).abs() > 0.001;
                                      final totalVal = priceVal * qtyVal;
                                      return {
                                        'id': parsedId > 0 ? parsedId : rawId,
                                        'productId': parsedId,
                                        'name': item['name'] ?? '',
                                        'productName': item['name'] ?? '',
                                        'price': priceVal,
                                        'rate': priceVal,
                                        'unitPrice': priceVal,
                                        'qty': qtyVal,
                                        'quantity': qtyVal,
                                        'total': totalVal,
                                        'totalAmount': totalVal,
                                        'stockRate': stockRate,
                                        'isRateModified': isModified,
                                        'unit': item['unit'] ?? 'pcs',
                                        'isLoose': item['isLoose'] ?? false,
                                      };
                                    }).toList();

                                    final subtotalSnapshot = subtotal;
                                    final taxSnapshot = taxAmount;
                                    final netPayableSnapshot = netPayable;
                                    final discountSnapshot = (subtotal + taxAmount - netPayable).clamp(0.0, double.infinity);
                                    final modeSnapshot = selectedMode;
                                    final customerSnapshot = _selectedCustomer;
                                    final phoneSnapshot = _customerPhoneController.text;

                                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                    final syncProvider = Provider.of<SyncProvider>(context, listen: false);
                                    final masterProvider = Provider.of<MasterProvider>(context, listen: false);

                                    final paymentsList = <Map<String, dynamic>>[];
                                    if (selectedMode == 'Split') {
                                      if (cashAmt > 0) {
                                        paymentsList.add({
                                          'paymentMode': 'Cash',
                                          'paymentModeId': masterProvider.getPaymentModeId('Cash'),
                                          'amount': cashAmt,
                                          'isReceived': true,
                                        });
                                      }
                                      if (upiAmt > 0) {
                                        paymentsList.add({
                                          'paymentMode': 'UPI',
                                          'paymentModeId': masterProvider.getPaymentModeId('UPI'),
                                          'amount': upiAmt,
                                          'upiIdUsed': upiIdUsed,
                                          'accountName': acNameUsed,
                                          'bankName': bNameUsed,
                                          'isReceived': true,
                                        });
                                      }
                                    } else if (selectedMode != 'Udhaar') {
                                      paymentsList.add({
                                        'paymentMode': modeSnapshot,
                                        'paymentModeId': masterProvider.getPaymentModeId(modeSnapshot),
                                        'amount': totalPaid,
                                        'upiIdUsed': modeSnapshot == 'UPI' ? upiIdUsed : null,
                                        'accountName': modeSnapshot == 'UPI' ? acNameUsed : null,
                                        'bankName': modeSnapshot == 'UPI' ? bNameUsed : null,
                                        'isReceived': true,
                                      });
                                    }
                                    if (remainingUdhaar > 0) {
                                      paymentsList.add({
                                        'paymentMode': 'Udhaar',
                                        'paymentModeId': masterProvider.getPaymentModeId('Udhaar'),
                                        'amount': remainingUdhaar,
                                        'isReceived': false,
                                      });
                                    }
                                    
                                    final rawCustId = _customerIdMap[customerSnapshot];
                                    var parsedCustId = rawCustId is num ? rawCustId.toInt() : int.tryParse(rawCustId?.toString() ?? '');

                                    if (parsedCustId == null && customerSnapshot != 'Walk-in Customer') {
                                      try {
                                        final allCust = await syncProvider.fetchCustomers();
                                        final matched = allCust.firstWhere(
                                          (c) => (c['name'] ?? '').toString().trim().toLowerCase() == customerSnapshot.trim().toLowerCase(),
                                          orElse: () => {},
                                        );
                                        if (matched['id'] != null) {
                                          final pId = int.tryParse(matched['id'].toString());
                                          if (pId != null && pId > 0) {
                                            parsedCustId = pId;
                                            _customerIdMap[customerSnapshot] = pId;
                                          }
                                        }
                                      } catch (_) {}
                                    }

                                    await syncProvider.saveOfflineSale({
                                      'clientTransactionId': invoiceNo,
                                      'tenantId': authProvider.tenantId,
                                      'tenantCode': authProvider.tenantCode,
                                      'customerId': parsedCustId,
                                      'customer': customerSnapshot,
                                      'customerName': customerSnapshot,
                                      'customerPhone': phoneSnapshot,
                                      'subtotal': subtotalSnapshot,
                                      'taxAmount': taxSnapshot,
                                      'discountAmount': discountSnapshot,
                                      'discount': discountSnapshot,
                                      'amount': netPayableSnapshot,
                                      'totalAmount': netPayableSnapshot,
                                      'paidAmount': totalPaid,
                                      'paymentMode': modeSnapshot,
                                      'paymentModeId': masterProvider.getPaymentModeId(modeSnapshot),
                                      'payments': paymentsList,
                                      'items': cartSnapshot,
                                      'createdAt': DateTime.now().toIso8601String(),
                                    });

                                    // Update Customer Record in local SQLite (both cash and udhaar transactions)
                                    if (customerSnapshot != 'Walk-in Customer') {
                                      try {
                                        final lastTxSummary = 'Invoice #$invoiceNo ($modeSnapshot: ₹${netPayableSnapshot.toStringAsFixed(0)})';
                                        final customersList = await SQLiteHelper.instance.getCustomers();
                                        final cust = customersList.firstWhere((c) => c['name'] == customerSnapshot, orElse: () => {});
                                        final currentBalance = (cust['udhaar'] as num?)?.toDouble() ?? 0.0;
                                        final newBalance = currentBalance + remainingUdhaar;
                                        await SQLiteHelper.instance.updateCustomerLastTx(
                                          customerSnapshot,
                                          lastTxSummary,
                                          remainingUdhaar > 0 ? newBalance : null,
                                        );
                                      } catch (_) {}
                                    }

                                    if (context.mounted) {
                                      setState(() {
                                        for (var cartItem in cartSnapshot) {
                                          final idx = _availableProducts.indexWhere((p) => p['id'] == cartItem['id'] || p['name'] == cartItem['name']);
                                          if (idx >= 0) {
                                            final current = (_availableProducts[idx]['stock'] as num).toDouble();
                                            final qty = (cartItem['qty'] as num).toDouble();
                                            _availableProducts[idx]['stock'] = (current - qty) < 0 ? 0 : (current - qty);
                                            // Update SQLite stock
                                            SQLiteHelper.instance.deductProductStock(_availableProducts[idx]['name'], qty);
                                          }
                                        }
                                        _cartItems.clear();
                                        _selectedCustomer = 'Walk-in Customer';
                                        _customerPhoneController.clear();
                                        _selectedPaymentMode = 'Cash';
                                      });

                                      Navigator.pop(modalCtx);

                                      _showInvoiceReceiptModal(
                                        context: context,
                                        isHindi: isHindi,
                                        themeProvider: themeProvider,
                                        invoiceNo: invoiceNo,
                                        customerName: customerSnapshot,
                                        customerPhone: phoneSnapshot,
                                        items: cartSnapshot,
                                        subtotal: subtotalSnapshot,
                                        taxAmount: taxSnapshot,
                                        discountAmount: discountSnapshot,
                                        grandTotal: netPayableSnapshot,
                                        paymentMode: modeSnapshot,
                                      );
                                    }
                                  } catch (e) {
                                    setModalState(() {
                                      isProcessingSale = false;
                                      modalErrorMessage = 'Failed to process sale: ${e.toString()}';
                                    });
                                  }
                                }

                                // If UPI payment is involved (Full UPI or Split with UPI > 0), show Scanner Modal FIRST!
                                if (upiAmt > 0) {
                                  final invoiceNo = 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
                                  final subtotalSnapshot = subtotal;
                                  final taxSnapshot = taxAmount;
                                  final discountSnapshot = (subtotal + taxAmount - netPayable).clamp(0.0, double.infinity);
                                  final phoneSnapshot = _customerPhoneController.text;
                                  final cartSnapshot = _cartItems.map((item) {
                                    final rawId = item['id'];
                                    final parsedId = rawId is num ? rawId.toInt() : (int.tryParse(rawId?.toString() ?? '') ?? 0);
                                    final qtyVal = (item['qty'] as num?)?.toDouble() ?? 1.0;
                                    final priceVal = (item['price'] as num?)?.toDouble() ?? 0.0;
                                    final stockRate = (item['stockRate'] as num?)?.toDouble() ?? priceVal;
                                    final isModified = (priceVal - stockRate).abs() > 0.001;
                                    final totalVal = priceVal * qtyVal;
                                    return {
                                      'id': parsedId > 0 ? parsedId : rawId,
                                      'productId': parsedId,
                                      'name': item['name'] ?? '',
                                      'productName': item['name'] ?? '',
                                      'price': priceVal,
                                      'rate': priceVal,
                                      'unitPrice': priceVal,
                                      'qty': qtyVal,
                                      'quantity': qtyVal,
                                      'total': totalVal,
                                      'totalAmount': totalVal,
                                      'stockRate': stockRate,
                                      'isRateModified': isModified,
                                      'unit': item['unit'] ?? 'pcs',
                                      'isLoose': item['isLoose'] ?? false,
                                    };
                                  }).toList();

                                  _showUpiPaymentScannerModal(
                                    context: context,
                                    isHindi: isHindi,
                                    themeProvider: themeProvider,
                                    invoiceNo: invoiceNo,
                                    customerSnapshot: customerSnapshot,
                                    phoneSnapshot: phoneSnapshot,
                                    cartSnapshot: cartSnapshot,
                                    subtotalSnapshot: subtotalSnapshot,
                                    taxSnapshot: taxSnapshot,
                                    discountSnapshot: discountSnapshot,
                                    netPayableSnapshot: upiAmt, // Display EXACT UPI payable amount on QR scanner
                                    modeSnapshot: selectedMode,
                                    onPaymentConfirmed: (chosenUpiId, chosenAcName, chosenBName) {
                                      executeSaleInsertion(chosenUpiId, chosenAcName, chosenBName);
                                    },
                                  );
                                  return;
                                }

                                await executeSaleInsertion();
                              },
                        child: isProcessingSale
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(
                                isHindi ? 'बिल पक्का करें' : 'Settle Bill & Print Receipt',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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

  void _showAddCustomerDialog(BuildContext context, bool isHindi) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isHindi ? 'ग्राहक जोड़ें' : 'Add Customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: isHindi ? 'ग्राहक नाम' : 'Customer Name',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: isHindi ? 'मोबाइल नंबर' : 'Phone Number',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isHindi ? 'रद्द करें' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final phone = phoneController.text.isNotEmpty ? phoneController.text : '+91 99000 00000';
                final syncProvider = Provider.of<SyncProvider>(context, listen: false);
                final newId = await syncProvider.saveOfflineCustomer(nameController.text, phone);

                setState(() {
                  final custName = nameController.text.trim();
                  if (!_customerList.contains(custName)) {
                    _customerList.add(custName);
                  }
                  if (newId != null) {
                    _customerIdMap[custName] = newId;
                  }
                  if (phone.isNotEmpty) {
                    _customerPhoneMap[custName] = phone;
                  }
                  _selectedCustomer = custName;
                  _customerPhoneController.text = phone;
                });

                if (mounted) {
                  Navigator.pop(ctx);
                }
              }
            },
            child: Text(isHindi ? 'जोड़ें' : 'Add'),
          ),
        ],
      ),
    );
  }
}
