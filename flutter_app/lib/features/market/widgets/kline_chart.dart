import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/market_provider.dart';

/// 蜡烛 K 线图:OHLC 蜡烛 + 成交量柱 + 最新价虚线。
/// [upColor]/[downColor] 由调用方按市场传入(crypto 绿涨/A股红涨)。
class KlineChart extends StatelessWidget {
  final List<KlineBar> bars;
  final Color upColor;
  final Color downColor;
  final double height;

  const KlineChart({
    super.key,
    required this.bars,
    required this.upColor,
    required this.downColor,
    this.height = 260,
  });

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(child: Text('暂无K线数据', style: AppTheme.caption)),
      );
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _KlinePainter(bars, upColor, downColor),
      ),
    );
  }
}

class _KlinePainter extends CustomPainter {
  final List<KlineBar> bars;
  final Color upColor;
  final Color downColor;

  _KlinePainter(this.bars, this.upColor, this.downColor);

  @override
  void paint(Canvas canvas, Size size) {
    // 布局:上方 78% 蜡烛区,中间 4% 间隔,下方 18% 成交量
    final priceH = size.height * 0.78;
    final volTop = size.height * 0.82;
    final volH = size.height * 0.18;

    double hi = -double.infinity, lo = double.infinity, maxVol = 0;
    for (final b in bars) {
      if (b.high > hi) hi = b.high;
      if (b.low < lo) lo = b.low;
      if (b.volume > maxVol) maxVol = b.volume;
    }
    if (hi <= lo) hi = lo + 1e-9;
    final pad = (hi - lo) * 0.05;
    hi += pad;
    lo -= pad;

    final n = bars.length;
    final slot = size.width / n;
    final bodyW = (slot * 0.62).clamp(1.0, 14.0);

    double yOf(double price) => (hi - price) / (hi - lo) * priceH;

    final wickPaint = Paint()..strokeWidth = 1;
    final bodyPaint = Paint();

    for (var i = 0; i < n; i++) {
      final b = bars[i];
      final cx = slot * i + slot / 2;
      final up = b.close >= b.open;
      final color = up ? upColor : downColor;

      // 影线
      wickPaint.color = color;
      canvas.drawLine(Offset(cx, yOf(b.high)), Offset(cx, yOf(b.low)), wickPaint);
      // 实体
      bodyPaint.color = color;
      final top = yOf(up ? b.close : b.open);
      final bottom = yOf(up ? b.open : b.close);
      canvas.drawRect(
        Rect.fromLTRB(cx - bodyW / 2, top, cx + bodyW / 2,
            bottom == top ? top + 1 : bottom),
        bodyPaint,
      );
      // 成交量柱
      if (maxVol > 0) {
        final vh = (b.volume / maxVol) * volH;
        bodyPaint.color = color.withValues(alpha: 0.5);
        canvas.drawRect(
          Rect.fromLTRB(cx - bodyW / 2, volTop + volH - vh, cx + bodyW / 2,
              volTop + volH),
          bodyPaint,
        );
      }
    }

    // 最新价虚线 + 标签
    final last = bars.last.close;
    final ly = yOf(last);
    final lastColor = last >= bars.last.open ? upColor : downColor;
    final dashPaint = Paint()
      ..color = lastColor.withValues(alpha: 0.7)
      ..strokeWidth = 0.8;
    const dashW = 4.0, gapW = 3.0;
    double x = 0;
    while (x < size.width - 52) {
      canvas.drawLine(Offset(x, ly), Offset(x + dashW, ly), dashPaint);
      x += dashW + gapW;
    }
    // 价格标签
    final tp = TextPainter(
      text: TextSpan(
        text: last.toStringAsFixed(2),
        style: TextStyle(color: lastColor, fontSize: 10, fontFamily: 'RobotoMono'),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(size.width - tp.width - 4, ly - tp.height / 2));

    // 最高/最低价标注
    final rangeTp = TextPainter(
      text: TextSpan(
        text: '${hi.toStringAsFixed(2)}  ·  ${lo.toStringAsFixed(2)}',
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    rangeTp.paint(canvas, const Offset(4, 2));
  }

  @override
  bool shouldRepaint(_KlinePainter old) => true;
}
