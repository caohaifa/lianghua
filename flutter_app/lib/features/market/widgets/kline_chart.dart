import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/market_provider.dart';
import '../utils/kline_signals.dart';
import '../utils/technical_indicators.dart';

/// 蜡烛 K 线图:OHLC 蜡烛 + 主图叠加(MA/BOLL)+ 副图(VOL/MACD/KDJ/RSI)
/// + 最新价虚线 + 指标多空信号标记。
/// [upColor]/[downColor] 由调用方按市场传入(crypto 绿涨/A股红涨)。
class KlineChart extends StatefulWidget {
  final List<KlineBar> bars;
  final Color upColor;
  final Color downColor;
  final double height;

  /// 是否显示多空预测信号
  final bool showSignals;

  /// 是否允许开空标记(A股 false,仅显示多信号)
  final bool allowShort;

  /// 主图叠加
  final bool showMa;
  final bool showBoll;

  /// 当前副图指标
  final SubIndicator sub;

  const KlineChart({
    super.key,
    required this.bars,
    required this.upColor,
    required this.downColor,
    this.height = 260,
    this.showSignals = true,
    this.allowShort = true,
    this.showMa = true,
    this.showBoll = false,
    this.sub = SubIndicator.vol,
  });

  @override
  State<KlineChart> createState() => _KlineChartState();
}

class _KlineChartState extends State<KlineChart> {
  /// 缓存指标集合:只在 bars 引用变化时重新计算
  late TechnicalIndicators _ti;
  late List<KlineBar> _cachedBars;
  List<KlineSignal> _signals = const [];

  @override
  void initState() {
    super.initState();
    _recompute();
  }

  @override
  void didUpdateWidget(KlineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // bars 变化,或信号相关开关变化时才重算(副图/MA/BOLL 切换不影响信号,交给 painter 重绘即可)
    if (!identical(widget.bars, _cachedBars) ||
        widget.bars.length != _cachedBars.length ||
        widget.showSignals != oldWidget.showSignals ||
        widget.allowShort != oldWidget.allowShort) {
      _recompute();
    }
  }

  /// 全套指标只构建一次,信号复用同一实例 → 每根 tick 由 2× 降为 1×
  void _recompute() {
    _cachedBars = widget.bars;
    _ti = TechnicalIndicators(_cachedBars);
    _signals = (widget.showSignals && _cachedBars.length >= 35)
        ? KlineSignalGenerator(_cachedBars)
            .generateWith(_ti)
            .where((s) => widget.allowShort || s.side == KlineSignalSide.long)
            .toList()
        : const [];
  }

  @override
  Widget build(BuildContext context) {
    final bars = _cachedBars;
    if (bars.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const Center(child: Text('暂无K线数据', style: AppTheme.caption)),
      );
    }
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: CustomPaint(
        painter: _KlinePainter(
          bars: bars,
          upColor: widget.upColor,
          downColor: widget.downColor,
          signals: _signals,
          ti: _ti,
          showMa: widget.showMa,
          showBoll: widget.showBoll,
          sub: widget.sub,
        ),
      ),
    );
  }
}

// 指标配色
const _cMa5 = Color(0xFFFFEE83);
const _cMa10 = Color(0xFFF0884E);
const _cMa20 = Color(0xFF7E9CFF);
const _cMa60 = Color(0xFF2FB8A4);
const _cBollBand = Color(0xFF8E9BAE);
const _cBollMid = Color(0xFFE8C87A);
const _cDif = Color(0xFFFFEE83);
const _cDea = Color(0xFF7E9CFF);
const _cK = Color(0xFFE879F9);
const _cD = Color(0xFF60A5FA);
const _cJ = Color(0xFFFBBF24);
const _cRsi = Color(0xFFC084FC);

class _KlinePainter extends CustomPainter {
  final List<KlineBar> bars;
  final Color upColor;
  final Color downColor;
  final List<KlineSignal> signals;
  final TechnicalIndicators ti;
  final bool showMa;
  final bool showBoll;
  final SubIndicator sub;

