import 'package:flutter_test/flutter_test.dart';
import 'package:ai_quant_app/features/market/providers/market_provider.dart';
import 'package:ai_quant_app/features/market/utils/kline_signals.dart';

/// 以价格 p 为中心造一根 K 线
KlineBar _bar(double p, int t) => KlineBar(
      time: t,
      open: p,
      high: p + 0.5,
      low: p - 0.5,
      close: p,
      volume: 1000,
    );

/// V 型:前 half 根线性下跌 start→end,后 half 根线性回升
List<KlineBar> _vShape(double from, double to, int total) {
  final half = total ~/ 2;
  final downStep = (to - from) / (half - 1);
  final upStep = (from - to) / (total - half - 1);
  return [
    for (var i = 0; i < half; i++) _bar(from + downStep * i, i),
    for (var i = 0; i < total - half; i++) _bar(to + upStep * i, half + i),
  ];
}

void main() {
  group('KlineSignalGenerator', () {
    test('V 型(先跌后涨):后半段出现开多信号', () {
      final bars = _vShape(100, 50, 120);
      final signals = KlineSignalGenerator(bars).generate();

      expect(signals, isNotEmpty);
      final last = signals.last;
      expect(last.side, KlineSignalSide.long);
      expect(last.index, greaterThan(55));
      expect(last.score, greaterThanOrEqualTo(3));
    });

    test('倒 V 型(先涨后跌):后半段出现开空信号', () {
      // 先涨后跌:把 V 型价格镜像
      final v = _vShape(100, 50, 120);
      final bars = [
        for (var i = 0; i < v.length; i++)
          KlineBar(
            time: i,
            open: 150 - v[i].open,
            high: 150 - v[i].low,
            low: 150 - v[i].high,
            close: 150 - v[i].close,
            volume: 1000,
          ),
      ];
      final signals = KlineSignalGenerator(bars).generate();

      expect(signals, isNotEmpty);
      final last = signals.last;
      expect(last.side, KlineSignalSide.short);
      expect(last.index, greaterThan(55));
      expect(last.score, lessThanOrEqualTo(-3));
    });

    test('信号索引合法且相邻信号方向交替(同向去重)', () {
      final signals = KlineSignalGenerator(_vShape(100, 50, 120)).generate();

      for (final s in signals) {
        expect(s.index, inInclusiveRange(0, 119));
      }
      for (var i = 1; i < signals.length; i++) {
        expect(signals[i].side, isNot(signals[i - 1].side));
        expect(signals[i].index, greaterThan(signals[i - 1].index));
      }
    });

    test('三种以上指标共振即判定(阈值 3)', () {
      expect(KlineSignalGenerator.consensus, 3);
    });

    test('数据不足 35 根返回空', () {
      final bars = [for (var i = 0; i < 30; i++) _bar(100 + i.toDouble(), i)];
      expect(KlineSignalGenerator(bars).generate(), isEmpty);
    });
  });
}
