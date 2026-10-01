import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class AnalyticsChartsWidget extends StatefulWidget {
  final List<Map<String, dynamic>> salesList;
  final bool isHindi;

  const AnalyticsChartsWidget({
    super.key,
    required this.salesList,
    required this.isHindi,
  });

  @override
  State<AnalyticsChartsWidget> createState() => _AnalyticsChartsWidgetState();
}

class _AnalyticsChartsWidgetState extends State<AnalyticsChartsWidget> with SingleTickerProviderStateMixin {
  String _selectedFilter = 'This Week';
  late AnimationController _animController;
  late Animation<double> _chartProgress;
  int? _hoveredPointIndex;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _chartProgress = CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
    _animController.forward();
  }

  @override
  void didUpdateWidget(covariant AnalyticsChartsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.salesList != widget.salesList) {
      _animController.reset();
      _animController.forward();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onFilterChanged(String filter) {
    if (_selectedFilter != filter) {
      setState(() {
        _selectedFilter = filter;
        _hoveredPointIndex = null;
      });
      _animController.reset();
      _animController.forward();
    }
  }

  List<Map<String, dynamic>> _getFilteredSales() {
    final now = DateTime.now();
    return widget.salesList.where((s) {
      final dateStr = s['createdAt']?.toString() ?? '';
      if (dateStr.isEmpty) return true;

      final parsed = DateTime.tryParse(dateStr);
      if (parsed == null) return true;

      if (_selectedFilter == 'Today') {
        return parsed.year == now.year && parsed.month == now.month && parsed.day == now.day;
      } else if (_selectedFilter == 'This Week') {
        final weekAgo = now.subtract(const Duration(days: 7));
        return parsed.isAfter(weekAgo);
      } else if (_selectedFilter == 'This Month') {
        return parsed.year == now.year && parsed.month == now.month;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<TenantThemeProvider>(context);
    final filteredSales = _getFilteredSales();

    final List<_ChartPoint> trendData = _computeTrendData(filteredSales);
    final Map<String, double> modeData = _computeModeData(filteredSales);
    final List<MapEntry<String, double>> topProducts = _computeTopProducts(filteredSales);

    final isDesktop = MediaQuery.of(context).size.width > 768;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: themeProvider.primaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.analytics_rounded, color: themeProvider.primaryColor, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.isHindi ? 'बिक्री ग्राफ' : 'Sales Analytics',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: themeProvider.fontFamily,
                        fontSize: 16 * themeProvider.fontSizeScale,
                        fontWeight: FontWeight.bold,
                        color: themeProvider.textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isDesktop)
              Wrap(
                spacing: 6,
                children: ['Today', 'This Week', 'This Month', 'All Time'].map((f) {
                  final isSelected = _selectedFilter == f;
                  return ChoiceChip(
                    label: Text(
                      _getFilterLabel(f, widget.isHindi),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : Colors.grey.shade800,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: themeProvider.primaryColor,
                    backgroundColor: Colors.grey.shade100,
                    elevation: isSelected ? 2 : 0,
                    onSelected: (_) => _onFilterChanged(f),
                  );
                }).toList(),
              )
            else
              Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: themeProvider.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: themeProvider.primaryColor.withOpacity(0.25)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedFilter,
                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: themeProvider.primaryColor, size: 18),
                    isDense: true,
                    style: TextStyle(
                      fontFamily: themeProvider.fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: themeProvider.primaryColor,
                    ),
                    items: ['Today', 'This Week', 'This Month', 'All Time'].map((f) {
                      return DropdownMenuItem<String>(
                        value: f,
                        child: Text(_getFilterLabel(f, widget.isHindi)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) _onFilterChanged(val);
                    },
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),

        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: _buildLineChartCard(themeProvider, trendData),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    _buildDonutChartCard(themeProvider, modeData),
                    const SizedBox(height: 14),
                    _buildTopProductsCard(themeProvider, topProducts),
                  ],
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              _buildLineChartCard(themeProvider, trendData),
              const SizedBox(height: 14),
              _buildDonutChartCard(themeProvider, modeData),
              const SizedBox(height: 14),
              _buildTopProductsCard(themeProvider, topProducts),
            ],
          ),
      ],
    );
  }

  String _getFilterLabel(String key, bool isHindi) {
    if (!isHindi) return key;
    switch (key) {
      case 'Today': return 'आज';
      case 'This Week': return 'इस हफ्ते';
      case 'This Month': return 'इस महीने';
      default: return 'कुल सभी';
    }
  }

  Widget _buildLineChartCard(TenantThemeProvider themeProvider, List<_ChartPoint> points) {
    final double maxVal = points.isEmpty ? 1000.0 : points.map((e) => e.value).reduce(max);
    final double displayMax = maxVal == 0 ? 1000.0 : maxVal * 1.15;
    final double totalRevenue = points.fold(0.0, (s, p) => s + p.value);

    return AnimatedBuilder(
      animation: _chartProgress,
      builder: (ctx, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isHindi ? 'बिक्री रेवेन्यू ट्रेंड' : 'Revenue Growth Trend',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        'Total: ₹ ${totalRevenue.toStringAsFixed(2)}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: themeProvider.primaryColor),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.trending_up_rounded, size: 16, color: Colors.green),
                        SizedBox(width: 4),
                        Text('Sales', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 220,
                width: double.infinity,
                child: points.isEmpty
                    ? Center(child: Text(widget.isHindi ? 'कोई डेटा नहीं मिला' : 'No Trend Data Available', style: const TextStyle(color: Colors.grey)))
                    : GestureDetector(
                        onPanUpdate: (details) => _handleHover(details.localPosition, points),
                        child: CustomPaint(
                          painter: _LineChartPainter(
                            points: points,
                            progress: _chartProgress.value,
                            primaryColor: themeProvider.primaryColor,
                            secondaryColor: themeProvider.secondaryColor,
                            maxValue: displayMax,
                            hoveredIndex: _hoveredPointIndex,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleHover(Offset pos, List<_ChartPoint> points) {
    if (points.isEmpty) return;
    final double stepX = 300.0 / (points.length > 1 ? points.length - 1 : 1);
    final int index = (pos.dx / stepX).round().clamp(0, points.length - 1);
    if (_hoveredPointIndex != index) {
      setState(() {
        _hoveredPointIndex = index;
      });
    }
  }

  Widget _buildDonutChartCard(TenantThemeProvider themeProvider, Map<String, double> modeData) {
    final double total = modeData.values.fold(0.0, (s, v) => s + v);

    return AnimatedBuilder(
      animation: _chartProgress,
      builder: (ctx, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isHindi ? 'भुगतान मोड़ ब्रेकडाउन' : 'Payment Methods Breakdown',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    width: 110,
                    height: 110,
                    child: CustomPaint(
                      painter: _DonutChartPainter(
                        data: modeData,
                        progress: _chartProgress.value,
                        total: total,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '₹${(total / 1000).toStringAsFixed(1)}k',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const Text('Total', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        _buildLegendItem('Cash (नगद)', modeData['Cash'] ?? 0, total, Colors.green),
                        const SizedBox(height: 6),
                        _buildLegendItem('UPI / Online', modeData['UPI'] ?? 0, total, Colors.blue),
                        const SizedBox(height: 6),
                        _buildLegendItem('Udhaar (उधार)', modeData['Udhaar'] ?? 0, total, Colors.red),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegendItem(String label, double val, double total, Color color) {
    final pct = total > 0 ? (val / total * 100).toStringAsFixed(0) : '0';
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500))),
        Text('$pct% (₹${val.toStringAsFixed(0)})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTopProductsCard(TenantThemeProvider themeProvider, List<MapEntry<String, double>> topProducts) {
    final maxVal = topProducts.isEmpty ? 1.0 : topProducts.map((e) => e.value).reduce(max);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isHindi ? 'टॉप बिकने वाले सामान' : 'Top Selling Items',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 10),
          if (topProducts.isEmpty)
            Text(widget.isHindi ? 'कोई डेटा नहीं' : 'No items sold yet', style: const TextStyle(color: Colors.grey, fontSize: 12))
          else
            ...topProducts.take(4).map((entry) {
              final pct = maxVal > 0 ? (entry.value / maxVal) : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                        Text('₹ ${entry.value.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: themeProvider.primaryColor)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct * _chartProgress.value,
                        backgroundColor: Colors.grey.shade100,
                        color: themeProvider.primaryColor,
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  List<_ChartPoint> _computeTrendData(List<Map<String, dynamic>> sales) {
    final Map<String, double> bucketMap = {};

    if (_selectedFilter == 'Today') {
      for (int h = 8; h <= 20; h += 3) {
        final label = '${h > 12 ? h - 12 : h} ${h >= 12 ? 'PM' : 'AM'}';
        bucketMap[label] = 0.0;
      }
      for (var s in sales) {
        final amt = (s['totalAmount'] as num?)?.toDouble() ?? 0.0;
        final dateStr = s['createdAt']?.toString() ?? '';
        final parsed = DateTime.tryParse(dateStr) ?? DateTime.now();
        final h = parsed.hour;
        final bucketHour = (h / 3).round() * 3;
        final label = '${bucketHour > 12 ? bucketHour - 12 : bucketHour} ${bucketHour >= 12 ? 'PM' : 'AM'}';
        bucketMap[label] = (bucketMap[label] ?? 0.0) + amt;
      }
    } else {
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      for (var d in days) {
        bucketMap[d] = 0.0;
      }
      for (var s in sales) {
        final amt = (s['totalAmount'] as num?)?.toDouble() ?? 0.0;
        final dateStr = s['createdAt']?.toString() ?? '';
        final parsed = DateTime.tryParse(dateStr) ?? DateTime.now();
        final dayName = days[(parsed.weekday - 1) % 7];
        bucketMap[dayName] = (bucketMap[dayName] ?? 0.0) + amt;
      }
    }

    return bucketMap.entries.map((e) => _ChartPoint(e.key, e.value)).toList();
  }

  Map<String, double> _computeModeData(List<Map<String, dynamic>> sales) {
    final Map<String, double> modes = {'Cash': 0.0, 'UPI': 0.0, 'Udhaar': 0.0};
    for (var s in sales) {
      final amt = (s['totalAmount'] as num?)?.toDouble() ?? 0.0;
      final mode = s['paymentMode']?.toString() ?? 'Cash';
      if (modes.containsKey(mode)) {
        modes[mode] = modes[mode]! + amt;
      } else {
        modes['Cash'] = modes['Cash']! + amt;
      }
    }
    return modes;
  }

  List<MapEntry<String, double>> _computeTopProducts(List<Map<String, dynamic>> sales) {
    final Map<String, double> prodRevenue = {};
    for (var s in sales) {
      final items = s['items'] as List<dynamic>? ?? [];
      for (var it in items) {
        if (it is Map) {
          final pName = it['productName']?.toString() ?? it['name']?.toString() ?? 'General Item';
          final num price = it['unitPrice'] ?? it['price'] ?? 0;
          final num qty = it['quantity'] ?? it['qty'] ?? 1;
          final double tot = (it['totalAmount'] ?? (price * qty)) as double;
          prodRevenue[pName] = (prodRevenue[pName] ?? 0.0) + tot;
        }
      }
    }
    final sorted = prodRevenue.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted;
  }
}

class _ChartPoint {
  final String label;
  final double value;
  _ChartPoint(this.label, this.value);
}

class _LineChartPainter extends CustomPainter {
  final List<_ChartPoint> points;
  final double progress;
  final Color primaryColor;
  final Color secondaryColor;
  final double maxValue;
  final int? hoveredIndex;

  _LineChartPainter({
    required this.points,
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
    required this.maxValue,
    this.hoveredIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final double bottomMargin = 24.0;
    final double chartHeight = size.height - bottomMargin;
    final double stepX = points.length > 1 ? size.width / (points.length - 1) : size.width;

    final Paint gridPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1.0;

    for (int i = 0; i <= 3; i++) {
      final double y = chartHeight * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final List<Offset> offsets = [];
    for (int i = 0; i < points.length; i++) {
      final double x = i * stepX;
      final double normY = (points[i].value / maxValue).clamp(0.0, 1.0);
      final double y = chartHeight - (normY * chartHeight * progress);
      offsets.add(Offset(x, y));
    }

    final Path path = Path();
    path.moveTo(offsets[0].dx, offsets[0].dy);

    for (int i = 0; i < offsets.length - 1; i++) {
      final p1 = offsets[i];
      final p2 = offsets[i + 1];
      final controlP1 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p1.dy);
      final controlP2 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p2.dy);
      path.cubicTo(controlP1.dx, controlP1.dy, controlP2.dx, controlP2.dy, p2.dx, p2.dy);
    }

    final Path fillPath = Path.from(path);
    fillPath.lineTo(offsets.last.dx, chartHeight);
    fillPath.lineTo(offsets.first.dx, chartHeight);
    fillPath.close();

    final Paint fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [primaryColor.withOpacity(0.35), primaryColor.withOpacity(0.0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, chartHeight));

    canvas.drawPath(fillPath, fillPaint);

    final Paint linePaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);

    final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < offsets.length; i++) {
      final pt = offsets[i];

      final isHovered = hoveredIndex == i;
      final Paint dotPaint = Paint()
        ..color = isHovered ? secondaryColor : primaryColor
        ..style = PaintingStyle.fill;

      canvas.drawCircle(pt, isHovered ? 6.5 : 4.0, dotPaint);
      canvas.drawCircle(pt, isHovered ? 3.0 : 2.0, Paint()..color = Colors.white);

      textPainter.text = TextSpan(
        text: points[i].label,
        style: TextStyle(
          color: isHovered ? primaryColor : Colors.grey.shade600,
          fontSize: 10,
          fontWeight: isHovered ? FontWeight.bold : FontWeight.normal,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(pt.dx - (textPainter.width / 2), size.height - 18));
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) => true;
}

class _DonutChartPainter extends CustomPainter {
  final Map<String, double> data;
  final double progress;
  final double total;

  _DonutChartPainter({
    required this.data,
    required this.progress,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final strokeWidth = 16.0;

    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);
    double startAngle = -pi / 2;

    final colors = {
      'Cash': Colors.green,
      'UPI': Colors.blue,
      'Udhaar': Colors.red,
    };

    if (total == 0) {
      final Paint emptyPaint = Paint()
        ..color = Colors.grey.shade200
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawArc(rect, 0, 2 * pi, false, emptyPaint);
      return;
    }

    data.forEach((key, val) {
      final sweepAngle = (val / total) * 2 * pi * progress;
      final Paint paint = Paint()
        ..color = colors[key] ?? Colors.grey
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    });
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) => true;
}
