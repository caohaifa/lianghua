import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// 深度图:买卖盘累积量曲线。左半买盘(绿,价格从低到最优),右半卖盘(红,价格从最优到高),
/// 中间交界即最优买/卖价。面积填充 + 描边。
class DepthChart extends StatelessWidget {
  final List<List<double>> bids; // [[price, qty]] 价降序
  final List<List<double>> asks; // [[price, qty]] 价升序
  final double height;

  const DepthChart({
    super.key,
    required this.bids,
    required this.asks,
    this.height = 160,
  });

  @override
  Widget build(BuildContext context) {
    if (bids.isEmpty && asks.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(child: Text('深度加载中…', style: AppTheme.caption)),
      );
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _DepthPainter(bids, asks)),
    );
  }
}

class _DepthPainter extends CustomPainter {
  final List<List<double>> bids;
  final List<List<double>> asks;

  _DepthPainter(this.bids, this.asks);

  @override
  void paint(Canvas canvas, Size size) {
    // 累积量:买盘从最优(价高)向外累积,卖盘同理
    final bidCum = _cumulate(bids);
    final askCum = _cumulate(asks);
    double maxCum = 0;
    if (bidCum.isNotEmpty) maxCum = bidCum.last;
    if (askCum.isNotEmpty && askCum.last > maxCum) maxCum = askCum.last;
    if (maxCum <= 0) return;

    double yOf(double cum) =>
        size.height - 14 - (cum / maxCum) * (size.height - 22);

    // 左半:买盘。x 从左(最低价档)到中点(最优买)
    _drawSide(
      canvas,
      size,
      cum: bidCum,
      xOf: (i, n) => (i + 1) / n * (size.width / 2),
      yOf: yOf,
      color: AppTheme.bull,
    );
    // 右半:卖盘。x 从中点(最优卖)到右(最高价档)
    _drawSide(
      canvas,
      size,
      cum: askCum,
      xOf: (i, n) => size.width / 2 + i / n * (size.width / 2),
      yOf: yOf,
      color: AppTheme.bear,
    );

    // 中线
    final midPaint = Paint()
      ..color = AppTheme.divider
      ..strokeWidth = 1;
    canvas.drawLine(Offset(size.width / 2, 0),
        Offset(size.width / 2, size.height - 12), midPaint);

    // 底部价格标注:左=最低买价,中=最优买/卖,右=最高卖价
    if (bids.isNotEmpty) {
      _label(canvas, bids.last[0].toStringAsFixed(2), const Offset(2, 0),
          size, AppTheme.textSecondary);
    }
    if (asks.isNotEmpty) {
      final tp = TextPainter(
        text: TextSpan(
          text: asks.last[0].toStringAsFixed(2),
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas,
          Offset(size.width - tp.width - 2, size.height - tp.height));
    }
  }

  List<double> _cumulate(List<List<double>> side) {
    final out = <double>[];
    double acc = 0;
    for (final e in side) {
      acc += e[1];
      out.add(acc);
    }
    return out;
  }

  void _drawSide(
    Canvas canvas,
    Size size, {
    required List<double> cum,
    required double Function(int i, int n) xOf,
    required double Function(double cum) yOf,
    required Color color,
  }) {
    if (cum.isEmpty) return;
    final n = cum.length;
    final line = Path();
    final area = Path();
    for (var i = 0; i < n; i++) {
      final x = xOf(i, n);
      final y = yOf(cum[i]);
      if (i == 0) {
        line.moveTo(x, y);
        area.moveTo(x, size.height - 14);
        area.lineTo(x, y);
      } else {
        // 阶梯状:先水平后垂直
        line.lineTo(x, yOf(cum[i - 1]));
        line.lineTo(x, y);
        area.lineTo(x, yOf(cum[i - 1]));
        area.lineTo(x, y);
      }
    }
    area.lineTo(xOf(n - 1, n), size.height - 14);
    area.close();

    canvas.drawPath(
        area,
        Paint()
          ..color = color.withValues(alpha: 0.15)
          ..style = PaintingStyle.fill);
    canvas.drawPath(
        line,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
  }

  void _label(Canvas canvas, String text, Offset at, Size size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
          text: text, style: TextStyle(color: color, fontSize: 9)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(at.dx, size.height - tp.height));
  }

  @override
  bool shouldRepaint(_DepthPainter old) => true;
}
