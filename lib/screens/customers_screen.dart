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
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);
      final fetchedCustomers = await syncProvider.fetchCustomers();

      if (fetchedCustomers.isNotEmpty) {
        final List<Map<String, dynamic>> loaded = fetchedCustomers.map((c) => {
          'id': c['id']?.toString() ?? '0',
          'name': c['name'] ?? '',
          'phone': c['phone'] ?? '',
          'udhaar': (c['udhaar'] as num?)?.toDouble() ?? 0.0,
          'lastTx': c['lastTx'] ?? 'Registered Today',
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
      } else {
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
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
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
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth >= 750;

                      Widget buildCustomerCard(Map<String, dynamic> customer) {
                        final udhaarVal = (customer['udhaar'] as num?)?.toDouble() ?? 0.0;
                        final hasBalance = udhaarVal > 0;
                        final phone = customer['phone'] ?? '';
                        final village = customer['village'] ?? customer['address'] ?? '';

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            onTap: () => _showCustomerDetailModal(context, customer, isHindi),
                            leading: CircleAvatar(
                              backgroundColor: hasBalance ? Colors.red.shade100 : Colors.green.shade100,
                              child: Icon(
                                Icons.person_rounded,
                                color: hasBalance ? Colors.red.shade800 : Colors.green.shade800,
                              ),
                            ),
                            title: Text(
                              customer['name'] ?? 'Unnamed',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            subtitle: Text(
                              village.toString().isNotEmpty
                                  ? '$phone • $village'
                                  : '$phone • ${customer["lastTx"] ?? "No tx"}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '₹ ${udhaarVal.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: hasBalance ? Colors.red.shade700 : Colors.green.shade700,
                                      ),
                                    ),
                                    if (hasBalance)
                                      InkWell(
                                        onTap: () => _showRecordPaymentDialog(context, customer, isHindi),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade700,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            isHindi ? 'जमा लें' : 'Pay Received',
                                            style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: Icon(Icons.edit_outlined, color: themeProvider.primaryColor, size: 20),
                                  tooltip: 'Edit Customer Master',
                                  onPressed: () => _showAddCustomerModal(context, isHindi, customer),
                                ),
                              ],
                            ),
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
                            mainAxisExtent: 78,
                          ),
                          itemCount: filteredCustomers.length,
                          itemBuilder: (ctx, index) => buildCustomerCard(filteredCustomers[index]),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        itemCount: filteredCustomers.length,
                        separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                        itemBuilder: (ctx, index) => buildCustomerCard(filteredCustomers[index]),
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

  void _showCustomerDetailModal(BuildContext context, Map<String, dynamic> c, bool isHindi) {
    final themeProvider = Provider.of<TenantThemeProvider>(context, listen: false);
    final udhaarVal = (c['udhaar'] as num?)?.toDouble() ?? 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isHindi ? 'ग्राहक मास्टर प्रोफ़ाइल' : 'Customer Master Profile',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: themeProvider.primaryColor),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_note_rounded, color: Colors.blue),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showAddCustomerModal(context, isHindi, c);
                    },
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: themeProvider.primaryColor.withOpacity(0.1),
                  child: Icon(Icons.person_rounded, color: themeProvider.primaryColor, size: 28),
                ),
                title: Text(c['name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                subtitle: Text('Father\'s Name: ${c["fatherName"] ?? "N/A"}'),
                trailing: Text(
                  '₹ ${udhaarVal.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: udhaarVal > 0 ? Colors.red.shade700 : Colors.green.shade700),
                ),
              ),
              const SizedBox(height: 12),
              const Text('CONTACT DETAILS:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.phone, size: 16, color: Colors.grey.shade700),
                  const SizedBox(width: 8),
                  Text('Phone: ${c["phone"] ?? "N/A"}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 16),
                  Icon(Icons.message_rounded, size: 16, color: Colors.green),
                  const SizedBox(width: 4),
                  Text('WA: ${c["whatsapp"] ?? c["phone"] ?? "N/A"}', style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              if (c['email'] != null && c['email'].toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.email, size: 16, color: Colors.grey.shade700),
                    const SizedBox(width: 8),
                    Text('Email: ${c["email"]}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              const Text('FULL ADDRESS BREAKDOWN:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Address: ${c["address"] ?? "N/A"}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text('Village/Town: ${c["village"] ?? "N/A"}  |  P.O.: ${c["po"] ?? "N/A"}', style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 2),
                    Text('P.S.: ${c["ps"] ?? "N/A"}  |  District: ${c["dist"] ?? "N/A"}  |  PIN: ${c["pincode"] ?? "N/A"}', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(isHindi ? 'बंद करें' : 'Close Profile'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddCustomerModal(BuildContext context, bool isHindi, [Map<String, dynamic>? existing]) {
    final themeProvider = Provider.of<TenantThemeProvider>(context, listen: false);

    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final phoneCtrl = TextEditingController(text: existing?['phone'] ?? '');
    final emailCtrl = TextEditingController(text: existing?['email'] ?? '');
    final whatsappCtrl = TextEditingController(text: existing?['whatsapp'] ?? existing?['phone'] ?? '');
    final fatherCtrl = TextEditingController(text: existing?['fatherName'] ?? '');
    final addressCtrl = TextEditingController(text: existing?['address'] ?? '');
    final villageCtrl = TextEditingController(text: existing?['village'] ?? '');
    final poCtrl = TextEditingController(text: existing?['po'] ?? '');
    final psCtrl = TextEditingController(text: existing?['ps'] ?? '');
    final distCtrl = TextEditingController(text: existing?['dist'] ?? '');
    final pincodeCtrl = TextEditingController(text: existing?['pincode'] ?? '');
    final udhaarCtrl = TextEditingController(text: (existing?['udhaar'] ?? 0.0).toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
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
                        ? (isHindi ? 'ग्राहक अपडेट करें (Edit Master)' : 'Edit Customer Master Profile')
                        : (isHindi ? 'नया ग्राहक जोड़ें' : 'Add New Customer Master'),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 12),
              
              const Text('PRIMARY CONTACT INFORMATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: isHindi ? 'ग्राहक नाम *' : 'Customer Name *',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: fatherCtrl,
                      decoration: InputDecoration(
                        labelText: isHindi ? 'पिता का नाम' : 'Father\'s Name',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: isHindi ? 'मोबाइल नंबर *' : 'Phone Number *',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: whatsappCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: isHindi ? 'व्हाट्सएप नंबर' : 'WhatsApp Number',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: isHindi ? 'ईमेल (Optional)' : 'Email Address',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),

              const SizedBox(height: 16),
              const Text('FULL ADDRESS DETAILS (VILLAGE / PO / PS / DIST)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
              const SizedBox(height: 8),
              TextField(
                controller: addressCtrl,
                decoration: InputDecoration(
                  labelText: isHindi ? 'पता / मकान / गली (Street/Address)' : 'House No, Street, Landmark',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: villageCtrl,
                      decoration: InputDecoration(
                        labelText: isHindi ? 'गाँव / कस्बा (Village)' : 'Village / Town',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: poCtrl,
                      decoration: InputDecoration(
                        labelText: isHindi ? 'डाकघर (Post Office / P.O.)' : 'Post Office (P.O.)',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: psCtrl,
                      decoration: InputDecoration(
                        labelText: isHindi ? 'थाना (Police Station / P.S.)' : 'Police Station (P.S.)',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: distCtrl,
                      decoration: InputDecoration(
                        labelText: isHindi ? 'जिला (District / Dist)' : 'District (Dist)',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: pincodeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isHindi ? 'पिन कोड (PIN Code)' : 'PIN Code',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: udhaarCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isHindi ? 'उधार बकाया (₹ Udhaar Balance)' : 'Udhaar Balance (₹)',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
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
                      final newUdhaar = double.tryParse(udhaarCtrl.text) ?? 0.0;

                      final record = {
                        'name': nameCtrl.text.trim(),
                        'phone': phoneStr.trim(),
                        'email': emailCtrl.text.trim(),
                        'whatsapp': whatsappCtrl.text.trim(),
                        'fatherName': fatherCtrl.text.trim(),
                        'address': addressCtrl.text.trim(),
                        'village': villageCtrl.text.trim(),
                        'po': poCtrl.text.trim(),
                        'ps': psCtrl.text.trim(),
                        'dist': distCtrl.text.trim(),
                        'pincode': pincodeCtrl.text.trim(),
                        'udhaar': newUdhaar,
                        'lastTx': existing != null ? 'Profile Updated' : 'Registered Today',
                      };

                      final sqlite = SQLiteHelper.instance;
                      if (existing != null) {
                        await sqlite.updateCustomerRecord(existing['name'], record);
                      } else {
                        await sqlite.saveCustomer(record);
                      }

                      final syncProvider = Provider.of<SyncProvider>(context, listen: false);
                      await syncProvider.saveOfflineCustomer(nameCtrl.text, phoneStr);

                      await _loadCustomers();

                      if (mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              existing != null
                                  ? (isHindi ? 'ग्राहक मास्टर प्रोफाइल अपडेट हुई!' : 'Customer Master profile updated!')
                                  : (isHindi ? 'ग्राहक सफलतापूर्‍वक सहेजा गया!' : 'Customer saved successfully!'),
                            ),
                            backgroundColor: Colors.green.shade700,
                          ),
                        );
                      }
                    }
                  },
                  child: Text(
                    existing != null ? (isHindi ? 'अपडेट सेव करें' : 'Update Profile') : (isHindi ? 'ग्राहक सेव करें' : 'Save Customer Profile'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
