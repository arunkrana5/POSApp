import 'dart:math';
import 'package:flutter/material.dart';

// --- Color Palette for Analytics ---
class PosChartColors {
  static const Color primary = Color(0xFF2563EB); // Royal Blue
  static const Color success = Color(0xFF10B981); // Emerald Green
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color danger = Color(0xFFEF4444);  // Rose Red
  static const Color purple = Color(0xFF8B5CF6);  // Violet
  static const Color teal = Color(0xFF0D9488);    // Teal
  static const Color cardBg = Colors.white;
  static const Color textMain = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
}

// ============================================================================
// 1. INTERACTIVE AREA / LINE CHART (Daily Revenue & Invoice Velocity)
// ============================================================================
class TrendDataPoint {
  final String date;
  final String day;
  final double total;
  final int count;

  TrendDataPoint({
    required this.date,
    required this.day,
    required this.total,
    required this.count,
  });
}

class InteractiveAreaLineChart extends StatefulWidget {
  final List<TrendDataPoint> points;
  final Color primaryColor;
  final double height;

  const InteractiveAreaLineChart({
    super.key,
    required this.points,
    this.primaryColor = PosChartColors.primary,
    this.height = 200,
  });

  @override
  State<InteractiveAreaLineChart> createState() => _InteractiveAreaLineChartState();
}

