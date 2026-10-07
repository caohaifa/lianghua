import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_quant_app/features/market/providers/market_provider.dart';
import 'package:ai_quant_app/features/market/utils/technical_indicators.dart';
import 'package:ai_quant_app/features/market/widgets/kline_chart.dart';

void main() {
  final bars = [
    for (var i = 0; i < 120; i++)
      KlineBar(
        time: i,
        open: 100 + i.toDouble(),
        high: 101 + i.toDouble(),
        low: 99 + i.toDouble(),
        close: 100 + i.toDouble(),
        volume: i * 10.0,
      ),
  ];

  Widget wrap(KlineChart chart) => MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: chart)),
      );

  testWidgets('KlineChart 默认渲染蜡烛+MA+VOL,无异常', (tester) async {
    await tester.pumpWidget(wrap(KlineChart(
      bars: bars,
      upColor: Colors.green,
      downColor: Colors.red,
    )));
    expect(tester.takeException(), isNull);
    // Material 内部本身含一个 CustomPaint,故用 findsWidgets
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('主图 BOLL 叠加可正常绘制', (tester) async {
    await tester.pumpWidget(wrap(KlineChart(
      bars: bars,
      upColor: Colors.green,
      downColor: Colors.red,
      showBoll: true,
    )));
    expect(tester.takeException(), isNull);
  });

  testWidgets('副图 MACD/KDJ/RSI 分别绘制均无异常', (tester) async {
    for (final sub in SubIndicator.values) {
      await tester.pumpWidget(wrap(KlineChart(
        bars: bars,
        upColor: Colors.green,
        downColor: Colors.red,
        sub: sub,
      )));
      expect(tester.takeException(), isNull, reason: 'sub=$sub');
    }
  });

  testWidgets('空数据显示占位文本', (tester) async {
    await tester.pumpWidget(wrap(const KlineChart(
      bars: [],
      upColor: Colors.green,
      downColor: Colors.red,
    )));
    expect(find.text('暂无K线数据'), findsOneWidget);
  });
}
