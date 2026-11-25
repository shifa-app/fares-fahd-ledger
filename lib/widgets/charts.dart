import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../app_info.dart';
import '../logic/balance.dart';

/// Dashboard charts drawn with CustomPainter (no extra dependency).
/// All values come from real ledger entries; with no data the charts
/// are replaced by an empty-state message by the caller.

const Color _inflowColor = BrandColors.success;
const Color _outflowColor = BrandColors.danger;

String _shortMoney(double value) {
  if (value >= 1000000) {
    final v = value / 1000000;
    return '${v == v.truncateToDouble() ? v.truncate() : v.toStringAsFixed(1)}م';
  }
  if (value >= 1000) {
    final v = value / 1000;
    return '${v == v.truncateToDouble() ? v.truncate() : v.toStringAsFixed(1)}أ';
  }
  return value.truncate().toString();
}

void _drawLabel(
  Canvas canvas,
  String text,
  Offset offset,
  TextStyle style,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.rtl,
  )..layout();
  painter.paint(canvas, offset);
}

/// Smooth curve through [points] (Catmull-Rom converted to Bezier).
/// When [minY]/[maxY] are given, every y coordinate — anchor points
/// and Bezier control points — is clamped into that band. The control
/// points are what overshoot: with inflow [0,0,0,0,0,0,220] the curve
/// dipped ~22dp below the zero line, so clamping the anchors alone
/// would not fix it (1.0.7).
Path _smoothPath(List<Offset> points, {double? minY, double? maxY}) {
  final path = Path();
  if (points.isEmpty) return path;
  double clampY(double y) =>
      minY == null || maxY == null ? y : y.clamp(minY, maxY);
  path.moveTo(points.first.dx, clampY(points.first.dy));
  for (var i = 0; i < points.length - 1; i++) {
    final p0 = i == 0 ? points[i] : points[i - 1];
    final p1 = points[i];
    final p2 = points[i + 1];
    final p3 = i + 2 < points.length ? points[i + 2] : p2;
    final c1 = Offset(
      p1.dx + (p2.dx - p0.dx) / 6,
      clampY(p1.dy + (p2.dy - p0.dy) / 6),
    );
    final c2 = Offset(
      p2.dx - (p3.dx - p1.dx) / 6,
      clampY(p2.dy - (p3.dy - p1.dy) / 6),
    );
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, clampY(p2.dy));
  }
  return path;
}

/// Line chart: daily inflow (green) and outflow (red) over the last days.
/// Smooth curves, gradient area under the inflow line, and tapping a
/// point shows that day's exact values above the chart.
class LineFlowChart extends StatefulWidget {
  const LineFlowChart({super.key, required this.days});

  final List<DayFlow> days;

  @override
  State<LineFlowChart> createState() => _LineFlowChartState();
}

class _LineFlowChartState extends State<LineFlowChart> {
  int? _selected;

