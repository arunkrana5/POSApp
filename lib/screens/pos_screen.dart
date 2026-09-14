import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../providers/sync_provider.dart';
import '../providers/theme_provider.dart';
import '../database/sqlite_helper.dart';
import '../widgets/app_drawer.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final List<Map<String, dynamic>> _availableProducts = [
    {'id': '1', 'name': 'Aashirvaad Atta 5kg', 'price': 220.0, 'stock': 15, 'unit': 'pkt'},
    {'id': '2', 'name': 'Fortune Mustard Oil 1L', 'price': 145.0, 'stock': 8, 'unit': 'bottle'},
    {'id': '3', 'name': 'Tata Salt 1kg', 'price': 28.0, 'stock': 40, 'unit': 'pkt'},
    {'id': '4', 'name': 'Surf Excel 1kg', 'price': 130.0, 'stock': 12, 'unit': 'pkt'},
    {'id': '5', 'name': 'Sugar (चीनी) 1kg', 'price': 42.0, 'stock': 50, 'unit': 'kg'},
    {'id': '6', 'name': 'Toor Dal 1kg', 'price': 160.0, 'stock': 20, 'unit': 'kg'},
  ];

  final List<String> _customerList = [
    'Walk-in Customer',
    'Ramesh Kumar',
    'Suresh Patel',
    'Anita Sharma',
    'Vikas Verma',
  ];

  final List<Map<String, dynamic>> _cartItems = [];
  String _selectedPaymentMode = 'Cash';
  String _selectedCustomer = 'Walk-in Customer';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    try {
      final dbCustomers = await SQLiteHelper.instance.getCustomers();
      if (dbCustomers.isNotEmpty) {
        final names = dbCustomers.map((c) => c['name'].toString()).where((n) => n.isNotEmpty).toList();
        setState(() {
          for (var n in names) {
            if (!_customerList.contains(n)) {
              _customerList.add(n);
            }
          }
        });
      }
    } catch (_) {}
  }

  double get _subtotal {
    return _cartItems.fold(0.0, (sum, item) => sum + (item['price'] * item['qty']));
  }

  void _addToCart(Map<String, dynamic> product, TenantThemeProvider themeProvider) {
    final availableStock = (product['stock'] as num).toInt();
    final existingIndex = _cartItems.indexWhere((item) => item['id'] == product['id']);
    final currentQtyInCart = existingIndex >= 0 ? (_cartItems[existingIndex]['qty'] as num).toInt() : 0;

    if (!themeProvider.allowNegativeStock && (currentQtyInCart + 1) > availableStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Out of stock! (${product['name']}). Negative stock disabled by Tenant Admin.',
          ),
          backgroundColor: Colors.red.shade800,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      if (existingIndex >= 0) {
        _cartItems[existingIndex]['qty'] += 1;
      } else {
        _cartItems.add({
          'id': product['id'],
          'name': product['name'],
          'price': product['price'],
          'unit': product['unit'],
          'qty': 1,
        });
      }
    });
  }

  void _updateQuantity(int index, int delta, TenantThemeProvider themeProvider) {
    if (delta > 0 && !themeProvider.allowNegativeStock) {
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
      _cartItems[index]['qty'] += delta;
      if (_cartItems[index]['qty'] <= 0) {
        _cartItems.removeAt(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = Provider.of<LocaleProvider>(context).isHindi;
    final themeProvider = Provider.of<TenantThemeProvider>(context);
    final filteredProducts = _availableProducts
        .where((p) => p['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    if (!_customerList.contains(_selectedCustomer)) {
      _customerList.add(_selectedCustomer);
    }
    final uniqueCustomers = _customerList.toSet().toList();

    final taxAmount = themeProvider.enableTaxCalculation
        ? _subtotal * (themeProvider.defaultTaxPercent / 100.0)
        : 0.0;
    final grandTotal = _subtotal + taxAmount;

    return Scaffold(
      backgroundColor: themeProvider.pageBgColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(
          isHindi ? 'नया बिल / POS' : 'Point of Sale (POS)',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
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
      body: Column(
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
                      child: DropdownButtonFormField<String>(
                        value: uniqueCustomers.contains(_selectedCustomer) ? _selectedCustomer : uniqueCustomers.first,
                        decoration: InputDecoration(
                          labelText: isHindi ? 'ग्राहक चुनें' : 'Select Customer',
                          prefixIcon: const Icon(Icons.person_rounded, size: 20),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: uniqueCustomers
                            .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14))))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedCustomer = val);
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
                const SizedBox(height: 10),
                // Payment Mode Chips
                Row(
                  children: ['Cash', if (themeProvider.enableOnlinePayment) 'UPI', if (themeProvider.enableUdhaar) 'Udhaar'].map((mode) {
                    final isSelected = _selectedPaymentMode == mode;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(
                          mode == 'Udhaar' ? (isHindi ? 'उधार' : 'Udhaar') : mode,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: mode == 'Udhaar' ? Colors.red.shade700 : themeProvider.buttonBgColor,
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedPaymentMode = mode);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: isHindi ? 'सामान खोजें...' : 'Search items...',
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
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val);
              },
            ),
          ),

          // Product Catalog Grid
          Expanded(
            flex: 5,
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.45,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: filteredProducts.length,
              itemBuilder: (ctx, index) {
                final product = filteredProducts[index];
                final cartIndex = _cartItems.indexWhere((item) => item['id'] == product['id']);
                final qtyInCart = cartIndex >= 0 ? _cartItems[cartIndex]['qty'] : 0;

                return InkWell(
                  onTap: () => _addToCart(product, themeProvider),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: themeProvider.cardBgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: qtyInCart > 0 ? themeProvider.buttonBgColor : themeProvider.textColor.withOpacity(0.1),
                        width: qtyInCart > 0 ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                product['name'],
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: themeProvider.fontFamily,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13 * themeProvider.fontSizeScale,
                                  color: themeProvider.textColor,
                                ),
                              ),
                            ),
                            if (qtyInCart > 0)
                              CircleAvatar(
                                radius: 10,
                                backgroundColor: themeProvider.buttonBgColor,
                                child: Text(
                                  '$qtyInCart',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: themeProvider.buttonTextColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '${themeProvider.currencySymbol} ${product["price"]}',
                                  style: TextStyle(
                                    fontFamily: themeProvider.fontFamily,
                                    fontSize: 15 * themeProvider.fontSizeScale,
                                    fontWeight: FontWeight.bold,
                                    color: themeProvider.amountColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: themeProvider.textColor.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${product["stock"]} ${product["unit"]}',
                                style: TextStyle(
                                  fontFamily: themeProvider.fontFamily,
                                  fontSize: 11 * themeProvider.fontSizeScale,
                                  color: themeProvider.textColor.withOpacity(0.7),
                                ),
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

          // Cart & Total Footer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: themeProvider.cardBgColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                // Cart Items Horizontal Preview
                if (_cartItems.isNotEmpty)
                  SizedBox(
                    height: 48,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _cartItems.length,
                      separatorBuilder: (ctx, i) => const SizedBox(width: 8),
                      itemBuilder: (ctx, index) {
                        final item = _cartItems[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: themeProvider.buttonBgColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: themeProvider.buttonBgColor.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Text(
                                item['name'],
                                style: TextStyle(
                                  fontFamily: themeProvider.fontFamily,
                                  fontSize: 12 * themeProvider.fontSizeScale,
                                  fontWeight: FontWeight.bold,
                                  color: themeProvider.textColor,
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
                            isHindi ? 'कुल योग / Total' : 'Grand Total',
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
                            : () async {
                                final syncProvider = Provider.of<SyncProvider>(context, listen: false);
                                await syncProvider.saveOfflineSale({
                                  'customer': _selectedCustomer,
                                  'subtotal': _subtotal,
                                  'taxAmount': taxAmount,
                                  'amount': grandTotal,
                                  'paymentMode': _selectedPaymentMode,
                                  'items': _cartItems,
                                  'createdAt': DateTime.now().toIso8601String(),
                                });

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isHindi
                                            ? 'बिल सफलतापूर्‍वक सहेजा गया! (Offline saved)'
                                            : 'Invoice generated & saved successfully!',
                                      ),
                                      backgroundColor: Colors.green.shade700,
                                    ),
                                  );
                                  setState(() {
                                    for (var cartItem in _cartItems) {
                                      final idx = _availableProducts.indexWhere((p) => p['id'] == cartItem['id'] || p['name'] == cartItem['name']);
                                      if (idx >= 0) {
                                        final current = (_availableProducts[idx]['stock'] as num).toInt();
                                        final qty = (cartItem['qty'] as num).toInt();
                                        _availableProducts[idx]['stock'] = (current - qty) < 0 ? 0 : (current - qty);
                                      }
                                    }
                                    _cartItems.clear();
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
        ],
      ),
    );
  }

  void _showAddCustomerDialog(BuildContext context, bool isHindi) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isHindi ? 'नया ग्राहक जोड़ें' : 'Add New Customer'),
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
                await syncProvider.saveOfflineCustomer(nameController.text, phone);

                setState(() {
                  if (!_customerList.contains(nameController.text)) {
                    _customerList.add(nameController.text);
                  }
                  _selectedCustomer = nameController.text;
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
