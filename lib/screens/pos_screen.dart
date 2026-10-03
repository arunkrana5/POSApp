import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/invoice_printer.dart';
import '../utils/whatsapp_helper.dart';
import '../providers/sync_provider.dart';
import '../providers/theme_provider.dart';
import '../database/sqlite_helper.dart';
import '../widgets/app_drawer.dart';
import '../utils/toast_helper.dart';

import 'package:shared_preferences/shared_preferences.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  Widget _buildTileThumbnail(String imgUrl, {double size = 44}) {
    final clean = imgUrl.trim();
    if (clean.isEmpty) {
      return Icon(Icons.inventory_2_rounded, size: size * 0.6, color: Colors.blue);
    }
    if (clean.startsWith('data:image/')) {
      try {
        final parts = clean.split(',');
        if (parts.length > 1) {
          final bytes = base64Decode(parts[1].trim());
          return Image.memory(bytes, width: size, height: size, fit: BoxFit.cover);
        }
      } catch (_) {}
    } else if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return Image.network(
        clean,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(Icons.inventory_2_rounded, size: size * 0.6, color: Colors.blue),
      );
    } else {
      try {
        final bytes = base64Decode(clean);
        return Image.memory(bytes, width: size, height: size, fit: BoxFit.cover);
      } catch (_) {}
    }
    return Icon(Icons.inventory_2_rounded, size: size * 0.6, color: Colors.blue);
  }

  final List<Map<String, dynamic>> _availableProducts = [];

  final List<String> _customerList = [
    'Walk-in Customer',
  ];

  final Map<String, String> _customerPhoneMap = {};

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
        'imageUrl': p.imageUrl ?? '',
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
    final price = (product['price'] as num).toDouble();
    double currentWeight = 1.0;
    if (cartIndex != null && cartIndex >= 0 && cartIndex < _cartItems.length) {
      currentWeight = (_cartItems[cartIndex]['qty'] as num).toDouble();
    }

    final weightController = TextEditingController(text: currentWeight.toStringAsFixed(currentWeight == currentWeight.roundToDouble() ? 0 : 3));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final calcWeight = double.tryParse(weightController.text) ?? 0.0;
          final calcTotal = calcWeight * price;

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
                      Text('Rate: ₹$price / ${product['unit']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                    ],
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Enter Qty:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
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
                const SizedBox(height: 12),
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
                  if (w <= 0) return;
                  setState(() {
                    if (cartIndex != null && cartIndex >= 0) {
                      _cartItems[cartIndex]['qty'] = w;
                    } else {
                      final existingIdx = _cartItems.indexWhere((item) => item['id'] == product['id']);
                      if (existingIdx >= 0) {
                        _cartItems[existingIdx]['qty'] = w;
                      } else {
                        _cartItems.add({
                          'id': product['id'],
                          'name': product['name'],
                          'price': product['price'],
                          'unit': product['unit'],
                          'qty': w,
                          'isLoose': true,
                        });
                      }
                    }
                  });
                  Navigator.pop(ctx);
                },
                child: Text(cartIndex != null ? 'Update Weight' : 'Add Loose Item', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
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
    final phoneCtrl = TextEditingController(text: customerPhone);

    bool isSendingWhatsApp = false;

    final calcDisc = discountAmount > 0.001
        ? discountAmount
        : (((subtotal + taxAmount) - grandTotal) > 0.001 ? ((subtotal + taxAmount) - grandTotal) : 0.0);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => AlertDialog(
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
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.print_rounded, size: 18),
                        label: Text(isHindi ? 'प्रिंट रसीद' : 'Print Receipt'),
                        onPressed: () {
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
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
                        icon: isSendingWhatsApp
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send_rounded, size: 18),
                        label: Text(isSendingWhatsApp ? 'Sending...' : 'WhatsApp'),
                        onPressed: isSendingWhatsApp
                            ? null
                            : () async {
                                final cleanPhone = phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
                                if (cleanPhone.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter a valid customer mobile number to send WhatsApp invoice')),
                                  );
                                  return;
                                }
                                setModalState(() {
                                  isSendingWhatsApp = true;
                                });

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
                                  final prefs = await SharedPreferences.getInstance();
                                  final tId = prefs.getInt('tenant_id') ?? 1;
                                  final token = prefs.getString('auth_token') ?? '';

                                  final headers = <String, String>{'Content-Type': 'application/json'};
                                  if (token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

                                  final response = await http.post(
                                    Uri.parse('${ApiConfig.baseUrl}/sales/send-whatsapp'),
                                    headers: headers,
                                    body: jsonEncode({
                                      'tenantId': tId,
                                      'phone': cleanPhone,
                                      'message': messageText,
                                    }),
                                  ).timeout(const Duration(seconds: 12));

                                  if (response.statusCode == 200) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('✅ Cloud Server WhatsApp message sent directly to +91 $cleanPhone!'),
                                          backgroundColor: const Color(0xFF25D366),
                                        ),
                                      );
                                    }
                                  } else {
                                    WhatsAppHelper.openWhatsApp(phone: cleanPhone, message: messageText);
                                  }
                                } catch (_) {
                                  WhatsAppHelper.openWhatsApp(phone: cleanPhone, message: messageText);
                                } finally {
                                  if (modalCtx.mounted) {
                                    setModalState(() {
                                      isSendingWhatsApp = false;
                                    });
                                  }
                                }
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
                      isHindi ? '+ नया बिल बनाएँ' : '+ New Bill',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
          isHindi ? 'नया बिल' : 'New Bill)',
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
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    mainAxisExtent: 130,
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
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: _buildTileThumbnail(imgUrl, size: 44),
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
    required VoidCallback onPaymentConfirmed,
  }) {
    final cleanPhone = themeProvider.supportPhone.replaceAll(RegExp(r'\D'), '');
    final upiPa = cleanPhone.isNotEmpty ? '$cleanPhone@upi' : 'store@upi';
    final storeTitle = themeProvider.tenantName.isNotEmpty ? themeProvider.tenantName : 'VillageShop POS';
    final upiPayload = 'upi://pay?pa=$upiPa&pn=${Uri.encodeComponent(storeTitle)}&am=${netPayableSnapshot.toStringAsFixed(2)}&cu=INR&tn=Bill_$invoiceNo';
    final qrUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=240x240&data=${Uri.encodeComponent(upiPayload)}';

    bool isConfirming = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => AlertDialog(
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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                    const SizedBox(height: 2),
                    Text(
                      'UPI ID: $upiPa',
                      style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'monospace'),
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
                      onPaymentConfirmed();
                    },
            ),
          ],
        ),
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
    String mode = _selectedPaymentMode;
    String? modalErrorMessage;
    bool isProcessingSale = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final discount = double.tryParse(discountCtrl.text) ?? 0.0;
            final netPayable = (grandTotal - discount).clamp(0.0, double.infinity);
            final paidAmount = double.tryParse(paidCtrl.text) ?? netPayable;
            final remainingUdhaar = mode == 'Udhaar'
                ? netPayable
                : (netPayable - paidAmount).clamp(0.0, double.infinity);

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
                            child: Text(mode.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.primaryColor, fontSize: 12)),
                          ),
                        ],
                      ),
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
                              hintText: '',
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            onChanged: (val) {
                              setModalState(() {
                                final d = double.tryParse(val) ?? 0.0;
                                final net = (grandTotal - d).clamp(0.0, double.infinity);
                                paidCtrl.text = net.toStringAsFixed(0);
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
                              paidCtrl.text = roundTotal.toStringAsFixed(0);
                            });
                          },
                          child: Text(isHindi ? 'राउंड ऑफ ₹${grandTotal.floor()}' : 'Round to ₹${grandTotal.floor()}'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Paid Amount Field
                    TextField(
                      controller: paidCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: isHindi ? 'प्राप्त राशि' : 'Amount Paid by Customer (₹)',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.payments_rounded, color: Colors.green),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: 14),

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
                                final modeSnapshot = mode;
                                final customerSnapshot = _selectedCustomer;

                                // Requirement 1: Walk-in Customer Udhaar Validation
                                if (customerSnapshot == 'Walk-in Customer' && (modeSnapshot == 'Udhaar' || remainingUdhaar > 0.001)) {
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

                                Future<void> executeSaleInsertion() async {
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
                                    return {
                                      'id': parsedId > 0 ? parsedId : rawId,
                                      'productId': parsedId,
                                      'name': item['name'] ?? '',
                                      'productName': item['name'] ?? '',
                                      'price': priceVal,
                                      'unitPrice': priceVal,
                                      'qty': qtyVal,
                                      'quantity': qtyVal,
                                      'unit': item['unit'] ?? 'pcs',
                                      'isLoose': item['isLoose'] ?? false,
                                    };
                                  }).toList();

                                  final subtotalSnapshot = subtotal;
                                  final taxSnapshot = taxAmount;
                                  final netPayableSnapshot = netPayable;
                                  final discountSnapshot = (subtotal + taxAmount - netPayable).clamp(0.0, double.infinity);
                                  final modeSnapshot = mode;
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
                                    'discountAmount': discountSnapshot,
                                    'discount': discountSnapshot,
                                    'amount': netPayableSnapshot,
                                    'totalAmount': netPayableSnapshot,
                                    'paidAmount': paidAmount,
                                    'paymentMode': modeSnapshot,
                                    'items': cartSnapshot,
                                    'createdAt': DateTime.now().toIso8601String(),
                                  });

                                  // Update Customer Udhaar Ledger balance if remainingUdhaar > 0
                                  if (remainingUdhaar > 0 && customerSnapshot != 'Walk-in Customer') {
                                    final customersList = await SQLiteHelper.instance.getCustomers();
                                    final cust = customersList.firstWhere((c) => c['name'] == customerSnapshot, orElse: () => {});
                                    final currentBalance = (cust['udhaar'] as num?)?.toDouble() ?? 0.0;
                                    final newBalance = currentBalance + remainingUdhaar;
                                    await SQLiteHelper.instance.updateCustomerUdhaar(customerSnapshot, newBalance);
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

                                // Requirement 2: If payment mode is UPI/Online, show scanner modal FIRST!
                                if (modeSnapshot.toUpperCase().contains('UPI') || modeSnapshot.toUpperCase().contains('ONLINE')) {
                                  final invoiceNo = 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
                                  final subtotalSnapshot = subtotal;
                                  final taxSnapshot = taxAmount;
                                  final netPayableSnapshot = netPayable;
                                  final discountSnapshot = (subtotal + taxAmount - netPayable).clamp(0.0, double.infinity);
                                  final phoneSnapshot = _customerPhoneController.text;
                                  final cartSnapshot = List<Map<String, dynamic>>.from(_cartItems);

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
                                    netPayableSnapshot: netPayableSnapshot,
                                    modeSnapshot: modeSnapshot,
                                    onPaymentConfirmed: () {
                                      executeSaleInsertion();
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
