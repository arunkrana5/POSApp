import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/sync_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/analytics_charts_widget.dart';
import '../widgets/app_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double _todaySales = 0.0;
  double _totalUdhaar = 0.0;
  int _lowStockCount = 0;
  double _todayProfit = 0.0;
  List<Map<String, dynamic>> _recentTransactions = [];
  List<Map<String, dynamic>> _salesList = [];
  bool _isLoadingMetrics = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (!auth.isAuthenticated) {
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        Provider.of<SyncProvider>(context, listen: false).loadPendingCount();
        Provider.of<TenantThemeProvider>(context, listen: false)
            .fetchAndApplyConfig(auth.accessToken ?? '', auth.tenantCode, auth.tenantId);
        _loadDashboardMetrics();
      }
    });
  }

  Future<void> _loadDashboardMetrics() async {
    setState(() => _isLoadingMetrics = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final tCode = auth.tenantCode ?? '';
      final tId = auth.tenantId ?? 0;
      final token = auth.accessToken ?? '';

      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        if (tId > 0) 'X-Tenant-Id': tId.toString(),
        if (tCode.isNotEmpty) 'X-Tenant-Code': tCode,
      };

      final qParams = <String>[];
      if (tId > 0) qParams.add('tenantId=$tId');
      if (tCode.isNotEmpty) qParams.add('tenantCode=$tCode');
      final qStr = qParams.isNotEmpty ? '?${qParams.join('&')}' : '';

      final responses = await Future.wait([
        http.get(Uri.parse('${ApiConfig.baseUrl}/sales$qStr'), headers: headers),
        http.get(Uri.parse('${ApiConfig.baseUrl}/customers$qStr'), headers: headers),
        http.get(Uri.parse('${ApiConfig.baseUrl}/products$qStr'), headers: headers),
      ]).timeout(const Duration(seconds: 10));

      double salesSum = 0.0;
      List<Map<String, dynamic>> salesList = [];
      if (responses[0].statusCode == 200) {
        final List<dynamic> sData = jsonDecode(responses[0].body);
        salesList = sData.map((s) => Map<String, dynamic>.from(s)).toList();
        for (var s in salesList) {
          salesSum += (s['totalAmount'] as num?)?.toDouble() ?? 0.0;
        }
      }

      double udhaarSum = 0.0;
      if (responses[1].statusCode == 200) {
        final List<dynamic> cData = jsonDecode(responses[1].body);
        for (var c in cData) {
          udhaarSum += (c['udhaar'] as num?)?.toDouble() ?? 0.0;
        }
      }

      int lowStock = 0;
      if (responses[2].statusCode == 200) {
        final List<dynamic> pData = jsonDecode(responses[2].body);
        for (var p in pData) {
          final stock = (p['currentStock'] as num?)?.toInt() ?? 0;
          final minStock = (p['minimumStock'] as num?)?.toInt() ?? 5;
          if (stock <= minStock) lowStock++;
        }
      }

      setState(() {
        _todaySales = salesSum;
        _totalUdhaar = udhaarSum;
        _lowStockCount = lowStock;
        _todayProfit = salesSum * 0.15; // 15% estimated profit margin
        _recentTransactions = salesList.take(6).toList();
        _salesList = salesList;
      });
    } catch (_) {}
    setState(() => _isLoadingMetrics = false);
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
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh Dashboard',
            onPressed: _loadDashboardMetrics,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await themeProvider.fetchAndApplyConfig();
          await syncProvider.syncNow();
          await _loadDashboardMetrics();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Banner & Quick Sync Pill
                  _buildGreetingHeader(context, username ?? tenantName, isHindi, syncProvider, themeProvider),
              const SizedBox(height: 20),

              // Interactive Real-time Analytics & Charts (Top Priority Position)
              AnalyticsChartsWidget(
                salesList: _salesList,
                isHindi: isHindi,
              ),
              const SizedBox(height: 24),

              // Metric Summary Cards (4 Grids)
              Text(
                isHindi ? 'आज का व्यापार सारांश (Live DB)' : 'Today\'s Business Summary (Live DB)',
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
                    isHindi ? 'हाल के लेन-देन (Recent DB Sales)' : 'Recent Transactions (Live DB)',
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 700;
        return GridView.count(
          crossAxisCount: isDesktop ? 4 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: isDesktop ? 2.0 : 1.5,
          children: [
            _buildStatCard(
              context,
              isHindi ? 'आज की बिक्री' : 'Today\'s Sales',
              '₹ ${_todaySales.toStringAsFixed(2)}',
              Icons.payments_rounded,
              themeProvider.amountColor,
              themeProvider.amountColor.withOpacity(0.1),
              themeProvider,
            ),
            _buildStatCard(
              context,
              isHindi ? 'कुल उधार बकाया' : 'Total Udhaar',
              '₹ ${_totalUdhaar.toStringAsFixed(2)}',
              Icons.account_balance_wallet_rounded,
              Colors.red.shade700,
              Colors.red.shade50,
              themeProvider,
            ),
            _buildStatCard(
              context,
              isHindi ? 'कम स्टॉक सामान' : 'Low Stock Alert',
              '$_lowStockCount ${isHindi ? "सामान" : "Items"}',
              Icons.warning_amber_rounded,
              themeProvider.secondaryColor,
              themeProvider.secondaryColor.withOpacity(0.1),
              themeProvider,
            ),
            _buildStatCard(
              context,
              isHindi ? 'अनुमानित लाभ' : 'Estimated Profit',
              '₹ ${_todayProfit.toStringAsFixed(2)}',
              Icons.trending_up_rounded,
              themeProvider.buttonBgColor,
              themeProvider.buttonBgColor.withOpacity(0.1),
              themeProvider,
            ),
          ],
        );
      },
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
              fontSize: 18 * themeProvider.fontSizeScale,
              fontWeight: FontWeight.bold,
              color: value.contains('₹') ? themeProvider.amountColor : themeProvider.textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context, bool isHindi, TenantThemeProvider themeProvider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 700;
        if (isDesktop) {
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
                  title: isHindi ? 'बिक्री इतिहास' : 'Sale History',
                  icon: Icons.receipt_long_rounded,
                  color: themeProvider.primaryColor,
                  route: '/sales-history',
                  themeProvider: themeProvider,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionButton(
                  context,
                  title: isHindi ? 'स्टॉक' : 'Stock',
                  icon: Icons.add_box_rounded,
                  color: themeProvider.secondaryColor,
                  route: '/stock',
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
        return Column(
          children: [
            Row(
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
                    title: isHindi ? 'बिक्री इतिहास' : 'Sale History',
                    icon: Icons.receipt_long_rounded,
                    color: themeProvider.primaryColor,
                    route: '/sales-history',
                    themeProvider: themeProvider,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    context,
                    title: isHindi ? 'स्टॉक' : 'Stock',
                    icon: Icons.add_box_rounded,
                    color: themeProvider.secondaryColor,
                    route: '/stock',
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
            ),
          ],
        );
      },
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
    if (_isLoadingMetrics) {
      return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
    }

    if (_recentTransactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: themeProvider.cardBgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            isHindi ? 'अभी कोई बिक्री दर्ज नहीं हुई है।' : 'No recent transactions recorded.',
            style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recentTransactions.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 8),
      itemBuilder: (ctx, index) {
        final tx = _recentTransactions[index];
        final inv = tx['id']?.toString() ?? 'INV';
        final cust = tx['customerName']?.toString() ?? 'Walk-in Customer';
        final amt = (tx['totalAmount'] as num?)?.toDouble() ?? 0.0;
        final mode = tx['paymentMode']?.toString() ?? 'Cash';
        final time = tx['createdAt']?.toString() ?? '';
        final isUdhaar = mode == 'Udhaar';

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
              cust,
              style: TextStyle(
                fontFamily: themeProvider.fontFamily,
                fontWeight: FontWeight.bold,
                fontSize: 15 * themeProvider.fontSizeScale,
                color: themeProvider.textColor,
              ),
            ),
            subtitle: Text(
              '$inv • $time',
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
                  '₹ ${amt.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontFamily: themeProvider.fontFamily,
                    fontSize: 15 * themeProvider.fontSizeScale,
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
                    mode,
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
