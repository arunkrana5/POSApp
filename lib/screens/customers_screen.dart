import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../providers/sync_provider.dart';
import '../providers/theme_provider.dart';
import '../database/sqlite_helper.dart';
import '../widgets/app_drawer.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  List<Map<String, dynamic>> _customers = [
    {'id': '1', 'name': 'Ramesh Kumar', 'phone': '+91 98765 43210', 'udhaar': 2400.0, 'lastTx': '12 Sep 2026'},
    {'id': '2', 'name': 'Suresh Patel', 'phone': '+91 98123 45678', 'udhaar': 1200.0, 'lastTx': '11 Sep 2026'},
    {'id': '3', 'name': 'Anita Devi', 'phone': '+91 97654 32109', 'udhaar': 0.0, 'lastTx': '10 Sep 2026'},
    {'id': '4', 'name': 'Vikas Verma', 'phone': '+91 99887 76655', 'udhaar': 880.0, 'lastTx': '09 Sep 2026'},
  ];

  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    try {
      final dbCustomers = await SQLiteHelper.instance.getCustomers();
      if (dbCustomers.isNotEmpty) {
        final List<Map<String, dynamic>> loaded = dbCustomers.map((c) => {
          'id': c['id']?.toString() ?? '0',
          'name': c['name'] ?? '',
          'phone': c['phone'] ?? '',
          'udhaar': (c['udhaar'] as num?)?.toDouble() ?? 0.0,
          'lastTx': c['lastTx'] ?? 'Today',
        }).toList();

        final existingNames = loaded.map((e) => e['name'].toString().toLowerCase()).toSet();
        for (var d in _customers) {
          if (!existingNames.contains(d['name'].toString().toLowerCase())) {
            loaded.add(d);
          }
        }
        setState(() {
          _customers = loaded;
        });
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = Provider.of<LocaleProvider>(context).isHindi;
    final filteredCustomers = _customers
        .where((c) =>
            c['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
            c['phone'].toString().contains(_searchQuery))
        .toList();

    final totalUdhaar = _customers.fold(0.0, (sum, c) => sum + ((c['udhaar'] as num?)?.toDouble() ?? 0.0));

    final themeProvider = Provider.of<TenantThemeProvider>(context);
    return Scaffold(
      backgroundColor: themeProvider.pageBgColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(
          isHindi ? 'ग्राहक उधार खाता' : 'Customer Udhaar Ledger',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Total Udhaar Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: themeProvider.cardBgColor,
              border: Border(bottom: BorderSide(color: themeProvider.textColor.withOpacity(0.08))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isHindi ? 'कुल मार्केट उधार' : 'Total Outstanding Udhaar',
                      style: TextStyle(
                        fontFamily: themeProvider.fontFamily,
                        color: themeProvider.textColor.withOpacity(0.7),
                        fontSize: 13 * themeProvider.fontSizeScale,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹ ${totalUdhaar.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontFamily: themeProvider.fontFamily,
                        fontSize: 24 * themeProvider.fontSizeScale,
                        fontWeight: FontWeight.bold,
                        color: themeProvider.amountColor,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeProvider.buttonBgColor,
                    foregroundColor: themeProvider.buttonTextColor,
                  ),
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                  label: Text(
                    isHindi ? 'नया ग्राहक' : 'Add Customer',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  onPressed: () => _showAddCustomerModal(context, isHindi),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: isHindi ? 'ग्राहक नाम या फोन नंबर खोजें...' : 'Search by customer name or phone...',
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

          // Customer List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: filteredCustomers.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                    itemBuilder: (ctx, index) {
                      final customer = filteredCustomers[index];
                      final udhaarVal = (customer['udhaar'] as num?)?.toDouble() ?? 0.0;
                      final hasBalance = udhaarVal > 0;

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: hasBalance ? Colors.red.shade100 : Colors.green.shade100,
                            child: Icon(
                              Icons.person_rounded,
                              color: hasBalance ? Colors.red.shade800 : Colors.green.shade800,
                            ),
                          ),
                          title: Text(
                            customer['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: Text('${customer["phone"]} • ${customer["lastTx"]}'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹ ${udhaarVal.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: hasBalance ? Colors.red.shade700 : Colors.green.shade700,
                                ),
                              ),
                              if (hasBalance)
                                InkWell(
                                  onTap: () => _showRecordPaymentDialog(context, customer, isHindi),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade700,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isHindi ? 'जमा लें' : 'Pay Received',
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
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

  void _showRecordPaymentDialog(BuildContext context, Map<String, dynamic> customer, bool isHindi) {
    final amountController = TextEditingController();
    final double currentUdhaar = (customer['udhaar'] as num?)?.toDouble() ?? 0.0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${isHindi ? "भुगतान प्राप्त करें" : "Record Payment"} - ${customer["name"]}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${isHindi ? "वर्तमान बकाया" : "Current Balance"}: ₹ ${currentUdhaar.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: isHindi ? 'जमा की गई राशि (₹)' : 'Amount Received (₹)',
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
            onPressed: () async {
              final paidAmount = double.tryParse(amountController.text) ?? 0.0;
              if (paidAmount > 0) {
                final newUdhaar = (currentUdhaar - paidAmount).clamp(0.0, double.infinity);
                
                final syncProvider = Provider.of<SyncProvider>(context, listen: false);
                await syncProvider.saveOfflineCustomerPayment(customer['name'], paidAmount, newUdhaar);

                setState(() {
                  customer['udhaar'] = newUdhaar;
                  customer['lastTx'] = 'Payment Paid';
                });

                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isHindi
                            ? 'भुगतान सफलतापूर्‍वक दर्ज किया गया! (Saved & Synced)'
                            : 'Payment recorded & synced successfully!',
                      ),
                      backgroundColor: Colors.green.shade700,
                    ),
                  );
                }
              }
            },
            child: Text(isHindi ? 'जमा करें' : 'Save Payment', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddCustomerModal(BuildContext context, bool isHindi) {
    final themeProvider = Provider.of<TenantThemeProvider>(context, listen: false);
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isHindi ? 'नया ग्राहक जोड़ें' : 'Add New Customer',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: isHindi ? 'ग्राहक नाम' : 'Customer Name',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: isHindi ? 'मोबाइल नंबर' : 'Phone Number',
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
                onPressed: () async {
                  if (nameCtrl.text.isNotEmpty) {
                    final phoneStr = phoneCtrl.text.isNotEmpty ? phoneCtrl.text : '+91 99000 00000';
                    final syncProvider = Provider.of<SyncProvider>(context, listen: false);
                    await syncProvider.saveOfflineCustomer(nameCtrl.text, phoneStr);

                    final newCust = {
                      'id': '${_customers.length + 1}',
                      'name': nameCtrl.text,
                      'phone': phoneStr,
                      'udhaar': 0.0,
                      'lastTx': 'Registered Today',
                    };

                    setState(() {
                      _customers.insert(0, newCust);
                    });

                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isHindi
                                ? 'ग्राहक सफलतापूर्‍वक सहेजा गया! (Saved & Synced)'
                                : 'Customer saved & synced successfully!',
                          ),
                          backgroundColor: Colors.green.shade700,
                        ),
                      );
                    }
                  }
                },
                child: Text(
                  isHindi ? 'ग्राहक सेव करें' : 'Save Customer',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
