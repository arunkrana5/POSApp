import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/sync_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/notification_provider.dart';
import '../widgets/app_drawer.dart';
import '../widgets/notification_bell_icon.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double _todaySales = 0.0;
  double _totalRevenue = 0.0;
  double _totalUdhaar = 0.0;
  int _lowStockCount = 0;
  double _todayProfit = 0.0;
  double _cashSales = 0.0;
  double _upiSales = 0.0;
  double _udhaarSales = 0.0;
  int _totalSalesCount = 0;
  List<Map<String, dynamic>> _recentTransactions = [];
  List<Map<String, dynamic>> _topSellingProducts = [];
  List<Map<String, dynamic>> _dailyTrend = [];
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
        Provider.of<NotificationProvider>(context, listen: false)
            .fetchNotifications(tenantId: auth.tenantId ?? 1, tenantCode: auth.tenantCode, token: auth.accessToken);
        _loadDashboardMetrics();
      }
    });
  }

  Future<void> _loadDashboardMetrics() async {
    if (!mounted) return;
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

      final baseUrl = ApiConfig.baseUrl.isNotEmpty ? ApiConfig.baseUrl : 'https://villageshop-api.onrender.com/api';

      // Fast server-side SQL aggregate metrics endpoint
      bool aggregateFetched = false;
      try {
        final resMetrics = await http.get(Uri.parse('$baseUrl/reports/dashboard-metrics$qStr'), headers: headers).timeout(const Duration(seconds: 8));
        if (resMetrics.statusCode == 200) {
          final mData = jsonDecode(resMetrics.body);
          if (mData is Map<String, dynamic>) {
            final tRevenue = (mData['todayRevenue'] as num?)?.toDouble() ?? 0.0;
            final totRev = (mData['totalRevenue'] as num?)?.toDouble() ?? 0.0;
            final tUdhaar = (mData['totalUdhaar'] as num?)?.toDouble() ?? 0.0;
            final lStock = (mData['lowStockCount'] as num?)?.toInt() ?? 0;
            final cash = (mData['cashSales'] as num?)?.toDouble() ?? 0.0;
            final upi = (mData['upiSales'] as num?)?.toDouble() ?? 0.0;
            final udhaar = (mData['udhaarSales'] as num?)?.toDouble() ?? 0.0;
            final sCount = (mData['totalSales'] as num?)?.toInt() ?? 0;
            final rSales = List<Map<String, dynamic>>.from(mData['recentSales'] ?? []);
            final topProd = List<Map<String, dynamic>>.from(mData['topSellingProducts'] ?? []);
            final trend = List<Map<String, dynamic>>.from(mData['dailyTrend'] ?? []);

            if (mounted) {
              setState(() {
                _todaySales = tRevenue;
                _totalRevenue = totRev;
                _totalUdhaar = tUdhaar;
                _lowStockCount = lStock;
                _cashSales = cash;
                _upiSales = upi;
                _udhaarSales = udhaar;
                _totalSalesCount = sCount;
                _todayProfit = (tRevenue > 0 ? tRevenue : totRev) * 0.15;
                _recentTransactions = rSales;
                _topSellingProducts = topProd;
                _dailyTrend = trend;
              });
            }
            aggregateFetched = true;
          }
        }
      } catch (_) {}

      if (!aggregateFetched) {
        // Fallback to individual endpoints if aggregate endpoint is unreachable
        double salesSum = 0.0;
        List<Map<String, dynamic>> salesList = [];

        try {
          final resSales = await http.get(Uri.parse('$baseUrl/sales$qStr'), headers: headers).timeout(const Duration(seconds: 8));
          if (resSales.statusCode == 200) {
            final dynamic raw = jsonDecode(resSales.body);
            final List<dynamic> sData = raw is List ? raw : (raw['items'] as List? ?? []);
            salesList = sData.map((s) => Map<String, dynamic>.from(s)).toList();
            for (var s in salesList) {
              salesSum += (s['totalAmount'] as num?)?.toDouble() ?? 0.0;
            }
          }
        } catch (_) {}

        double udhaarSum = 0.0;
        try {
          final resCust = await http.get(Uri.parse('$baseUrl/customers$qStr'), headers: headers).timeout(const Duration(seconds: 8));
          if (resCust.statusCode == 200) {
            final dynamic raw = jsonDecode(resCust.body);
            final List<dynamic> cData = raw is List ? raw : (raw['items'] as List? ?? []);
            for (var c in cData) {
              udhaarSum += (c['udhaar'] as num?)?.toDouble() ?? 0.0;
            }
          }
        } catch (_) {}

        int lowStock = 0;
        try {
          final resProd = await http.get(Uri.parse('$baseUrl/Stock$qStr'), headers: headers).timeout(const Duration(seconds: 8));
          if (resProd.statusCode == 200) {
            final dynamic raw = jsonDecode(resProd.body);
            final List<dynamic> pData = raw is List ? raw : (raw['items'] as List? ?? []);
            for (var p in pData) {
              final stock = (p['currentStock'] as num?)?.toInt() ?? 0;
              final minStock = (p['minimumStock'] as num?)?.toInt() ?? 5;
              if (stock <= minStock) lowStock++;
            }
          }
        } catch (_) {}

        if (mounted) {
          setState(() {
            _todaySales = salesSum;
            _totalRevenue = salesSum;
            _totalUdhaar = udhaarSum;
            _lowStockCount = lowStock;
            _todayProfit = salesSum * 0.15;
            _recentTransactions = salesList.take(6).toList();
          });
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoadingMetrics = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final syncProvider = Provider.of<SyncProvider>(context);
    final themeProvider = Provider.of<TenantThemeProvider>(context);

    final isHindi = localeProvider.isHindi;

    return Scaffold(
      backgroundColor: themeProvider.pageBgColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: themeProvider.primaryColor,
        title: Row(
          children: [
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
                  fontSize: 15 * themeProvider.fontSizeScale,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        actions: [
          const NotificationBellIcon(),
          IconButton(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(),
            icon: Icon(
              localeProvider.isHindi ? Icons.g_translate_rounded : Icons.language_rounded,
              color: Colors.white,
              size: 20,
            ),
            tooltip: 'Switch Language',
            onPressed: () {
              localeProvider.setLocale(
                localeProvider.isHindi ? const Locale('en') : const Locale('hi'),
              );
            },
          ),
          IconButton(
            padding: const EdgeInsets.only(left: 4, right: 10),
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
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
                  // 1. Executive Top Greeting Banner
                  _buildGreetingBanner(context, isHindi, themeProvider),
                  const SizedBox(height: 16),

                  // 2. Metric Summary Cards (4 Grids)
                  _buildStatsGrid(context, isHindi, themeProvider),
                  const SizedBox(height: 16),

                  // 3. Payment Collection Split (Cash vs UPI vs Udhaar Bar)
                  _buildPaymentSplitBar(context, isHindi, themeProvider),
                  const SizedBox(height: 16),

                  // 4. Analytics Row: 7-Day Sales Trend & Top Selling Products
                  _buildAnalyticsSection(context, isHindi, themeProvider),
                  const SizedBox(height: 20),

                  // 5. Quick Actions Row
                  Text(
                    isHindi ? 'त्वरित कार्य' : 'Quick Actions',
                    style: TextStyle(
                      fontFamily: themeProvider.fontFamily,
                      fontSize: 17 * themeProvider.fontSizeScale,
                      fontWeight: FontWeight.bold,
                      color: themeProvider.textColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildQuickActionsGrid(context, isHindi, themeProvider),
                  const SizedBox(height: 24),

                  // 6. Recent Transactions Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.history_rounded, size: 20, color: themeProvider.primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            isHindi ? 'हाल के लेन-देन' : 'Recent Transactions',
                            style: TextStyle(
                              fontFamily: themeProvider.fontFamily,
                              fontSize: 17 * themeProvider.fontSizeScale,
                              fontWeight: FontWeight.bold,
                              color: themeProvider.textColor,
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                        label: Text(
                          isHindi ? 'सभी देखें' : 'View Audit Ledger',
                          style: TextStyle(
                            fontFamily: themeProvider.fontFamily,
                            fontWeight: FontWeight.bold,
                            fontSize: 13 * themeProvider.fontSizeScale,
                          ),
                        ),
                        onPressed: () {
                          Navigator.pushNamed(context, '/reports');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 7. Recent Transactions List Feed
                  _buildRecentTransactionsList(context, isHindi, themeProvider),
                  const SizedBox(height: 32),
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
          isHindi ? '+ नया बिल बनाएँ' : '+ New Bill',
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

  // Modern Greeting & Store Status Banner
  Widget _buildGreetingBanner(BuildContext context, bool isHindi, TenantThemeProvider themeProvider) {
    final now = DateTime.now();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dateStr = '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: themeProvider.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.storefront_rounded, color: themeProvider.primaryColor, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isHindi ? 'पीओएस डैशबोर्ड एवं काउंटर' : 'POS Executive Dashboard',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$_totalSalesCount ${isHindi ? "कुल बिल" : "Bills"} • $dateStr',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isHindi ? 'लाइव सिंक' : 'Live Sync',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 4 Executive KPI Cards
  Widget _buildStatsGrid(BuildContext context, bool isHindi, TenantThemeProvider themeProvider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 700;
        final displaySales = _todaySales > 0 ? _todaySales : _totalRevenue;
        final salesSub = _todaySales > 0
            ? 'Total: ₹ ${_totalRevenue.toStringAsFixed(0)}'
            : (isHindi ? 'कुल कारोबार' : 'Gross Turnover');

        return GridView.count(
          crossAxisCount: isDesktop ? 4 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: isDesktop ? 2.1 : 1.75,
          children: [
            _buildStatCard(
              context,
              isHindi ? 'आज की बिक्री' : 'Sales Revenue',
              '₹ ${displaySales.toStringAsFixed(2)}',
              salesSub,
              Icons.payments_rounded,
              themeProvider.amountColor,
              themeProvider.amountColor.withOpacity(0.1),
              themeProvider,
            ),
            _buildStatCard(
              context,
              isHindi ? 'कुल उधार' : 'Total Udhaar',
              '₹ ${_totalUdhaar.toStringAsFixed(2)}',
              _totalUdhaar > 0 ? (isHindi ? 'वसूली योग्य' : 'Outstanding Due') : (isHindi ? 'शून्य बकाया' : 'All Cleared'),
              Icons.account_balance_wallet_rounded,
              Colors.red.shade700,
              Colors.red.shade50,
              themeProvider,
            ),
            _buildStatCard(
              context,
              isHindi ? 'कम स्टॉक' : 'Low Stock',
              '$_lowStockCount ${isHindi ? "सामान" : "Items"}',
              _lowStockCount > 0 ? (isHindi ? 'रीऑर्डर जरूरी' : 'Needs Reorder') : (isHindi ? 'स्टॉक सुरक्षित' : 'Healthy Stock'),
              Icons.warning_amber_rounded,
              themeProvider.secondaryColor,
              themeProvider.secondaryColor.withOpacity(0.1),
              themeProvider,
            ),
            _buildStatCard(
              context,
              isHindi ? 'अनुमानित लाभ' : 'Estimated Profit',
              '₹ ${_todayProfit.toStringAsFixed(2)}',
              isHindi ? '~15% ग्रॉस मार्जिन' : '~15% Gross Margin',
              Icons.trending_up_rounded,
              const Color(0xFF059669),
              const Color(0xFF059669).withOpacity(0.1),
              themeProvider,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
    Color bgColor,
    TenantThemeProvider themeProvider,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: themeProvider.cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
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
                    fontSize: 12 * themeProvider.fontSizeScale,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.textColor.withOpacity(0.7),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontFamily: themeProvider.fontFamily,
                    fontSize: 18 * themeProvider.fontSizeScale,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Modern Payment Collection Split Bar
  Widget _buildPaymentSplitBar(BuildContext context, bool isHindi, TenantThemeProvider themeProvider) {
    final double totalSplit = _cashSales + _upiSales + _udhaarSales;
    final double effectiveTotal = totalSplit > 0 ? totalSplit : (_totalRevenue > 0 ? _totalRevenue : 1.0);

    final cashRatio = (_cashSales / effectiveTotal).clamp(0.0, 1.0);
    final upiRatio = (_upiSales / effectiveTotal).clamp(0.0, 1.0);
    final udhaarRatio = (_udhaarSales / effectiveTotal).clamp(0.0, 1.0);

    final cashPct = (cashRatio * 100).toStringAsFixed(0);
    final upiPct = (upiRatio * 100).toStringAsFixed(0);
    final udhaarPct = (udhaarRatio * 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.pie_chart_rounded, size: 18, color: themeProvider.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    isHindi ? 'भुगतान एवं नकदी विभाजन' : 'Payment Collection Split',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              Text(
                'Total: ₹ ${effectiveTotal.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Multi-color segmented progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (cashRatio > 0)
                    Expanded(
                      flex: (cashRatio * 100).toInt(),
                      child: Container(color: const Color(0xFF10B981)), // Green
                    ),
                  if (upiRatio > 0)
                    Expanded(
                      flex: (upiRatio * 100).toInt(),
                      child: Container(color: const Color(0xFF3B82F6)), // Blue
                    ),
                  if (udhaarRatio > 0)
                    Expanded(
                      flex: (udhaarRatio * 100).toInt(),
                      child: Container(color: const Color(0xFFEF4444)), // Red
                    ),
                  if (totalSplit <= 0)
                    Expanded(
                      flex: 100,
                      child: Container(color: Colors.grey.shade200),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Legend chips with exact amounts
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSplitLegendItem(
                label: isHindi ? 'नकद (Cash)' : 'Cash',
                amount: '₹ ${_cashSales.toStringAsFixed(0)}',
                percent: '$cashPct%',
                color: const Color(0xFF10B981),
              ),
              _buildSplitLegendItem(
                label: isHindi ? 'यूपीआई (UPI)' : 'UPI',
                amount: '₹ ${_upiSales.toStringAsFixed(0)}',
                percent: '$upiPct%',
                color: const Color(0xFF3B82F6),
              ),
              _buildSplitLegendItem(
                label: isHindi ? 'उधार (Due)' : 'Udhaar',
                amount: '₹ ${_udhaarSales.toStringAsFixed(0)}',
                percent: '$udhaarPct%',
                color: const Color(0xFFEF4444),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSplitLegendItem({
    required String label,
    required String amount,
    required String percent,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
            Text('$amount ($percent)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ],
    );
  }

  // Modern Analytics Row: 7-Day Trend + Instant Top Selling Products
  Widget _buildAnalyticsSection(BuildContext context, bool isHindi, TenantThemeProvider themeProvider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 768;

        if (isDesktop) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: _build7DayTrendCard(isHindi, themeProvider),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 5,
                child: _buildTopSellingCard(isHindi, themeProvider),
              ),
            ],
          );
        }

        return Column(
          children: [
            _build7DayTrendCard(isHindi, themeProvider),
            const SizedBox(height: 14),
            _buildTopSellingCard(isHindi, themeProvider),
          ],
        );
      },
    );
  }

  // 7-Day Sales Trend Bar Chart (Clean Native Widget)
  Widget _build7DayTrendCard(bool isHindi, TenantThemeProvider themeProvider) {
    final double maxDaily = _dailyTrend.isNotEmpty
        ? _dailyTrend.map<double>((d) => ((d['total'] as num?)?.toDouble() ?? 0.0)).reduce(max)
        : 1.0;
    final effectiveMax = maxDaily > 0 ? maxDaily : 1.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.bar_chart_rounded, size: 18, color: themeProvider.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    isHindi ? '7-दिवसीय बिक्री ट्रेंड' : '7-Day Sales Trend',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  isHindi ? 'दैनिक वॉल्यूम' : 'Daily Vol',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_dailyTrend.isEmpty)
            SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  isHindi ? 'ट्रेंड डेटा लोड हो रहा है...' : 'Trend data updating...',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            )
          else
            SizedBox(
              height: 130,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: _dailyTrend.map((d) {
                  final day = d['day']?.toString() ?? '';
                  final total = ((d['total'] as num?)?.toDouble() ?? 0.0);
                  final ratio = (total / effectiveMax).clamp(0.08, 1.0);
                  final kStr = total >= 1000 ? '${(total / 1000).toStringAsFixed(1)}k' : total.toStringAsFixed(0);

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            total > 0 ? '₹$kStr' : '',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 90 * ratio,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  themeProvider.primaryColor,
                                  themeProvider.primaryColor.withOpacity(0.6),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            day,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // Top Selling Products with INSTANT Progress Bar (Zero Delay from SQL Server)
  Widget _buildTopSellingCard(bool isHindi, TenantThemeProvider themeProvider) {
    final double maxRevenue = _topSellingProducts.isNotEmpty
        ? (_topSellingProducts.map<double>((p) => ((p['revenue'] as num?)?.toDouble() ?? 0.0)).reduce(max))
        : 1.0;
    final effectiveMax = maxRevenue > 0 ? maxRevenue : 1.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.local_fire_department_rounded, size: 18, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Text(
                    isHindi ? 'टॉप बिकने वाले सामान' : 'Top Selling Items',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  isHindi ? 'फास्ट सेलर' : 'Fast Movers',
                  style: TextStyle(fontSize: 10, color: Colors.orange.shade900, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_topSellingProducts.isEmpty)
            SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  isHindi ? 'अभी कोई बिक्री रिकॉर्ड नहीं है' : 'No items sold yet',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            )
          else
            Column(
              children: _topSellingProducts.take(4).toList().asMap().entries.map((entry) {
                final index = entry.key;
                final prod = entry.value;
                final name = prod['name']?.toString() ?? 'Item';
                final qty = prod['quantity'] ?? 0;
                final revenue = ((prod['revenue'] as num?)?.toDouble() ?? 0.0);
                final ratio = (revenue / effectiveMax).clamp(0.05, 1.0);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: index == 0 ? Colors.amber.shade100 : Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '#${index + 1}',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: index == 0 ? Colors.amber.shade900 : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                            child: Text(
                              '$qty sold',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '₹ ${revenue.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: themeProvider.amountColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          backgroundColor: Colors.grey.shade100,
                          color: index == 0 ? themeProvider.primaryColor : themeProvider.secondaryColor,
                          minHeight: 5,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // Quick Action Buttons
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
                  title: isHindi ? 'नया बिल' : 'New Bill',
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
                    title: isHindi ? 'नया बिल' : 'New Bill',
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

  // Recent Transactions Feed
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
        final inv = tx['invoiceNumber']?.toString() ?? tx['id']?.toString() ?? 'INV';
        final cust = tx['customerName']?.toString() ?? tx['status']?.toString() ?? 'Walk-in Customer';
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
                fontSize: 14 * themeProvider.fontSizeScale,
                color: themeProvider.textColor,
              ),
            ),
            subtitle: Text(
              '$inv • $time',
              style: TextStyle(
                fontFamily: themeProvider.fontFamily,
                fontSize: 11 * themeProvider.fontSizeScale,
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
                    fontSize: 14 * themeProvider.fontSizeScale,
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
