import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as path;
import '../models/sale.dart';
import '../providers/auth_provider.dart';
import '../providers/sale_provider.dart';

class NewSaleScreen extends StatefulWidget {
  const NewSaleScreen({super.key});

  @override
  State<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends State<NewSaleScreen> {
  final _amountController = TextEditingController(text: '150');
  final _paidController = TextEditingController(text: '150');
  String _paymentMode = 'Cash';

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final saleProv = Provider.of<SaleProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("नई बिक्री दर्ज करें (New Sale)"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "कुल राशि / Total Amount (₹)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.currency_rupee),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _paidController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "दिया गया नगद / Paid Amount (₹)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.payments),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _paymentMode,
              decoration: const InputDecoration(
                labelText: "भुगतान का प्रकार (Payment Mode)",
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Cash', child: Text('नगद (Cash)')),
                DropdownMenuItem(value: 'UPI', child: Text('यूपीआई / ऑनलाइन (UPI)')),
                DropdownMenuItem(value: 'Udhaar', child: Text('उधार खाता (Udhaar Credit)')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _paymentMode = val);
              },
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                ),
                onPressed: saleProv.isProcessing
                    ? null
                    : () async {
                        final total = double.tryParse(_amountController.text) ?? 0.0;
                        final paid = double.tryParse(_paidController.text) ?? 0.0;
                        final clientTxId = "MOB-${DateTime.now().millisecondsSinceEpoch}";

                        final items = [
                          OfflineSaleItem(
                            productId: 1,
                            productName: "General Item",
                            quantity: 1,
                            unitPrice: total,
                          )
                        ];

                        final res = await saleProv.recordSale(
                          clientTxId: clientTxId,
                          totalAmount: total,
                          paidAmount: paid,
                          paymentMode: _paymentMode,
                          items: items,
                          token: auth.accessToken ?? '',
                        );

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(res.message), backgroundColor: res.status ? Colors.green : Colors.red),
                          );
                          if (res.status) Navigator.pop(context);
                        }
                      },
                child: saleProv.isProcessing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("बिक्री पक्की करें (COMPLETE SALE)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