  _KlinePainter({
    required this.bars,
    required this.upColor,
    required this.downColor,
    required this.signals,
    required this.ti,
    required this.showMa,
    required this.showBoll,
    required this.sub,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 布局:上方 62% 主图,中间 8% 间隔,下方 30% 副图
    final mainH = size.height * 0.62;
    final subTop = size.height * 0.70;
    final subH = size.height * 0.30;

    final n = bars.length;
    final slot = size.width / n;
    final bodyW = (slot * 0.62).clamp(1.0, 14.0);

    // 主图价格范围:蜡烛 + BOLL 轨道(若显示)
    double hi = -double.infinity, lo = double.infinity;
    for (final b in bars) {
      if (b.high > hi) hi = b.high;
      if (b.low < lo) lo = b.low;
    }
    if (showBoll) {
      for (var i = 0; i < n; i++) {
        final u = ti.bollUpper[i], l = ti.bollLower[i];
        if (u != null && u > hi) hi = u;
        if (l != null && l < lo) lo = l;
      }
    }
    if (hi <= lo) hi = lo + 1e-9;
    final pad = (hi - lo) * 0.05;
    hi += pad;
    lo -= pad;

    double yOf(double price) => (hi - price) / (hi - lo) * mainH;
    double xAt(int i) => slot * i + slot / 2;

    // ── 蜡烛 ───────────────────────────────────────────────
    final wickPaint = Paint()..strokeWidth = 1;
    final bodyPaint = Paint();
    for (var i = 0; i < n; i++) {
      final b = bars[i];
      final up = b.close >= b.open;
      final color = up ? upColor : downColor;
      wickPaint.color = color;
      canvas.drawLine(
          Offset(xAt(i), yOf(b.high)), Offset(xAt(i), yOf(b.low)), wickPaint);
      bodyPaint.color = color;
      final top = yOf(up ? b.close : b.open);
      final bottom = yOf(up ? b.open : b.close);
      canvas.drawRect(
        Rect.fromLTRB(xAt(i) - bodyW / 2, top, xAt(i) + bodyW / 2,
            bottom == top ? top + 1 : bottom),
        bodyPaint,
      );
    }

    // ── BOLL(先画,线在蜡烛下层感) ─────────────────────────
    if (showBoll) {
      _plotLine(canvas, ti.bollUpper, yOf, xAt, n, _cBollBand, 0.9);
      _plotLine(canvas, ti.bollLower, yOf, xAt, n, _cBollBand, 0.9);
      _plotLine(canvas, ti.bollMid, yOf, xAt, n, _cBollMid, 0.9);
    }

    // ── MA ────────────────────────────────────────────────
    if (showMa) {
      _plotLine(canvas, ti.ma5, yOf, xAt, n, _cMa5, 1.1);
      _plotLine(canvas, ti.ma10, yOf, xAt, n, _cMa10, 1.1);
      _plotLine(canvas, ti.ma20, yOf, xAt, n, _cMa20, 1.1);
      _plotLine(canvas, ti.ma60, yOf, xAt, n, _cMa60, 1.1);
    }

    // ── 多空信号箭头(绿↑贴 low 下/红↓贴 high 上,尖端指向蜡烛柱) ──
    const arrowW = 11.0, arrowH = 8.0, gap = 3.0;
    for (final s in signals) {
      if (s.index < 0 || s.index >= n) continue;
      final b = bars[s.index];
      final isLong = s.side == KlineSignalSide.long;
      bodyPaint.color = isLong ? upColor : downColor;
      final cx = xAt(s.index);
      var cy = isLong
          ? yOf(b.low) + gap + arrowH / 2
          : yOf(b.high) - gap - arrowH / 2;
      cy = cy.clamp(arrowH / 2 + 1, mainH - arrowH / 2 - 1).toDouble();
      final path = Path();
      if (isLong) {
        // 顶点朝上,指向蜡烛
        path.moveTo(cx, cy - arrowH / 2);
        path.lineTo(cx - arrowW / 2, cy + arrowH / 2);
        path.lineTo(cx + arrowW / 2, cy + arrowH / 2);
      } else {
        // 顶点朝下,指向蜡烛
        path.moveTo(cx, cy + arrowH / 2);
        path.lineTo(cx - arrowW / 2, cy - arrowH / 2);
        path.lineTo(cx + arrowW / 2, cy - arrowH / 2);
      }
      path.close();
      canvas.drawPath(path, bodyPaint);
    }

    // ── 最新价虚线 + 标签 ──────────────────────────────────
    final last = bars.last.close;
    final ly = yOf(last);
    final lastColor = last >= bars.last.open ? upColor : downColor;
    final dashPaint = Paint()
      ..color = lastColor.withValues(alpha: 0.7)
      ..strokeWidth = 0.8;
    const dashW = 4.0, gapW = 3.0;
    var x = 0.0;
    while (x < size.width - 52) {
      canvas.drawLine(Offset(x, ly), Offset(x + dashW, ly), dashPaint);
      x += dashW + gapW;
    }
    _text(last.toStringAsFixed(2), lastColor, 10)
        .paint(canvas, Offset(size.width - 48, ly - 6));

    // ── 主图左上角指标读数 ─────────────────────────────────
    final titleY = _mainTitle(canvas, ti, n - 1);
    // 高低价
    _text('${hi.toStringAsFixed(2)} · ${lo.toStringAsFixed(2)}',
            AppTheme.textSecondary, 9)
        .paint(canvas, Offset(4, titleY + 2));

    // ══════════════ 副图 ══════════════
    _drawSub(canvas, ti, subTop, subH, size.width, bodyW, xAt: xAt);
  }

  /// 主图指标读数,返回下一可用 y
  double _mainTitle(Canvas canvas, TechnicalIndicators ti, int i) {
    var y = 2.0;
    if (showMa) {
      _rich([
        _span('MA5 ', _cMa5, ti.ma5[i]),
        _span(' MA10 ', _cMa10, ti.ma10[i]),
      ]).paint(canvas, Offset(4, y));
      y += 12;
      _rich([
        _span('MA20 ', _cMa20, ti.ma20[i]),
        _span(' MA60 ', _cMa60, ti.ma60[i]),
      ]).paint(canvas, Offset(4, y));
      y += 12;
    }
    if (showBoll) {
      _rich([
        _span('UP ', _cBollBand, ti.bollUpper[i]),
        _span(' MID ', _cBollMid, ti.bollMid[i]),
        _span(' LOW ', _cBollBand, ti.bollLower[i]),
      ]).paint(canvas, Offset(4, y));
      y += 12;
    }
    return y;
  }

  void _drawSub(Canvas canvas, TechnicalIndicators ti, double top, double h,
      double width, double bodyW,
      {required double Function(int i) xAt}) {
    final n = bars.length;
    switch (sub) {
      case SubIndicator.vol:
        double maxVol = 0;
        for (final b in bars) {
          if (b.volume > maxVol) maxVol = b.volume;
        }
        final paint = Paint();
        if (maxVol > 0) {
          for (var i = 0; i < n; i++) {
            final b = bars[i];
            final vh = b.volume / maxVol * (h - 14);
            paint.color = (b.close >= b.open ? upColor : downColor)
                .withValues(alpha: 0.6);
            canvas.drawRect(
              Rect.fromLTRB(xAt(i) - bodyW / 2, top + 14 + (h - 14) - vh,
                  xAt(i) + bodyW / 2, top + h),
              paint,
            );
          }
        }
        _text('VOL', AppTheme.textSecondary, 9)
            .paint(canvas, Offset(4, top + 1));
      case SubIndicator.macd:
        double hh = 0;
        for (var i = 0; i < n; i++) {
          final v = ti.macdHist[i];
          if (v != null && v.abs() > hh) hh = v.abs();
        }
        if (hh == 0) hh = 1;
        hh *= 1.2;
        double yV(double v) => top + 14 + (h - 14) / 2 - v / hh * (h - 14) / 2;
        // 0 轴
        canvas.drawLine(
            Offset(0, yV(0)),
            Offset(width, yV(0)),
            Paint()
              ..color = AppTheme.textSecondary.withValues(alpha: 0.4)
              ..strokeWidth = 0.6);
        // hist 柱
        final paint = Paint();
        for (var i = 0; i < n; i++) {
          final v = ti.macdHist[i];
          if (v == null) continue;
          paint.color = (v >= 0 ? upColor : downColor).withValues(alpha: 0.6);
          canvas.drawRect(
            Rect.fromLTRB(xAt(i) - bodyW / 2, yV(0).clamp(top + 14, top + h),
                xAt(i) + bodyW / 2, yV(v).clamp(top + 14, top + h)),
            paint,
          );
        }
        _plotLineAt(canvas, ti.dif, yV, xAt, n, _cDif, 1.0, top + 14, top + h);
        _plotLineAt(canvas, ti.dea, yV, xAt, n, _cDea, 1.0, top + 14, top + h);
        _rich([
          _span('DIF ', _cDif, ti.dif[n - 1]),
          _span(' DEA ', _cDea, ti.dea[n - 1]),
          _span(' MACD ', upColor, ti.macdHist[n - 1]),
        ]).paint(canvas, Offset(4, top + 1));
      case SubIndicator.kdj:
        double yV(double v) =>
            top + 14 + (1 - (v.clamp(0, 100)) / 100) * (h - 14);
        for (final lv in [20.0, 80.0]) {
          canvas.drawLine(
              Offset(0, yV(lv)),
              Offset(width, yV(lv)),
              Paint()
                ..color = AppTheme.textSecondary.withValues(alpha: 0.3)
                ..strokeWidth = 0.6);
        }
        _plotLineAt(canvas, ti.k, yV, xAt, n, _cK, 1.0, top + 14, top + h);
        _plotLineAt(canvas, ti.d, yV, xAt, n, _cD, 1.0, top + 14, top + h);
        _plotLineAt(canvas, ti.j, yV, xAt, n, _cJ, 1.0, top + 14, top + h);
        _rich([
          _span('K ', _cK, ti.k[n - 1]),
          _span(' D ', _cD, ti.d[n - 1]),
          _span(' J ', _cJ, ti.j[n - 1]),
        ]).paint(canvas, Offset(4, top + 1));
      case SubIndicator.rsi:
        double yV(double v) =>
            top + 14 + (1 - (v.clamp(0, 100)) / 100) * (h - 14);
        for (final lv in [30.0, 50.0, 70.0]) {
          canvas.drawLine(
              Offset(0, yV(lv)),
              Offset(width, yV(lv)),
              Paint()
                ..color = AppTheme.textSecondary.withValues(alpha: 0.3)
                ..strokeWidth = 0.6);
        }
        _plotLineAt(
            canvas, ti.rsi14, yV, xAt, n, _cRsi, 1.1, top + 14, top + h);
        _rich([
          _span('RSI(14) ', _cRsi, ti.rsi14[n - 1]),
        ]).paint(canvas, Offset(4, top + 1));
    }
  }

  // ── 绘制/文本工具 ─────────────────────────────────────────

  void _plotLine(Canvas canvas, List<double?> v, double Function(double) y,
      double Function(int) xAt, int n, Color color, double sw) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = sw
      ..isAntiAlias = true;
    Offset? prev;
    for (var i = 0; i < n; i++) {
      final val = v[i];
      if (val == null) {
        prev = null;
        continue;
      }
      final o = Offset(xAt(i), y(val));
      if (prev != null) canvas.drawLine(prev, o, paint);
      prev = o;
    }
  }

