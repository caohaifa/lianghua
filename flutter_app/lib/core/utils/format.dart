import '../../features/market/providers/market_provider.dart';

/// 大额简写:2.38T / 912.4B / 3.2M
String compactFmt(double v) {
  if (v >= 1e12) return '${(v / 1e12).toStringAsFixed(2)}T';
  if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(2)}B';
  if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(2)}M';
  if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
  return v.toStringAsFixed(2);
}

/// 价格文本:千分位 + 按量级取小数位
String priceText(Quote q) {
  final p = q.price;
  if (q.market == 'crypto') {
    if (p >= 1000) {
      final s = p.toStringAsFixed(0);
      final buf = StringBuffer();
      for (var i = 0; i < s.length; i++) {
        if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
        buf.write(s[i]);
      }
      return buf.toString();
    }
    if (p >= 1) return p.toStringAsFixed(2);
    if (p >= 0.01) return p.toStringAsFixed(4);
    return p.toStringAsFixed(7);
  }
  return p.toStringAsFixed(2);
}

/// 任意价格按量级格式化(盘口/K线用)
String priceOf(double p, {bool crypto = true}) {
  if (!crypto) return p.toStringAsFixed(2);
  if (p >= 1000) return p.toStringAsFixed(1);
  if (p >= 1) return p.toStringAsFixed(2);
  if (p >= 0.01) return p.toStringAsFixed(4);
  return p.toStringAsFixed(7);
}

/// 金额千分位格式化(固定两位小数):12,345.67
String moneyFmt(double v) {
  final s = v.toStringAsFixed(2);
  final parts = s.split('.');
  final buf = StringBuffer();
  for (var i = 0; i < parts[0].length; i++) {
    if (i > 0 && (parts[0].length - i) % 3 == 0) buf.write(',');
    buf.write(parts[0][i]);
  }
  return '${buf.toString()}.${parts[1]}';
}

/// 持仓数量按量级格式化:≥100 取整,≥1 四位,否则六位
String amountFmt(double v) {
  if (v >= 100) return v.toStringAsFixed(0);
  if (v >= 1) return v.toStringAsFixed(4);
  return v.toStringAsFixed(6);
}
