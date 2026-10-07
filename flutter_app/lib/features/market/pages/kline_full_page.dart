import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/market_provider.dart';
import '../utils/technical_indicators.dart';
import '../widgets/kline_chart.dart';
import '../widgets/kline_control_panel.dart';

/// K 线全屏页:横向大空间蜡烛图(主图 MA/BOLL 叠加)+ 副图(VOL/MACD/KDJ/RSI)
class KlineFullPage extends StatefulWidget {
  final String symbol;
  final String period;
  const KlineFullPage({super.key, required this.symbol, required this.period});

  @override
  State<KlineFullPage> createState() => _KlineFullPageState();
}

class _KlineFullPageState extends State<KlineFullPage> {
  /// 加密:币安完整时间段;A股:新浪支持的分钟/日线
  static const _cryptoPeriods = <String, String>{
    '1m': '1分',
    '3m': '3分',
    '5m': '5分',
    '15m': '15分',
    '30m': '30分',
    '1h': '1时',
    '2h': '2时',
    '4h': '4时',
    '6h': '6时',
    '8h': '8时',
    '12h': '12时',
    '1d': '1日',
    '3d': '3日',
    '1w': '1周',
    '1M': '1月',
  };
  static const _aSharePeriods = <String, String>{
    '5m': '5分',
    '15m': '15分',
    '30m': '30分',
    '1h': '1时',
    '1d': '1日',
  };

  late String _period = _resolvePeriod(widget.period, widget.symbol);
  List<KlineBar> _bars = [];
  bool _loading = true;

  bool _showMa = true;
  bool _showBoll = false;
  SubIndicator _sub = SubIndicator.vol;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final bars = await context
          .read<MarketProvider>()
          .fetchKline(widget.symbol, period: _period);
      if (!mounted) return;
      setState(() {
        _bars = bars;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final market = context.watch<MarketProvider>();
    final quote =
        market.quotes.where((q) => q.symbol == widget.symbol).firstOrNull;
    final up = (quote?.change ?? 0) >= 0;
    final color = up ? AppTheme.bull : AppTheme.bear;
    final liveBars = _mergeLive(_bars, quote?.price ?? 0);
    final isCrypto = widget.symbol.contains('/');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.symbol),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(quote == null ? '' : '\$${_fmtPrice(quote.price)}',
                  style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'RobotoMono')),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 共用控制面板:周期 + 主图指标 + 副图指标
          KlineControlPanel(
            currentPeriod: _period,
            periods: isCrypto ? _cryptoPeriods : _aSharePeriods,
            showMa: _showMa,
            showBoll: _showBoll,
            sub: _sub,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            onPeriodChanged: (p) {
              if (_period == p) return;
              setState(() => _period = p);
              _load();
            },
            onToggleMa: () => setState(() => _showMa = !_showMa),
            onToggleBoll: () => setState(() => _showBoll = !_showBoll),
            onSubChanged: (s) => setState(() => _sub = s),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : LayoutBuilder(
                      builder: (_, c) => KlineChart(
                        bars: liveBars,
                        upColor: AppTheme.bull,
                        downColor: AppTheme.bear,
                        height: c.maxHeight,
                        allowShort: isCrypto,
                        showMa: _showMa,
                        showBoll: _showBoll,
                        sub: _sub,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// A股新浪不提供 1m:传入 1m 时回退 5m
  static String _resolvePeriod(String period, String symbol) {
    if (!symbol.contains('/') && period == '1m') return '5m';
    return period;
  }

  /// WS 实时价合并末根
  List<KlineBar> _mergeLive(List<KlineBar> bars, double live) {
    if (bars.isEmpty || live == 0) return bars;
    final last = bars.last;
    if (last.close == live) return bars;
    final merged = KlineBar(
      time: last.time,
      open: last.open,
      high: live > last.high ? live : last.high,
      low: live < last.low ? live : last.low,
      close: live,
      volume: last.volume,
    );
    return [...bars.sublist(0, bars.length - 1), merged];
  }

  static String _fmtPrice(double v) {
    if (v >= 1000) {
      final s = v.toStringAsFixed(2);
      final parts = s.split('.');
      final buf = StringBuffer();
      for (var i = 0; i < parts[0].length; i++) {
        if (i > 0 && (parts[0].length - i) % 3 == 0) buf.write(',');
        buf.write(parts[0][i]);
      }
      return '${buf.toString()}.${parts[1]}';
    }
    if (v >= 1) return v.toStringAsFixed(3);
    return v.toStringAsFixed(5);
  }
}