  void _plotLineAt(
      Canvas canvas,
      List<double?> v,
      double Function(double) y,
      double Function(int) xAt,
      int n,
      Color color,
      double sw,
      double minY,
      double maxY) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = sw
      ..isAntiAlias = true;
    Offset? prev;
    for (var i = 0; i < n; i++) {
      final val = v[i];
      if (val == null) {
        prev = null;
        continue;
      }
      final o = Offset(xAt(i), y(val).clamp(minY, maxY));
      if (prev != null) canvas.drawLine(prev, o, paint);
      prev = o;
    }
  }

  TextPainter _text(String s, Color color, double size) => TextPainter(
        text: TextSpan(
          text: s,
          style:
              TextStyle(color: color, fontSize: size, fontFamily: 'RobotoMono'),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  TextSpan _span(String label, Color color, double? v) => TextSpan(children: [
        TextSpan(text: label, style: TextStyle(color: color, fontSize: 9)),
        TextSpan(
          text: v == null ? '--' : v.toStringAsFixed(2),
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 9),
        ),
      ]);

  TextPainter _rich(List<TextSpan> spans) => TextPainter(
        text: TextSpan(children: spans),
        textDirection: TextDirection.ltr,
      )..layout();

  @override
  bool shouldRepaint(_KlinePainter old) {
    // 只在 bars 引用变化或指标开关切换时重绘
    return !identical(old.bars, bars) ||
        old.showMa != showMa ||
        old.showBoll != showBoll ||
        old.sub != sub ||
        old.upColor != upColor ||
        old.downColor != downColor;
  }
}