class _InteractiveAreaLineChartState extends State<InteractiveAreaLineChart> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _animProgress;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _animProgress = CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
    _animController.forward();
  }

  @override
  void didUpdateWidget(covariant InteractiveAreaLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points) {
      _animController.reset();
      _animController.forward();
      _selectedIndex = null;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleTouch(Offset localPos, double width) {
    if (widget.points.isEmpty) return;
    const paddingLeft = 45.0;
    const paddingRight = 20.0;
    final plotWidth = width - paddingLeft - paddingRight;
    if (plotWidth <= 0) return;

    final touchX = (localPos.dx - paddingLeft).clamp(0.0, plotWidth);
    final stepX = plotWidth / max(widget.points.length - 1, 1);
    final idx = (touchX / stepX).round().clamp(0, widget.points.length - 1);

    if (_selectedIndex != idx) {
      setState(() => _selectedIndex = idx);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: Text('No revenue activity in this period', style: TextStyle(color: PosChartColors.textMuted, fontSize: 12)),
        ),
      );
    }

    final double maxVal = widget.points.map((p) => p.total).reduce(max);
    final double effectiveMax = maxVal > 0 ? maxVal * 1.15 : 100.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return Column(
          children: [
            // Floating Touch Tooltip Banner
            SizedBox(
              height: 28,
              child: _selectedIndex != null && _selectedIndex! < widget.points.length
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${widget.points[_selectedIndex!].date} (${widget.points[_selectedIndex!].day})',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: PosChartColors.textMuted),
                        ),
                        Row(
                          children: [
                            Text(
                              '₹ ${widget.points[_selectedIndex!].total.toStringAsFixed(2)}',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: widget.primaryColor),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                              child: Text(
                                '${widget.points[_selectedIndex!].count} bills',
                                style: TextStyle(fontSize: 10, color: Colors.blue.shade800, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Touch points to inspect revenue', style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)),
                        Text('Max: ₹${maxVal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                      ],
                    ),
            ),
            const SizedBox(height: 6),

            // Canvas Chart Area
            SizedBox(
              height: widget.height - 34,
              width: width,
              child: GestureDetector(
                onPanDown: (d) => _handleTouch(d.localPosition, width),
                onPanUpdate: (d) => _handleTouch(d.localPosition, width),
                onTapUp: (d) => _handleTouch(d.localPosition, width),
                child: AnimatedBuilder(
                  animation: _animProgress,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _AreaLineChartPainter(
                        points: widget.points,
                        progress: _animProgress.value,
                        primaryColor: widget.primaryColor,
                        maxValue: effectiveMax,
                        selectedIndex: _selectedIndex,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AreaLineChartPainter extends CustomPainter {
  final List<TrendDataPoint> points;
  final double progress;
  final Color primaryColor;
  final double maxValue;
  final int? selectedIndex;

  _AreaLineChartPainter({
    required this.points,
    required this.progress,
    required this.primaryColor,
    required this.maxValue,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const paddingLeft = 45.0;
    const paddingRight = 20.0;
    const paddingTop = 12.0;
    const paddingBottom = 24.0;

    final plotWidth = size.width - paddingLeft - paddingRight;
    final plotHeight = size.height - paddingTop - paddingBottom;
    if (plotWidth <= 0 || plotHeight <= 0) return;

    // Grid lines and Y-axis text
    final gridPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 1.0;

    const textStyle = TextStyle(fontSize: 9, color: PosChartColors.textMuted, fontWeight: FontWeight.w600);

    for (int i = 0; i <= 3; i++) {
      final y = paddingTop + plotHeight * (i / 3);
      canvas.drawLine(Offset(paddingLeft, y), Offset(size.width - paddingRight, y), gridPaint);

      final val = maxValue * (1.0 - i / 3);
      final label = val >= 1000 ? '₹${(val / 1000).toStringAsFixed(1)}k' : '₹${val.toStringAsFixed(0)}';
      final textSpan = TextSpan(text: label, style: textStyle);
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      textPainter.paint(canvas, Offset(paddingLeft - textPainter.width - 6, y - textPainter.height / 2));
    }

    final stepX = plotWidth / max(points.length - 1, 1);
    final offsets = <Offset>[];

    for (int i = 0; i < points.length; i++) {
      final x = paddingLeft + i * stepX;
      final normY = (points[i].total / maxValue).clamp(0.0, 1.0);
      final y = paddingTop + plotHeight - (normY * plotHeight * progress);
      offsets.add(Offset(x, y));
    }

    // Bezier Curve Path
    final path = Path()..moveTo(offsets[0].dx, offsets[0].dy);
    for (int i = 0; i < offsets.length - 1; i++) {
      final p1 = offsets[i];
      final p2 = offsets[i + 1];
      final cx = p1.dx + (p2.dx - p1.dx) / 2;
      path.cubicTo(cx, p1.dy, cx, p2.dy, p2.dx, p2.dy);
    }

    // Area Fill Path
    final fillPath = Path.from(path)
      ..lineTo(offsets.last.dx, paddingTop + plotHeight)
      ..lineTo(offsets.first.dx, paddingTop + plotHeight)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [primaryColor.withOpacity(0.32), primaryColor.withOpacity(0.01)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(paddingLeft, paddingTop, plotWidth, plotHeight));

    canvas.drawPath(fillPath, fillPaint);

    // Stroke Path
    final strokePaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, strokePaint);

    // X-axis day labels & tick lines
    for (int i = 0; i < points.length; i++) {
      final p = offsets[i];
      final isSel = selectedIndex == i;
      final day = points[i].day;

      final daySpan = TextSpan(
        text: day,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
          color: isSel ? primaryColor : PosChartColors.textMuted,
        ),
      );
      final dayPainter = TextPainter(text: daySpan, textDirection: TextDirection.ltr)..layout();
      dayPainter.paint(canvas, Offset(p.dx - dayPainter.width / 2, paddingTop + plotHeight + 6));
    }

    // Draw active cursor and anchor points
    for (int i = 0; i < offsets.length; i++) {
      final p = offsets[i];
      final isSel = selectedIndex == i;

      if (isSel) {
        // Vertical dashed guideline
        final guidePaint = Paint()
          ..color = primaryColor.withOpacity(0.4)
          ..strokeWidth = 1.2;
        canvas.drawLine(Offset(p.dx, paddingTop), Offset(p.dx, paddingTop + plotHeight), guidePaint);

        // Highlight ring
        canvas.drawCircle(p, 7, Paint()..color = primaryColor.withOpacity(0.2));
      }

      // Outer dot
      canvas.drawCircle(p, isSel ? 5.0 : 3.5, Paint()..color = Colors.white);
      // Inner circle
      canvas.drawCircle(
        p,
        isSel ? 3.5 : 2.2,
        Paint()..color = isSel ? primaryColor : primaryColor.withOpacity(0.8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AreaLineChartPainter old) =>
      old.progress != progress || old.selectedIndex != selectedIndex || old.points != points;
}

// ============================================================================
// 2. INTERACTIVE DONUT / PIE CHART (Payment Mode Breakdown)
// ============================================================================
class DonutSlice {
  final String label;
  final double value;
  final Color color;

  DonutSlice({required this.label, required this.value, required this.color});
}

class InteractiveDonutChart extends StatefulWidget {
  final List<DonutSlice> slices;
  final double size;

  const InteractiveDonutChart({
    super.key,
    required this.slices,
    this.size = 180,
  });

  @override
  State<InteractiveDonutChart> createState() => _InteractiveDonutChartState();
}

class _InteractiveDonutChartState extends State<InteractiveDonutChart> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _animProgress;
  int? _hoveredSliceIndex;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _animProgress = CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
    _animController.forward();
  }

  @override
  void didUpdateWidget(covariant InteractiveDonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slices != widget.slices) {
      _animController.reset();
      _animController.forward();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleTouch(Offset localPos) {
    final double total = widget.slices.fold(0.0, (sum, s) => sum + s.value);
    if (total <= 0) return;

    final center = Offset(widget.size / 2, widget.size / 2);
    final dx = localPos.dx - center.dx;
    final dy = localPos.dy - center.dy;
    final dist = sqrt(dx * dx + dy * dy);

    // Only respond if touch is roughly on donut ring
    if (dist < 25 || dist > widget.size / 2 + 10) {
      setState(() => _hoveredSliceIndex = null);
      return;
    }

    // Calculate angle normalized from top (-pi/2)
    var angle = atan2(dy, dx) + (pi / 2);
    if (angle < 0) angle += 2 * pi;

    var currentAngle = 0.0;
    for (int i = 0; i < widget.slices.length; i++) {
      final sweep = 2 * pi * (widget.slices[i].value / total);
      if (angle >= currentAngle && angle <= currentAngle + sweep) {
        if (_hoveredSliceIndex != i) {
          setState(() => _hoveredSliceIndex = i);
        }
        return;
      }
      currentAngle += sweep;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double total = widget.slices.fold(0.0, (sum, s) => sum + s.value);

    if (total <= 0) {
      return SizedBox(
        height: widget.size,
        child: const Center(
          child: Text('No transaction volume recorded', style: TextStyle(color: PosChartColors.textMuted, fontSize: 12)),
        ),
      );
    }

    final activeSlice = _hoveredSliceIndex != null && _hoveredSliceIndex! < widget.slices.length
        ? widget.slices[_hoveredSliceIndex!]
        : null;

    final activePct = activeSlice != null && total > 0 ? (activeSlice.value / total * 100).toStringAsFixed(1) : '';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Donut with Center Callout
        GestureDetector(
          onTapDown: (d) => _handleTouch(d.localPosition),
          onPanUpdate: (d) => _handleTouch(d.localPosition),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _animProgress,
                  builder: (context, _) {
                    return CustomPaint(
                      size: Size(widget.size, widget.size),
                      painter: _DonutChartPainter(
                        slices: widget.slices,
                        progress: _animProgress.value,
                        total: total,
                        selectedIndex: _hoveredSliceIndex,
                      ),
                    );
                  },
                ),
                // Center text
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      activeSlice != null ? activeSlice.label : 'Total Volume',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: PosChartColors.textMuted),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      activeSlice != null
                          ? '₹${activeSlice.value >= 1000 ? '${(activeSlice.value / 1000).toStringAsFixed(1)}k' : activeSlice.value.toStringAsFixed(0)}'
                          : '₹${total >= 1000 ? '${(total / 1000).toStringAsFixed(1)}k' : total.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: activeSlice != null ? activeSlice.color : PosChartColors.textMain,
                      ),
                    ),
                    if (activeSlice != null)
                      Text(
                        '$activePct%',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: activeSlice.color),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 18),

        // Interactive Legend Column
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: widget.slices.asMap().entries.map((entry) {
              final idx = entry.key;
              final slice = entry.value;
              final isSelected = _hoveredSliceIndex == idx;
              final pct = total > 0 ? (slice.value / total * 100).toStringAsFixed(1) : '0';

              return InkWell(
                onTap: () {
                  setState(() => _hoveredSliceIndex = isSelected ? null : idx);
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? slice.color.withOpacity(0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: slice.color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          slice.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? slice.color : PosChartColors.textMain,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '$pct%',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: slice.color),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<DonutSlice> slices;
  final double progress;
  final double total;
  final int? selectedIndex;

  _DonutChartPainter({
    required this.slices,
    required this.progress,
    required this.total,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 22.0;
    final radius = (min(size.width, size.height) - strokeWidth) / 2 - 4;

    var startAngle = -pi / 2;

    for (int i = 0; i < slices.length; i++) {
      final slice = slices[i];
      final sweepAngle = (2 * pi * (slice.value / total)) * progress;
      final isSel = selectedIndex == i;

      final paint = Paint()
        ..color = slice.color
        ..strokeWidth = isSel ? strokeWidth + 6 : strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter old) =>
      old.progress != progress || old.selectedIndex != selectedIndex || old.slices != slices;
}

// ============================================================================
// 3. INTERACTIVE VERTICAL BAR CHART (Category Valuation Comparison)
// ============================================================================
class CategoryBarData {
  final String category;
  final double value;
  final int count;

  CategoryBarData({required this.category, required this.value, required this.count});
}

class InteractiveCategoryBarChart extends StatefulWidget {
  final List<CategoryBarData> data;
  final double height;
  final Color barColor;

  const InteractiveCategoryBarChart({
    super.key,
    required this.data,
    this.height = 190,
    this.barColor = PosChartColors.teal,
  });

  @override
  State<InteractiveCategoryBarChart> createState() => _InteractiveCategoryBarChartState();
}

class _InteractiveCategoryBarChartState extends State<InteractiveCategoryBarChart> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _animProgress;
  int? _selectedBarIndex;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _animProgress = CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
    _animController.forward();
  }

  @override
  void didUpdateWidget(covariant InteractiveCategoryBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _animController.reset();
      _animController.forward();
      _selectedBarIndex = null;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleTouch(Offset localPos, double width) {
    if (widget.data.isEmpty) return;
    const paddingLeft = 45.0;
    const paddingRight = 15.0;
    final plotWidth = width - paddingLeft - paddingRight;
    if (plotWidth <= 0) return;

    final touchX = (localPos.dx - paddingLeft).clamp(0.0, plotWidth);
    final barStep = plotWidth / widget.data.length;
    final idx = (touchX / barStep).floor().clamp(0, widget.data.length - 1);

    if (_selectedBarIndex != idx) {
      setState(() => _selectedBarIndex = idx);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: Text('No category stock holdings recorded', style: TextStyle(color: PosChartColors.textMuted, fontSize: 12)),
        ),
      );
    }

    final maxVal = widget.data.map((d) => d.value).reduce(max);
    final effectiveMax = maxVal > 0 ? maxVal * 1.15 : 100.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return Column(
          children: [
            // Top Inspection Label
            SizedBox(
              height: 24,
              child: _selectedBarIndex != null && _selectedBarIndex! < widget.data.length
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.data[_selectedBarIndex!].category,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: widget.barColor),
                        ),
                        Text(
                          '₹ ${widget.data[_selectedBarIndex!].value.toStringAsFixed(2)} (${widget.data[_selectedBarIndex!].count} SKUs)',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: PosChartColors.textMain),
                        ),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Tap column to inspect category stock value', style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)),
                        Text('₹ Asset Value', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                      ],
                    ),
            ),
            const SizedBox(height: 4),

            // Bar Canvas
            SizedBox(
              height: widget.height - 28,
              width: width,
              child: GestureDetector(
                onTapDown: (d) => _handleTouch(d.localPosition, width),
                onPanUpdate: (d) => _handleTouch(d.localPosition, width),
                child: AnimatedBuilder(
                  animation: _animProgress,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _VerticalBarPainter(
                        data: widget.data,
                        progress: _animProgress.value,
                        maxValue: effectiveMax,
                        barColor: widget.barColor,
                        selectedIndex: _selectedBarIndex,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _VerticalBarPainter extends CustomPainter {
  final List<CategoryBarData> data;
  final double progress;
  final double maxValue;
  final Color barColor;
  final int? selectedIndex;

  _VerticalBarPainter({
    required this.data,
    required this.progress,
    required this.maxValue,
    required this.barColor,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const paddingLeft = 45.0;
    const paddingRight = 15.0;
    const paddingTop = 12.0;
    const paddingBottom = 22.0;

    final plotWidth = size.width - paddingLeft - paddingRight;
    final plotHeight = size.height - paddingTop - paddingBottom;
    if (plotWidth <= 0 || plotHeight <= 0) return;

    // Grid baseline
    final baselineY = paddingTop + plotHeight;
    canvas.drawLine(Offset(paddingLeft, baselineY), Offset(size.width - paddingRight, baselineY), Paint()..color = const Color(0xFFE2E8F0)..strokeWidth = 1.2);

    final barSlotWidth = plotWidth / data.length;
    final barWidth = min(barSlotWidth * 0.55, 34.0);

    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final isSel = selectedIndex == i;
      final slotCenterX = paddingLeft + (i + 0.5) * barSlotWidth;
      final barLeft = slotCenterX - barWidth / 2;

      final normH = (item.value / maxValue).clamp(0.04, 1.0);
      final barH = normH * plotHeight * progress;
      final barTop = baselineY - barH;

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(barLeft, barTop, barWidth, barH),
        const Radius.circular(5),
      );

      final barPaint = Paint()
        ..color = isSel ? barColor : barColor.withOpacity(0.85);

      canvas.drawRRect(rrect, barPaint);

      // Label below bar
      final catName = item.category.length > 8 ? '${item.category.substring(0, 7)}…' : item.category;
      final textSpan = TextSpan(
        text: catName,
        style: TextStyle(
          fontSize: 9,
          fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
          color: isSel ? PosChartColors.textMain : PosChartColors.textMuted,
        ),
      );
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      textPainter.paint(canvas, Offset(slotCenterX - textPainter.width / 2, baselineY + 5));

      // Value above bar when selected
      if (isSel) {
        final valSpan = TextSpan(
          text: '₹${item.value >= 1000 ? '${(item.value / 1000).toStringAsFixed(1)}k' : item.value.toStringAsFixed(0)}',
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: barColor),
        );
        final valPainter = TextPainter(text: valSpan, textDirection: TextDirection.ltr)..layout();
        valPainter.paint(canvas, Offset(slotCenterX - valPainter.width / 2, barTop - valPainter.height - 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _VerticalBarPainter old) =>
      old.progress != progress || old.selectedIndex != selectedIndex || old.data != data;
}

// ============================================================================
// 4. INTERACTIVE HORIZONTAL RANKED BAR CHART (Top Selling Products)
// ============================================================================
class RankedItemData {
  final String name;
  final int quantity;
  final double revenue;

  RankedItemData({required this.name, required this.quantity, required this.revenue});
}

class InteractiveRankedBarList extends StatefulWidget {
  final List<RankedItemData> items;
  final Color primaryColor;

  const InteractiveRankedBarList({
    super.key,
    required this.items,
    this.primaryColor = PosChartColors.warning,
  });

  @override
  State<InteractiveRankedBarList> createState() => _InteractiveRankedBarListState();
}

class _InteractiveRankedBarListState extends State<InteractiveRankedBarList> {
  int? _selectedIdx;

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox(
        height: 140,
        child: Center(
          child: Text('No product sales recorded yet', style: TextStyle(color: PosChartColors.textMuted, fontSize: 12)),
        ),
      );
    }

    final double maxRevenue = widget.items.map((i) => i.revenue).reduce(max);
    final effectiveMax = maxRevenue > 0 ? maxRevenue : 1.0;
    final rankBadgeColors = [const Color(0xFFF59E0B), const Color(0xFF94A3B8), const Color(0xFFD97706), const Color(0xFF2563EB), const Color(0xFF64748B)];

    return Column(
      children: widget.items.take(5).toList().asMap().entries.map((entry) {
        final idx = entry.key;
        final item = entry.value;
        final isSel = _selectedIdx == idx;
        final ratio = (item.revenue / effectiveMax).clamp(0.06, 1.0);

        return InkWell(
          onTap: () {
            setState(() => _selectedIdx = isSel ? null : idx);
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: isSel ? PosChartColors.border.withOpacity(0.5) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: rankBadgeColors[idx % rankBadgeColors.length],
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '#${idx + 1}',
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                          color: PosChartColors.textMain,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${item.quantity} sold',
                      style: const TextStyle(fontSize: 10, color: PosChartColors.textMuted, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '₹ ${item.revenue.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: PosChartColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Animated bar indicator
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 6,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: ratio),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      builder: (context, val, _) {
                        return LinearProgressIndicator(
                          value: val,
                          backgroundColor: const Color(0xFFF1F5F9),
                          color: idx == 0 ? PosChartColors.warning : PosChartColors.primary,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