  int _indexFromX(double dx, double width) {
    const leftPad = 44.0;
    final chartWidth = width - leftPad - 8;
    final n = widget.days.length;
    if (n <= 1 || chartWidth <= 0) return 0;
    final raw = (dx - leftPad) / chartWidth * (n - 1);
    return raw.round().clamp(0, n - 1);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected != null &&
            _selected! >= 0 &&
            _selected! < widget.days.length
        ? widget.days[_selected!]
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (selected != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: BrandColors.navy,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${formatDayDate(selected.date)} — '
              'وارد ${formatMoney(selected.inflow)} • '
              'صادر ${formatMoney(selected.outflow)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        GestureDetector(
          onTapDown: (details) {
            final box = context.findRenderObject() as RenderBox?;
            if (box == null) return;
            final local = box.globalToLocal(details.globalPosition);
            setState(() => _selected = _indexFromX(local.dx, box.size.width));
          },
          // ClipRect keeps the smooth curve (which can overshoot the
          // zero line) inside its 170px box (1.0.7).
          child: ClipRect(
            child: SizedBox(
              height: 170,
              width: double.infinity,
              child: CustomPaint(
                painter: _LineFlowPainter(widget.days, _selected),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LineFlowPainter extends CustomPainter {
  _LineFlowPainter(this.days, this.selectedIndex);

  final List<DayFlow> days;
  final int? selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 44.0;
    const bottomPad = 24.0;
    const topPad = 12.0;
    final chartWidth = size.width - leftPad - 8;
    final chartHeight = size.height - topPad - bottomPad;
    final maxValue = days.fold<double>(
      1,
      (m, d) => math.max(m, math.max(d.inflow, d.outflow)),
    );
    final labelStyle = const TextStyle(fontSize: 11, color: Colors.grey);

    // Grid lines + y labels.
    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = topPad + chartHeight * i / 3;
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(size.width - 8, y),
        gridPaint,
      );
      final value = maxValue * (3 - i) / 3;
      _drawLabel(
        canvas,
        _shortMoney(value),
        Offset(0, y - 7),
        labelStyle,
      );
    }

    Offset point(int index, double value) {
      final x = days.length == 1
          ? leftPad + chartWidth / 2
          : leftPad + chartWidth * index / (days.length - 1);
      // Clamp into the chart band (1.0.7).
      final y = (topPad + chartHeight * (1 - value / maxValue))
          .clamp(topPad, topPad + chartHeight);
      return Offset(x, y);
    }

    final inflowPoints =
        List.generate(days.length, (i) => point(i, days[i].inflow));
    final outflowPoints =
        List.generate(days.length, (i) => point(i, days[i].outflow));

    // Gradient area under the smooth inflow line.
    if (inflowPoints.length > 1) {
      final fill = _smoothPath(
        inflowPoints,
        minY: topPad,
        maxY: topPad + chartHeight,
      );
      fill.lineTo(inflowPoints.last.dx, topPad + chartHeight);
      fill.lineTo(inflowPoints.first.dx, topPad + chartHeight);
      fill.close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, topPad),
            Offset(0, topPad + chartHeight),
            [
              _inflowColor.withValues(alpha: 0.22),
              _inflowColor.withValues(alpha: 0.0),
            ],
          ),
      );
    }

    void drawLine(List<Offset> pts, Color color) {
      if (pts.isEmpty) return;
      canvas.drawPath(
        _smoothPath(pts, minY: topPad, maxY: topPad + chartHeight),
        Paint()
          ..color = color
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
      for (final p in pts) {
        canvas.drawCircle(p, 4, Paint()..color = Colors.white);
        canvas.drawCircle(
          p,
          4,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }

    drawLine(inflowPoints, _inflowColor);
    drawLine(outflowPoints, _outflowColor);

    // Selected day: vertical guide + highlighted dots.
    if (selectedIndex != null &&
        selectedIndex! >= 0 &&
        selectedIndex! < days.length) {
      final i = selectedIndex!;
      final x = inflowPoints[i].dx;
      canvas.drawLine(
        Offset(x, topPad),
        Offset(x, topPad + chartHeight),
        Paint()
          ..color = BrandColors.gold
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(inflowPoints[i], 6, Paint()..color = _inflowColor);
      canvas.drawCircle(outflowPoints[i], 6, Paint()..color = _outflowColor);
    }

    // Day-of-month labels.
    for (var i = 0; i < days.length; i++) {
      final p = point(i, 0);
      _drawLabel(
        canvas,
        '${days[i].date.day}',
        Offset(p.dx - 6, size.height - 18),
        labelStyle,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LineFlowPainter old) =>
      old.days != days || old.selectedIndex != selectedIndex;
}

/// Grouped bar chart: inflow (green) vs outflow (red) per day.
class BarFlowChart extends StatelessWidget {
  const BarFlowChart({super.key, required this.days});

  final List<DayFlow> days;

  @override
  Widget build(BuildContext context) {
    // ClipRect keeps the bars inside their 170px box (1.0.7).
    return ClipRect(
      child: SizedBox(
        height: 170,
        width: double.infinity,
        child: CustomPaint(painter: _BarFlowPainter(days)),
      ),
    );
  }
}

class _BarFlowPainter extends CustomPainter {
  _BarFlowPainter(this.days);

  final List<DayFlow> days;

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 44.0;
    const bottomPad = 24.0;
    const topPad = 12.0;
    final chartWidth = size.width - leftPad - 8;
    final chartHeight = size.height - topPad - bottomPad;
    final maxValue = days.fold<double>(
      1,
      (m, d) => math.max(m, math.max(d.inflow, d.outflow)),
    );
    final labelStyle = const TextStyle(fontSize: 11, color: Colors.grey);

    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = topPad + chartHeight * i / 3;
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(size.width - 8, y),
        gridPaint,
      );
      final value = maxValue * (3 - i) / 3;
      _drawLabel(
        canvas,
        _shortMoney(value),
        Offset(0, y - 7),
        labelStyle,
      );
    }

    final groupWidth = chartWidth / days.length;
    final barWidth = math.min(14.0, groupWidth / 3);
    for (var i = 0; i < days.length; i++) {
      final cx = leftPad + groupWidth * i + groupWidth / 2;
      final inHeight = chartHeight * days[i].inflow / maxValue;
      final outHeight = chartHeight * days[i].outflow / maxValue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            cx - barWidth - 2,
            topPad + chartHeight - inHeight,
            barWidth,
            inHeight,
          ),
          const Radius.circular(3),
        ),
        Paint()..color = _inflowColor,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            cx + 2,
            topPad + chartHeight - outHeight,
            barWidth,
            outHeight,
          ),
          const Radius.circular(3),
        ),
        Paint()..color = _outflowColor,
      );
      _drawLabel(
        canvas,
        '${days[i].date.day}',
        Offset(cx - 6, size.height - 18),
        labelStyle,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarFlowPainter old) => old.days != days;
}
