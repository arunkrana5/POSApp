import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:html' as html;
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/invoice_printer.dart';
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
    'Anita Devi',
    'Vikas Verma',
  ];

  final Map<String, String> _customerPhoneMap = {
    'Ramesh Kumar': '9876543210',
    'Suresh Patel': '9812345678',
    'Anita Devi': '9765432109',
    'Vikas Verma': '9988776655',
  };

  final TextEditingController _customerPhoneController = TextEditingController();
  final List<Map<String, dynamic>> _cartItems = [];
  String _selectedPaymentMode = 'Cash';
  String _selectedCustomer = 'Walk-in Customer';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _loadProducts();
  }

  Future<void> _loadCustomers() async {
    try {
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);
      final fetchedCustomers = await syncProvider.fetchCustomers();

      final List<Map<String, dynamic>> customersToProcess = [];
      if (fetchedCustomers.isNotEmpty) {
        customersToProcess.addAll(fetchedCustomers);
      } else {
        final dbCustomers = await SQLiteHelper.instance.getCustomers();
        if (dbCustomers.isNotEmpty) {
          customersToProcess.addAll(dbCustomers);
        }
      }

      if (customersToProcess.isNotEmpty) {
        setState(() {
          for (var c in customersToProcess) {
            final n = c['name']?.toString() ?? '';
            final p = c['phone']?.toString() ?? '';
            if (n.isNotEmpty) {
              if (!_customerList.contains(n)) {
                _customerList.add(n);
              }
              if (p.isNotEmpty) {
                _customerPhoneMap[n] = p;
              }
            }
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadProducts() async {
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
        }).toList();

        final existingNames = loadedList.map((e) => e['name'].toString().toLowerCase()).toSet();
        for (var d in _availableProducts) {
          if (!existingNames.contains(d['name'].toString().toLowerCase())) {
            loadedList.add(d);
          }
        }
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
    required double grandTotal,
    required String paymentMode,
  }) {
    final phoneCtrl = TextEditingController(text: customerPhone);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
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
                      final name = it['name'] ?? 'Item';
                      final qty = it['qty'] ?? 1;
                      final price = (it['price'] as num?)?.toDouble() ?? 0.0;
                      final tot = qty * price;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text('$qty x $name', style: const TextStyle(fontSize: 13))),
                            Text('₹ ${tot.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(isHindi ? 'कुल राशि:' : 'Grand Total:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                      '₹ ${grandTotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                Text(
                  isHindi ? 'व्हाट्सएप रसीद भेजें (WhatsApp Share):' : 'Send WhatsApp Invoice Receipt:',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: isHindi ? 'मोबाइल नंबर' : 'Customer Mobile Number',
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: Text(isHindi ? 'प्रिंट रसीद' : 'Print Receipt'),
                  onPressed: () {
                    InvoicePrinter.printA4Invoice(
                      tenantName: themeProvider.tenantName,
                      appTitle: themeProvider.appTitle,
                      logoUrl: themeProvider.logoUrl,
                      supportPhone: themeProvider.supportPhone,
                      invoiceNo: invoiceNo,
                      customerName: customerName,
                      customerPhone: phoneCtrl.text.trim(),
                      paymentMode: paymentMode,
                      createdAt: DateTime.now().toString().split('.')[0],
                      subtotal: subtotal,
                      taxAmount: taxAmount,
                      grandTotal: grandTotal,
                      items: items,
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('WhatsApp'),
                  onPressed: () {
                    final cleanPhone = phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
                    if (cleanPhone.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid customer mobile number to send WhatsApp invoice')),
                      );
                      return;
                    }
                    final targetPhone = cleanPhone.startsWith('91') ? cleanPhone : '91$cleanPhone';

                    final StringBuffer sb = StringBuffer();
                    sb.writeln('🛒 *VILLAGE SHOP - INVOICE RECEIPT*');
                    sb.writeln('===========================');
                    sb.writeln('📄 Invoice No: $invoiceNo');
                    sb.writeln('👤 Customer: $customerName');
                    sb.writeln('💳 Mode: $paymentMode');
                    sb.writeln('---------------------------');
                    for (var it in items) {
                      final name = it['name'];
                      final qty = it['qty'];
                      final price = it['price'];
                      sb.writeln('• ${qty}x $name @ ₹$price = ₹${(qty * price).toStringAsFixed(2)}');
                    }
                    sb.writeln('---------------------------');
                    sb.writeln('*GRAND TOTAL: ₹${grandTotal.toStringAsFixed(2)}*');
                    sb.writeln('===========================');
                    sb.writeln('Thank you for shopping with us! 🙏');

                    final encodedText = Uri.encodeComponent(sb.toString());
                    final waUrl = 'https://api.whatsapp.com/send?phone=$targetPhone&text=$encodedText';

                    if (kIsWeb) {
                      html.window.open(waUrl, '_blank');
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Opening WhatsApp for $targetPhone...'), backgroundColor: const Color(0xFF25D366)),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: themeProvider.buttonBgColor, foregroundColor: themeProvider.buttonTextColor),
              onPressed: () {
                Navigator.pop(ctx);
              },
              child: Text(
                isHindi ? '+ नया बिल बनाएँ (Next Bill)' : '+ Create Next Bill',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = Provider.of<LocaleProvider>(context).isHindi;
    final themeProvider = Provider.of<TenantThemeProvider>(context);
    final filteredProducts = _availableProducts
        .where((p) =>
            p['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (p['category'] != null && p['category'].toString().toLowerCase().contains(_searchQuery.toLowerCase())) ||
            (p['barcode'] != null && p['barcode'].toString().toLowerCase().contains(_searchQuery.toLowerCase())) ||
            (p['batchNumber'] != null && p['batchNumber'].toString().toLowerCase().contains(_searchQuery.toLowerCase())) ||
            (p['rackNumber'] != null && p['rackNumber'].toString().toLowerCase().contains(_searchQuery.toLowerCase())))
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
                          if (val != null) {
                            setState(() {
                              _selectedCustomer = val;
                              if (val == 'Walk-in Customer') {
                                _customerPhoneController.text = '';
                              } else {
                                _customerPhoneController.text = _customerPhoneMap[val] ?? '';
                              }
                            });
                          }
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
                childAspectRatio: 1.25,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: filteredProducts.length,
              itemBuilder: (ctx, index) {
                final product = filteredProducts[index];
                final cartIndex = _cartItems.indexWhere((item) => item['id'] == product['id']);
                final qtyInCart = cartIndex >= 0 ? _cartItems[cartIndex]['qty'] : 0;
                final imgUrl = product['imageUrl']?.toString() ?? '';
                final barcode = product['barcode']?.toString() ?? '';

                return InkWell(
                  onTap: () => _addToCart(product, themeProvider),
                  child: Container(
                    padding: const EdgeInsets.all(8),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: (imgUrl.isNotEmpty && Uri.tryParse(imgUrl)?.hasAbsolutePath == true)
                                  ? Image.network(imgUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2_rounded, size: 20, color: Colors.blue))
                                  : const Icon(Icons.inventory_2_rounded, size: 20, color: Colors.blue),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product['name'],
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: themeProvider.fontFamily,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12 * themeProvider.fontSizeScale,
                                      color: themeProvider.textColor,
                                    ),
                                  ),
                                  if (barcode.isNotEmpty)
                                    Text(
                                      '║▌$barcode',
                                      style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: Colors.purple, fontWeight: FontWeight.bold),
                                    ),
                                ],
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
                            Text(
                              '${product["stock"]} ${product["unit"]}',
                              style: TextStyle(
                                fontFamily: themeProvider.fontFamily,
                                fontSize: 11 * themeProvider.fontSizeScale,
                                color: (product['stock'] as num) <= 5 ? Colors.red.shade700 : themeProvider.textColor.withOpacity(0.6),
                                fontWeight: (product['stock'] as num) <= 5 ? FontWeight.bold : FontWeight.normal,
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
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _cartItems.length,
                      separatorBuilder: (ctx, i) => const SizedBox(width: 6),
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
                                final invoiceNo = 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
                                final cartSnapshot = List<Map<String, dynamic>>.from(_cartItems);
                                final subtotalSnapshot = _subtotal;
                                final taxSnapshot = taxAmount;
                                final grandTotalSnapshot = grandTotal;
                                final modeSnapshot = _selectedPaymentMode;
                                final customerSnapshot = _selectedCustomer;
                                final phoneSnapshot = _customerPhoneController.text;

                                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                final syncProvider = Provider.of<SyncProvider>(context, listen: false);
                                await syncProvider.saveOfflineSale({
                                  'clientTransactionId': invoiceNo,
                                  'tenantId': authProvider.tenantId,
                                  'tenantCode': authProvider.tenantCode,
                                  'customer': customerSnapshot,
                                  'customerName': customerSnapshot,
                                  'customerPhone': phoneSnapshot,
                                  'subtotal': subtotalSnapshot,
                                  'taxAmount': taxSnapshot,
                                  'amount': grandTotalSnapshot,
                                  'totalAmount': grandTotalSnapshot,
                                  'paidAmount': modeSnapshot == 'Udhaar' ? 0 : grandTotalSnapshot,
                                  'paymentMode': modeSnapshot,
                                  'items': cartSnapshot,
                                  'createdAt': DateTime.now().toIso8601String(),
                                });

                                if (context.mounted) {
                                  setState(() {
                                    for (var cartItem in cartSnapshot) {
                                      final idx = _availableProducts.indexWhere((p) => p['id'] == cartItem['id'] || p['name'] == cartItem['name']);
                                      if (idx >= 0) {
                                        final current = (_availableProducts[idx]['stock'] as num).toInt();
                                        final qty = (cartItem['qty'] as num).toInt();
                                        _availableProducts[idx]['stock'] = (current - qty) < 0 ? 0 : (current - qty);
                                      }
                                    }
                                    _cartItems.clear();
                                  });

                                  // Pop up the completed invoice receipt with WhatsApp & Print options!
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
                                    grandTotal: grandTotalSnapshot,
                                    paymentMode: modeSnapshot,
                                  );
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
