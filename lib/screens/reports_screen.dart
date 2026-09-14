import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/app_drawer.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isHindi = Provider.of<LocaleProvider>(context).isHindi;
    final themeProvider = Provider.of<TenantThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.pageBgColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(
          isHindi ? 'रिपोर्ट और कमाई' : 'Reports & Analytics',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Period Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isHindi ? 'बिक्री सारांश' : 'Sales Overview',
                  style: TextStyle(
                    fontFamily: themeProvider.fontFamily,
                    fontSize: 18 * themeProvider.fontSizeScale,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.textColor,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: themeProvider.cardBgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: themeProvider.textColor.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        isHindi ? 'इस महीने' : 'This Month',
                        style: TextStyle(
                          fontFamily: themeProvider.fontFamily,
                          fontWeight: FontWeight.bold,
                          fontSize: 13 * themeProvider.fontSizeScale,
                          color: themeProvider.textColor,
                        ),
                      ),
                      Icon(Icons.arrow_drop_down, color: themeProvider.textColor),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Summary Grid
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.5,
              children: [
                _buildReportCard(context, isHindi ? 'कुल बिक्री' : 'Total Revenue', '₹ 84,200', Icons.payments_rounded, themeProvider.amountColor, themeProvider),
                _buildReportCard(context, isHindi ? 'कुल लाभ' : 'Estimated Profit', '₹ 14,800', Icons.trending_up_rounded, themeProvider.buttonBgColor, themeProvider),
                _buildReportCard(context, isHindi ? 'नकद एकत्र' : 'Cash Collected', '₹ 71,800', Icons.account_balance_rounded, themeProvider.accentColor, themeProvider),
                _buildReportCard(context, isHindi ? 'उधार दिया' : 'Udhaar Given', '₹ 12,400', Icons.assignment_late_rounded, Colors.red.shade700, themeProvider),
              ],
            ),
            const SizedBox(height: 24),

            // Top Selling Products List
            Text(
              isHindi ? 'सबसे ज्यादा बिकने वाला सामान' : 'Top Selling Items',
              style: TextStyle(
                fontFamily: themeProvider.fontFamily,
                fontSize: 18 * themeProvider.fontSizeScale,
                fontWeight: FontWeight.bold,
                color: themeProvider.textColor,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: themeProvider.cardBgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: themeProvider.textColor.withOpacity(0.08)),
              ),
              child: ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.blue, child: Text('1', style: TextStyle(color: Colors.white))),
                    title: Text('Aashirvaad Atta 5kg', style: TextStyle(fontFamily: themeProvider.fontFamily, fontWeight: FontWeight.bold, color: themeProvider.textColor)),
                    subtitle: Text('142 pkts sold', style: TextStyle(fontFamily: themeProvider.fontFamily, color: themeProvider.textColor.withOpacity(0.6))),
                    trailing: Text('₹ 9,240', style: TextStyle(fontFamily: themeProvider.fontFamily, fontWeight: FontWeight.bold, fontSize: 15 * themeProvider.fontSizeScale, color: themeProvider.amountColor)),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.teal, child: Text('2', style: TextStyle(color: Colors.white))),
                    title: Text('Fortune Mustard Oil 1L', style: TextStyle(fontFamily: themeProvider.fontFamily, fontWeight: FontWeight.bold, color: themeProvider.textColor)),
                    subtitle: Text('98 pouches sold', style: TextStyle(fontFamily: themeProvider.fontFamily, color: themeProvider.textColor.withOpacity(0.6))),
                    trailing: Text('₹ 5,510', style: TextStyle(fontFamily: themeProvider.fontFamily, fontWeight: FontWeight.bold, fontSize: 15 * themeProvider.fontSizeScale, color: themeProvider.amountColor)),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.amber, child: Text('3', style: TextStyle(color: Colors.white))),
                    title: Text('Surf Excel Quick Wash 1kg', style: TextStyle(fontFamily: themeProvider.fontFamily, fontWeight: FontWeight.bold, color: themeProvider.textColor)),
                    subtitle: Text('76 pkts sold', style: TextStyle(fontFamily: themeProvider.fontFamily, color: themeProvider.textColor.withOpacity(0.6))),
                    trailing: Text('₹ 5,040', style: TextStyle(fontFamily: themeProvider.fontFamily, fontWeight: FontWeight.bold, fontSize: 15 * themeProvider.fontSizeScale, color: themeProvider.amountColor)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(BuildContext context, String title, String value, IconData icon, Color color, TenantThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: themeProvider.cardBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeProvider.textColor.withOpacity(0.08)),
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
              Text(
                title,
                style: TextStyle(
                  fontFamily: themeProvider.fontFamily,
                  fontSize: 12 * themeProvider.fontSizeScale,
                  fontWeight: FontWeight.w600,
                  color: themeProvider.textColor.withOpacity(0.7),
                ),
              ),
              Icon(icon, size: 20, color: color),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: themeProvider.fontFamily,
              fontSize: 18 * themeProvider.fontSizeScale,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
