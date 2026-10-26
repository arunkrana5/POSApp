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
import '../widgets/pos_analytics_charts.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedDays = 7;
  double _totalRevenue = 0.0;
  double _totalUdhaar = 0.0;
  double _cashSales = 0.0;
  double _upiSales = 0.0;
  double _udhaarSales = 0.0;
  int _totalSalesCount = 0;
  List<Map<String, dynamic>> _topSellingProducts = [];
  List<Map<String, dynamic>> _dailyTrend = [];
  List<Map<String, dynamic>> _settlementBreakdown = [];
  List<Map<String, dynamic>> _categorySummary = [];
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
      qParams.add('days=$_selectedDays');
      final qStr = qParams.isNotEmpty ? '?${qParams.join('&')}' : '';

      final baseUrl = ApiConfig.baseUrl.isNotEmpty ? ApiConfig.baseUrl : 'https://villageshop-api.onrender.com/api';

      // Fast server-side SQL aggregate metrics endpoint
      bool aggregateFetched = false;
      try {
        final resMetrics = await http
            .get(Uri.parse('$baseUrl/reports/dashboard-metrics$qStr'), headers: headers)
            .timeout(const Duration(seconds: 8));

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
            final topProd = List<Map<String, dynamic>>.from(mData['topSellingProducts'] ?? []);
            final trend = List<Map<String, dynamic>>.from(mData['dailyTrend'] ?? []);
            final sett = List<Map<String, dynamic>>.from(mData['settlementBreakdown'] ?? []);
            final cat = List<Map<String, dynamic>>.from(mData['categorySummary'] ?? []);

            if (mounted) {
              setState(() {
                _totalRevenue = totRev;
                _totalUdhaar = tUdhaar;
                _cashSales = cash;
                _upiSales = upi;
                _udhaarSales = udhaar;
                _totalSalesCount = sCount;
                _topSellingProducts = topProd;
                _dailyTrend = trend;
                _settlementBreakdown = sett;
                _categorySummary = cat;
              });
            }
            aggregateFetched = true;
          }
        }
      } catch (_) {}

      if (!aggregateFetched) {
        // Fallback to legacy individual requests if needed
        try {
          final resSales = await http
              .get(Uri.parse('$baseUrl/sales$qStr'), headers: headers)
              .timeout(const Duration(seconds: 8));
          if (resSales.statusCode == 200) {
            final dynamic raw = jsonDecode(resSales.body);
            final List<dynamic> sData = raw is List ? raw : (raw['items'] as List? ?? []);
            double sum = 0.0;
            for (var s in sData) {
              sum += (s['totalAmount'] as num?)?.toDouble() ?? 0.0;
            }
            if (mounted) {
              setState(() {
                _totalRevenue = sum;
                _totalSalesCount = sData.length;
              });
            }
          }
        } catch (_) {}
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMetrics = false);
      }
    }
  }

  void _onDaysChanged(int days) {
    if (_selectedDays != days) {
      setState(() => _selectedDays = days);
      _loadDashboardMetrics();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<TenantThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final syncProvider = Provider.of<SyncProvider>(context);
    final isHindi = localeProvider.isHindi;

    return Scaffold(
      backgroundColor: themeProvider.pageBgColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: themeProvider.primaryColor,
        elevation: 0,
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
          IconButton(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.upload_file_rounded, color: Colors.white, size: 20),
            tooltip: isHindi ? 'एक्सेल अपलोडर' : 'Excel Uploader',
            onPressed: () => Navigator.pushNamed(context, '/uploader'),
          ),
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
            icon: _isLoadingMetrics
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
            tooltip: 'Refresh Analytics',
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
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Compact Analytics Toolbar
                  _buildCompactToolbar(context, isHindi, themeProvider),
                  const SizedBox(height: 12),

                  // 2. Pure Graph-Only Analytics Grid
                  _buildGraphGrid(context, isHindi, themeProvider),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: themeProvider.buttonBgColor,
        elevation: 3,
        icon: Icon(Icons.add_shopping_cart_rounded, color: themeProvider.buttonTextColor),
        label: Text(
          isHindi ? '+ नया बिल' : '+ New Bill',
          style: TextStyle(
            fontFamily: themeProvider.fontFamily,
            fontWeight: FontWeight.bold,
            fontSize: 13 * themeProvider.fontSizeScale,
            color: themeProvider.buttonTextColor,
          ),
        ),
        onPressed: () {
          Navigator.pushNamed(context, '/pos');
        },
      ),
    );
  }

  // --- 1. Compact Analytics Toolbar (No redundant cards or giant headers) ---
  Widget _buildCompactToolbar(BuildContext context, bool isHindi, TenantThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: themeProvider.cardBgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          // Live Analytics workspace status
          Row(
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
                isHindi ? 'लाइव एनालिटिक्स' : 'Analytics Workspace',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12 * themeProvider.fontSizeScale,
                  color: themeProvider.textColor,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  '₹ ${_totalRevenue.toStringAsFixed(0)} • Udhaar: ₹${_totalUdhaar.toStringAsFixed(0)} • $_totalSalesCount Bills',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              ),
            ],
          ),

          // Date Filter Choice Chips
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFilterChoiceChip('7 Days', 7, isHindi ? '7 दिन' : '7 Days', themeProvider),
              const SizedBox(width: 6),
              _buildFilterChoiceChip('30 Days', 30, isHindi ? '30 दिन' : '30 Days', themeProvider),
              const SizedBox(width: 6),
              _buildFilterChoiceChip('All Time', 0, isHindi ? 'कुल समय' : 'All Time', themeProvider),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChoiceChip(String label, int daysVal, String displayLabel, TenantThemeProvider themeProvider) {
    final isSelected = _selectedDays == daysVal;
    return InkWell(
      onTap: () => _onDaysChanged(daysVal),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? themeProvider.primaryColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? themeProvider.primaryColor : Colors.grey.shade300),
        ),
        child: Text(
          displayLabel,
          style: TextStyle(
            fontSize: 11 * themeProvider.fontSizeScale,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey.shade800,
          ),
        ),
      ),
    );
  }

  // --- 2. Information-Dense Responsive Graph Grid ---
  Widget _buildGraphGrid(BuildContext context, bool isHindi, TenantThemeProvider themeProvider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 768;

        if (isDesktop) {
          return Column(
            children: [
              // Row 1: Daily Revenue Trend (60%) + Payment Mode Split (40%)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: _buildTrendChartCard(isHindi, themeProvider),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 4,
                    child: _buildPaymentSplitCard(isHindi, themeProvider),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Row 2: Top Selling Fast Movers (50%) + Category Inventory Valuation (50%)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: _buildTopSellingCard(isHindi, themeProvider),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 5,
                    child: _buildCategoryValuationCard(isHindi, themeProvider),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Row 3: Settlement Health & Credit Risk (Full Width)
              _buildSettlementCard(isHindi, themeProvider),
            ],
          );
        }

        // Mobile Single Column Stack
        return Column(
          children: [
            _buildTrendChartCard(isHindi, themeProvider),
            const SizedBox(height: 12),
            _buildPaymentSplitCard(isHindi, themeProvider),
            const SizedBox(height: 12),
            _buildTopSellingCard(isHindi, themeProvider),
            const SizedBox(height: 12),
            _buildCategoryValuationCard(isHindi, themeProvider),
            const SizedBox(height: 12),
            _buildSettlementCard(isHindi, themeProvider),
          ],
        );
      },
    );
  }

  // --- Chart 1: Sales Revenue Trend Card (Interactive Area/Line Chart) ---
  Widget _buildTrendChartCard(bool isHindi, TenantThemeProvider themeProvider) {
    final points = _dailyTrend.map((d) {
      final date = d['date']?.toString() ?? '';
      final day = d['day']?.toString() ?? (date.length >= 5 ? date.substring(5) : date);
      final total = ((d['total'] as num?)?.toDouble() ?? 0.0);
      final count = (d['count'] as num?)?.toInt() ?? 0;
      return TrendDataPoint(date: date, day: day, total: total, count: count);
    }).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: themeProvider.cardBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.trending_up_rounded, size: 18, color: themeProvider.primaryColor),
                  const SizedBox(width: 6),
                  Text(
                    isHindi ? 'बिक्री कारोबार एवं इनवॉइस ट्रेंड' : 'Sales Revenue & Invoice Trend',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                child: Text(
                  _selectedDays == 7 ? '7-Day View' : (_selectedDays == 30 ? '30-Day View' : 'All-Time'),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          InteractiveAreaLineChart(
            points: points,
            primaryColor: themeProvider.primaryColor,
            height: 200,
          ),
        ],
      ),
    );
  }

  // --- Chart 2: Payment Collection Split Card (Interactive Donut Chart) ---
  Widget _buildPaymentSplitCard(bool isHindi, TenantThemeProvider themeProvider) {
    final double totalSplit = _cashSales + _upiSales + _udhaarSales;
    final double effectiveTotal = totalSplit > 0 ? totalSplit : (_totalRevenue > 0 ? _totalRevenue : 0.0);

    final slices = [
      if (_cashSales > 0 || (effectiveTotal == 0 && _cashSales == 0 && _upiSales == 0 && _udhaarSales == 0))
        DonutSlice(label: 'Cash', value: _cashSales, color: const Color(0xFF10B981)),
      if (_upiSales > 0)
        DonutSlice(label: 'UPI', value: _upiSales, color: const Color(0xFF3B82F6)),
      if (_udhaarSales > 0)
        DonutSlice(label: 'Udhaar', value: _udhaarSales, color: const Color(0xFFEF4444)),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: themeProvider.cardBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.pie_chart_rounded, size: 18, color: Color(0xFF10B981)),
                  const SizedBox(width: 6),
                  Text(
                    isHindi ? 'भुगतान माध्यम विभाजन' : 'Payment Mode Split',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              Text(
                '₹ ${effectiveTotal.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InteractiveDonutChart(
            slices: slices,
            size: 165,
          ),
        ],
      ),
    );
  }

  // --- Chart 3: Top Selling Fast Movers (Interactive Ranked Horizontal Bars) ---
  Widget _buildTopSellingCard(bool isHindi, TenantThemeProvider themeProvider) {
    final rankedItems = _topSellingProducts.map((p) {
      final name = p['name']?.toString() ?? 'Item';
      final qty = (p['quantity'] as num?)?.toInt() ?? 0;
      final revenue = ((p['revenue'] as num?)?.toDouble() ?? 0.0);
      return RankedItemData(name: name, quantity: qty, revenue: revenue);
    }).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: themeProvider.cardBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.leaderboard_rounded, size: 18, color: Colors.amber.shade700),
                  const SizedBox(width: 6),
                  Text(
                    isHindi ? 'टॉप बिकने वाले उत्पाद' : 'Top Selling Products',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(4)),
                child: Text(
                  'Fast Movers',
                  style: TextStyle(fontSize: 10, color: Colors.amber.shade900, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InteractiveRankedBarList(
            items: rankedItems,
            primaryColor: Colors.amber.shade700,
          ),
        ],
      ),
    );
  }

  // --- Chart 4: Category Inventory Stock Valuation (Interactive Vertical Bar Chart) ---
  Widget _buildCategoryValuationCard(bool isHindi, TenantThemeProvider themeProvider) {
    final categoryData = _categorySummary.map((c) {
      final cat = c['category']?.toString() ?? 'General';
      final val = ((c['totalValue'] as num?)?.toDouble() ?? 0.0);
      final count = (c['productCount'] as num?)?.toInt() ?? 0;
      return CategoryBarData(category: cat, value: val, count: count);
    }).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: themeProvider.cardBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.inventory_2_rounded, size: 18, color: Color(0xFF0D9488)),
                  const SizedBox(width: 6),
                  Text(
                    isHindi ? 'श्रेणी अनुसार स्टॉक मूल्यांकन' : 'Category Stock Valuation',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFCCFBF1), borderRadius: BorderRadius.circular(4)),
                child: const Text(
                  '₹ Asset Value',
                  style: TextStyle(fontSize: 10, color: Color(0xFF0F766E), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          InteractiveCategoryBarChart(
            data: categoryData,
            height: 190,
            barColor: const Color(0xFF0D9488),
          ),
        ],
      ),
    );
  }

  // --- Chart 5: Settlement Health & Credit Risk Ratio ---
  Widget _buildSettlementCard(bool isHindi, TenantThemeProvider themeProvider) {
    final double totalCollections = _cashSales + _upiSales;
    final double grand = totalCollections + _udhaarSales;
    final double paidPct = grand > 0 ? (totalCollections / grand) * 100 : 0.0;
    final double creditPct = grand > 0 ? (_udhaarSales / grand) * 100 : 0.0;
    final int paidCount = _settlementBreakdown.isNotEmpty ? (_settlementBreakdown[0]['count'] ?? 0) : 0;
    final int creditCount = _settlementBreakdown.length > 1 ? (_settlementBreakdown[1]['count'] ?? 0) : 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: themeProvider.cardBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.account_balance_wallet_rounded, size: 18, color: const Color(0xFF6366F1)),
                  const SizedBox(width: 6),
                  Text(
                    isHindi ? 'लेनदारी स्वास्थ्य एवं उधारी जोखिम' : 'Settlement Health & Market Dues',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              Text(
                'Recovery: ${paidPct.toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Dual Distribution Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (paidPct > 0)
                    Expanded(
                      flex: paidPct.toInt().clamp(1, 100),
                      child: Container(color: const Color(0xFF10B981)),
                    ),
                  if (creditPct > 0)
                    Expanded(
                      flex: creditPct.toInt().clamp(1, 100),
                      child: Container(color: const Color(0xFFEF4444)),
                    ),
                  if (grand <= 0)
                    Expanded(
                      flex: 100,
                      child: Container(color: Colors.grey.shade200),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isHindi ? 'वसूली वास्तविक नकद/UPI' : 'Settled Cash / Digital',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF047857), fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹ ${totalCollections.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF065F46)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$paidCount Bills Cleared',
                        style: TextStyle(fontSize: 9.5, color: Colors.green.shade800, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isHindi ? 'मार्केट बकाया उधारी' : 'Outstanding Credit Dues',
                        style: const TextStyle(fontSize: 10, color: Color(0xFFB91C1C), fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹ ${_udhaarSales.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF991B1B)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$creditCount Credit Invoices',
                        style: TextStyle(fontSize: 9.5, color: Colors.red.shade800, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
