import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/sync_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/app_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SyncProvider>(context, listen: false).loadPendingCount();
      Provider.of<TenantThemeProvider>(context, listen: false).fetchAndApplyConfig();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final syncProvider = Provider.of<SyncProvider>(context);
    final themeProvider = Provider.of<TenantThemeProvider>(context);

    final isHindi = localeProvider.isHindi;
    final tenantName = authProvider.tenantName;
    final username = authProvider.username;

    return Scaffold(
      backgroundColor: themeProvider.pageBgColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: themeProvider.primaryColor,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: themeProvider.secondaryColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.storefront_rounded, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                (authProvider.tenantName != null && authProvider.tenantName!.isNotEmpty)
                    ? authProvider.tenantName!
                    : themeProvider.tenantName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: themeProvider.fontFamily,
                  fontWeight: FontWeight.bold,
                  fontSize: 16 * themeProvider.fontSizeScale,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              localeProvider.isHindi ? Icons.g_translate_rounded : Icons.language_rounded,
              color: Colors.white,
            ),
            tooltip: 'Switch Language',
            onPressed: () {
              localeProvider.setLocale(
                localeProvider.isHindi ? const Locale('en') : const Locale('hi'),
              );
            },
          ),
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications_none_rounded, size: 26, color: Colors.white),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      '2',
                      style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await themeProvider.fetchAndApplyConfig();
          await syncProvider.syncNow();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Banner & Quick Sync Pill
              _buildGreetingHeader(context, username ?? tenantName, isHindi, syncProvider, themeProvider),
              const SizedBox(height: 20),

              // Metric Summary Cards (4 Grids)
              Text(
                isHindi ? 'आज का व्यापार सारांश' : 'Today\'s Business Summary',
                style: TextStyle(
                  fontFamily: themeProvider.fontFamily,
                  fontSize: 18 * themeProvider.fontSizeScale,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.textColor,
                ),
              ),
              const SizedBox(height: 12),
              _buildStatsGrid(context, isHindi, themeProvider),
              const SizedBox(height: 24),

              // Quick Actions Row
              Text(
                isHindi ? 'त्वरित कार्य' : 'Quick Actions',
                style: TextStyle(
                  fontFamily: themeProvider.fontFamily,
                  fontSize: 18 * themeProvider.fontSizeScale,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.textColor,
                ),
              ),
              const SizedBox(height: 12),
              _buildQuickActionsGrid(context, isHindi, themeProvider),
              const SizedBox(height: 24),

              // Recent Transactions Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isHindi ? 'हाल के लेन-देन' : 'Recent Transactions',
                    style: TextStyle(
                      fontFamily: themeProvider.fontFamily,
                      fontSize: 18 * themeProvider.fontSizeScale,
                      fontWeight: FontWeight.bold,
                      color: themeProvider.textColor,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/reports');
                    },
                    child: Text(
                      isHindi ? 'सभी देखें →' : 'View All →',
                      style: TextStyle(
                        fontFamily: themeProvider.fontFamily,
                        fontWeight: FontWeight.bold,
                        fontSize: 14 * themeProvider.fontSizeScale,
                        color: themeProvider.buttonBgColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Recent Transactions List Feed
              _buildRecentTransactionsList(context, isHindi, themeProvider),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: themeProvider.buttonBgColor,
        elevation: 4,
        icon: Icon(Icons.add_shopping_cart_rounded, color: themeProvider.buttonTextColor),
        label: Text(
          isHindi ? '+ नया बिल बनाएँ' : '+ New Sale / Bill',
          style: TextStyle(
            fontFamily: themeProvider.fontFamily,
            fontWeight: FontWeight.bold,
            fontSize: 14 * themeProvider.fontSizeScale,
            color: themeProvider.buttonTextColor,
          ),
        ),
        onPressed: () {
          Navigator.pushNamed(context, '/pos');
        },
      ),
    );
  }

  Widget _buildGreetingHeader(BuildContext context, String? userName, bool isHindi, SyncProvider syncProvider, TenantThemeProvider themeProvider) {
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeProvider.cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeProvider.textColor.withOpacity(0.08), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isHindi ? 'नमस्ते, ${userName ?? "दुकानदार"}' : 'Welcome, ${userName ?? "Shopkeeper"} 👋',
                style: TextStyle(
                  fontFamily: themeProvider.fontFamily,
                  fontSize: 18 * themeProvider.fontSizeScale,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${isHindi ? "दिनांक" : "Date"}: $dateStr',
                style: TextStyle(
                  fontFamily: themeProvider.fontFamily,
                  color: themeProvider.textColor.withOpacity(0.6),
                  fontSize: 13 * themeProvider.fontSizeScale,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: syncProvider.pendingSyncCount > 0 ? Colors.orange.shade800 : themeProvider.accentColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  syncProvider.pendingSyncCount > 0 ? Icons.cloud_queue_rounded : Icons.check_circle_outline_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  syncProvider.pendingSyncCount > 0
                      ? '${syncProvider.pendingSyncCount} ${isHindi ? "पेंडिंग" : "Pending"}'
                      : (isHindi ? 'ऑनलाइन' : 'Online'),
                  style: TextStyle(
                    fontFamily: themeProvider.fontFamily,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12 * themeProvider.fontSizeScale,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, bool isHindi, TenantThemeProvider themeProvider) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          context,
          isHindi ? 'आज की बिक्री' : 'Today\'s Sales',
          '₹ 4,850',
          Icons.payments_rounded,
          themeProvider.amountColor,
          themeProvider.amountColor.withOpacity(0.1),
          themeProvider,
        ),
        _buildStatCard(
          context,
          isHindi ? 'कुल उधार बकाया' : 'Total Udhaar',
          '₹ 12,400',
          Icons.account_balance_wallet_rounded,
          Colors.red.shade700,
          Colors.red.shade50,
          themeProvider,
        ),
        _buildStatCard(
          context,
          isHindi ? 'कम स्टॉक सामान' : 'Low Stock Items',
          '3 Items',
          Icons.warning_amber_rounded,
          themeProvider.secondaryColor,
          themeProvider.secondaryColor.withOpacity(0.1),
          themeProvider,
        ),
        _buildStatCard(
          context,
          isHindi ? 'आज का लाभ' : 'Today\'s Profit',
          '₹ 1,120',
          Icons.trending_up_rounded,
          themeProvider.buttonBgColor,
          themeProvider.buttonBgColor.withOpacity(0.1),
          themeProvider,
        ),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color, Color bgColor, TenantThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: themeProvider.cardBgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: themeProvider.textColor.withOpacity(0.08), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 3)),
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
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: themeProvider.fontFamily,
                    fontSize: 13 * themeProvider.fontSizeScale,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.textColor.withOpacity(0.8),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 18, color: color),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: themeProvider.fontFamily,
              fontSize: 20 * themeProvider.fontSizeScale,
              fontWeight: FontWeight.bold,
              color: value.contains('₹') ? themeProvider.amountColor : themeProvider.textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context, bool isHindi, TenantThemeProvider themeProvider) {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            context,
            title: isHindi ? 'नया बिल (POS)' : 'New Bill (POS)',
            icon: Icons.point_of_sale_rounded,
            color: themeProvider.buttonBgColor,
            route: '/pos',
            themeProvider: themeProvider,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildActionButton(
            context,
            title: isHindi ? 'नया सामान' : 'Add Product',
            icon: Icons.add_box_rounded,
            color: themeProvider.secondaryColor,
            route: '/products',
            themeProvider: themeProvider,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildActionButton(
            context,
            title: isHindi ? 'उधार खाता' : 'Udhaar Ledger',
            icon: Icons.people_alt_rounded,
            color: themeProvider.accentColor,
            route: '/customers',
            themeProvider: themeProvider,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, {required String title, required IconData icon, required Color color, required String route, required TenantThemeProvider themeProvider}) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, route),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: themeProvider.cardBgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1.2),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: themeProvider.fontFamily,
                fontSize: 12 * themeProvider.fontSizeScale,
                fontWeight: FontWeight.bold,
                color: themeProvider.textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactionsList(BuildContext context, bool isHindi, TenantThemeProvider themeProvider) {
    final mockTransactions = [
      {'id': '#INV-1004', 'customer': 'Ramesh Kumar', 'amount': '₹ 450', 'mode': 'Cash', 'time': '10:45 AM'},
      {'id': '#INV-1003', 'customer': 'Suresh Patel', 'amount': '₹ 1,200', 'mode': 'Udhaar', 'time': '09:30 AM'},
      {'id': '#INV-1002', 'customer': 'Walk-in Customer', 'amount': '₹ 180', 'mode': 'UPI', 'time': 'Yesterday'},
    ];

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: mockTransactions.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 8),
      itemBuilder: (ctx, index) {
        final tx = mockTransactions[index];
        final isUdhaar = tx['mode'] == 'Udhaar';

        return Container(
          decoration: BoxDecoration(
            color: themeProvider.cardBgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: themeProvider.textColor.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
            ],
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isUdhaar ? Colors.red.shade100 : themeProvider.accentColor.withOpacity(0.15),
              child: Icon(
                isUdhaar ? Icons.account_balance_wallet_rounded : Icons.check_circle_rounded,
                color: isUdhaar ? Colors.red.shade800 : themeProvider.accentColor,
              ),
            ),
            title: Text(
              tx['customer']!,
              style: TextStyle(
                fontFamily: themeProvider.fontFamily,
                fontWeight: FontWeight.bold,
                fontSize: 15 * themeProvider.fontSizeScale,
                color: themeProvider.textColor,
              ),
            ),
            subtitle: Text(
              '${tx["id"]} • ${tx["time"]}',
              style: TextStyle(
                fontFamily: themeProvider.fontFamily,
                fontSize: 12 * themeProvider.fontSizeScale,
                color: themeProvider.textColor.withOpacity(0.6),
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  tx['amount']!,
                  style: TextStyle(
                    fontFamily: themeProvider.fontFamily,
                    fontSize: 16 * themeProvider.fontSizeScale,
                    fontWeight: FontWeight.bold,
                    color: isUdhaar ? Colors.red.shade700 : themeProvider.amountColor,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isUdhaar ? Colors.red.shade50 : themeProvider.accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tx['mode']!,
                    style: TextStyle(
                      fontFamily: themeProvider.fontFamily,
                      fontSize: 10 * themeProvider.fontSizeScale,
                      fontWeight: FontWeight.bold,
                      color: isUdhaar ? Colors.red.shade800 : themeProvider.accentColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
