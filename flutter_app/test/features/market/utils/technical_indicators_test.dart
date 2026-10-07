import 'package:flutter_test/flutter_test.dart';
import 'package:ai_quant_app/features/market/providers/market_provider.dart';
import 'package:ai_quant_app/features/market/utils/technical_indicators.dart';

KlineBar _bar(double p) => KlineBar(
      time: p.toInt(),
      open: p,
      high: p + 0.5,
      low: p - 0.5,
      close: p,
      volume: 1000,
    );

/// 线性趋势 K 线
List<KlineBar> _trend(double from, double step, int n) =>
    [for (var i = 0; i < n; i++) _bar(from + step * i)];

/// 常量价格 K 线
List<KlineBar> _flat(double p, int n) => [for (var i = 0; i < n; i++) _bar(p)];

void main() {
  group('TechnicalIndicators · MA', () {
    test('MA3 精确值(窗口滚动)', () {
      // 前 10 根价格 1..10,之后恒 10
      final bars = [
        for (var i = 0; i < 80; i++) _bar(i < 10 ? i + 1.0 : 10),
      ];
      final ti = TechnicalIndicators(bars);
      final ma3 = ti.ma(3);
      expect(ma3[2], 2.0);
      expect(ma3[9], 9.0);
      expect(ma3[79], 10.0);
      expect(ma3[0], isNull);
    });

    test('常量序列:MA5/10/20/60 全部等于常量', () {
      final ti = TechnicalIndicators(_flat(100, 80));
      expect(ti.ma5[79], 100);
      expect(ti.ma10[79], 100);
      expect(ti.ma20[79], 100);
      expect(ti.ma60[79], 100);
    });
  });

  group('TechnicalIndicators · 趋势方向', () {
    test('强上涨:RSI=100、J≥K≥D、DIF/DEA≈7、柱≈0、贴布林上轨', () {
      final ti = TechnicalIndicators(_trend(0, 1, 80));
      const i = 79;
      expect(ti.rsi14[i], 100);
      expect(ti.j[i]! >= ti.k[i]!, isTrue);
      expect(ti.k[i]! >= ti.d[i]!, isTrue);
      expect(ti.dif[i]!, closeTo(7, 1e-9));
      expect(ti.dea[i]!, closeTo(7, 1e-9));
      // 完美线性趋势中柱稳定为 0(浮点容差)
      expect(ti.macdHist[i]!, closeTo(0, 1e-9));
      expect(ti.bollUpper[i]! >= ti.closes[i], isTrue);
      expect(ti.bollLower[i]! <= ti.closes[i], isTrue);
    });

    test('强下跌:RSI=0、DIF≈-7、DEA≈-7、柱≈0', () {
      final ti = TechnicalIndicators(_trend(100, -1, 80));
      const i = 79;
      expect(ti.rsi14[i], 0);
      expect(ti.dif[i]!, closeTo(-7, 1e-9));
      expect(ti.dea[i]!, closeTo(-7, 1e-9));
      expect(ti.macdHist[i]!, closeTo(0, 1e-9));
    });
  });

  group('TechnicalIndicators · 常量序列边界', () {
    test('BOLL 三轨收敛到常量', () {
      final ti = TechnicalIndicators(_flat(100, 80));
      expect(ti.bollMid[79], 100);
      expect(ti.bollUpper[79], 100);
      expect(ti.bollLower[79], 100);
    });

    test('MACD DIF/DEA/柱全 0,KDJ 收敛 50', () {
      final ti = TechnicalIndicators(_flat(100, 80));
      expect(ti.dif[79], closeTo(0, 1e-9));
      expect(ti.dea[79], closeTo(0, 1e-9));
      expect(ti.macdHist[79], closeTo(0, 1e-9));
      expect(ti.k[79], closeTo(50, 1e-9));
      expect(ti.d[79], closeTo(50, 1e-9));
      expect(ti.j[79], closeTo(50, 1e-9));
    });
  });
}
