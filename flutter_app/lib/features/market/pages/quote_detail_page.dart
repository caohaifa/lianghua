import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/finance_card.dart';
import '../../../core/utils/format.dart';
import '../../position/widgets/order_sheet.dart';
import '../providers/favorites_provider.dart';
import '../providers/market_provider.dart';
import '../widgets/data_source_badge.dart';
import '../widgets/depth_chart.dart';
import '../widgets/kline_chart.dart';
import '../widgets/kline_control_panel.dart';
import '../widgets/order_book.dart';
import '../utils/technical_indicators.dart';

/// 标的情详情:实时价格/涨跌幅 + K线(周期切换) + 买入/卖出下单入口
class QuoteDetailPage extends StatefulWidget {
  final String symbol;
  const QuoteDetailPage({super.key, required this.symbol});

  @override
  State<QuoteDetailPage> createState() => _QuoteDetailPageState();
}

class _QuoteDetailPageState extends State<QuoteDetailPage> {
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

  String _period = '1m';
  List<KlineBar> _bars = [];
  bool _klineLoading = true;

  // 指标显示状态
  bool _showMa = true;
  bool _showBoll = false;
  SubIndicator _sub = SubIndicator.vol;

  // 交易所模式(仅加密):盘口/成交流水,4 秒轮询
  List<List<double>> _bids = const [];
  List<List<double>> _asks = const [];
  List<TradeTick> _trades = const [];
  Timer? _bookTimer;

  bool get _isCryptoSymbol => widget.symbol.contains('/');

  @override
  void initState() {
    super.initState();
    // A股新浪不提供 1m,默认 5m
    if (!_isCryptoSymbol) _period = '5m';
    _loadKline();
    if (_isCryptoSymbol) {
      _initBook();
    }
  }

  /// 首次 await 盘口加载完成后启动定时轮询,避免 UI 显示"盘口加载中…"
  Future<void> _initBook() async {
    await _pollBook();
    _bookTimer = Timer.periodic(const Duration(seconds: 4), (_) => _pollBook());
  }

  @override
  void dispose() {
    _bookTimer?.cancel();
    super.dispose();
  }

  /// 拉取盘口 + 最新成交(并发,减少一次往返;静默失败,保留下次轮询)
  Future<void> _pollBook() async {
    try {
      final mp = context.read<MarketProvider>();
      final results = await Future.wait([
        mp.fetchDepth(widget.symbol, limit: 20),
        mp.fetchTrades(widget.symbol, limit: 30),
      ]);
      if (!mounted) return;
      final depth = results[0] as Map<String, List<List<double>>>;
      final trades = results[1] as List<TradeTick>;
      setState(() {
        _bids = depth['bids']!;
        _asks = depth['asks']!;
        _trades = trades;
      });
    } catch (_) {}
  }

  Future<void> _loadKline() async {
    setState(() => _klineLoading = true);
    try {
      final bars = await context
          .read<MarketProvider>()
          .fetchKline(widget.symbol, period: _period);
      if (!mounted) return;
      setState(() {
        _bars = bars;
        _klineLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _klineLoading = false);
    }
  }

  /// WS 实时价驱动末根 K 线(本地衔接,无需重新请求)
  List<KlineBar> _barsWithLiveTick(double livePrice) {
    if (_bars.isEmpty) return _bars;
    final last = _bars.last;
    if ((last.close - livePrice).abs() < 1e-9) return _bars;
    final merged = last.close == livePrice
        ? last
        : KlineBar(
            time: last.time,
            open: last.open,
            high: livePrice > last.high ? livePrice : last.high,
            low: livePrice < last.low ? livePrice : last.low,
            close: livePrice,
            volume: last.volume,
          );
    return [..._bars.sublist(0, _bars.length - 1), merged];
  }

  @override
  Widget build(BuildContext context) {
    final market = context.watch<MarketProvider>();
    final quote = market.quoteOf(widget.symbol);
    if (quote == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.symbol)),
        body: const Center(child: Text('暂无该标的行情', style: AppTheme.caption)),
      );
    }
    final q = quote;
    final isUp = q.change >= 0;
    final isCrypto = q.market == 'crypto';
    final color = isCrypto
        ? (isUp ? AppTheme.bull : AppTheme.bear)
        : (isUp ? AppTheme.bear : AppTheme.bull);
    final buyColor = isCrypto ? AppTheme.bull : AppTheme.bear;
    final sellColor = isCrypto ? AppTheme.bear : AppTheme.bull;
    final liveBars = _barsWithLiveTick(q.price);
    final dotHex = market.meta[q.symbol];
    final dotColor = dotHex == null
        ? const Color(0xFF2B3139)
        : Color(int.parse('FF${dotHex.substring(1)}', radix: 16));

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration:
                  BoxDecoration(color: dotColor, shape: BoxShape.circle),
              child: Text(q.symbol.substring(0, 1),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(isCrypto ? '${q.name} · ${q.symbol}' : q.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
        actions: [
          // 自选星标切换
          Builder(builder: (context) {
            final isFav = context.watch<FavoritesProvider>().isFav(q.symbol);
            return IconButton(
              onPressed: () =>
                  context.read<FavoritesProvider>().toggle(q.symbol),
              icon: Icon(
                isFav ? Icons.star : Icons.star_border,
                color: isFav ? AppTheme.brandPrimary : AppTheme.textSecondary,
              ),
            );
          }),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 实时价格区(币安式平铺:左价格/右24h量)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${q.name} · ${isCrypto ? '加密货币' : 'A股'}',
                              style: AppTheme.caption),
                          const SizedBox(height: 6),
                          Text(
                            isCrypto
                                ? priceText(q)
                                : q.price.toStringAsFixed(2),
                            style: TextStyle(
                                color: color,
                                fontSize: 34,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'RobotoMono'),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${isUp ? '+' : ''}${q.change.toStringAsFixed(2)}%',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'RobotoMono'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        _StatCell(
                            label: '24h最高',
                            value:
                                q.high > 0 ? q.high.toStringAsFixed(2) : '--'),
                        const SizedBox(width: 18),
                        _StatCell(
                            label: '24h最低',
                            value: q.low > 0 ? q.low.toStringAsFixed(2) : '--'),
                        const SizedBox(width: 18),
                        _StatCell(
                            label: '24h量', value: _formatVolume(q.volume)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    DataSourceBadge(market: q.market, fontSize: 11),
                    const SizedBox(width: 8),
                    const Text('实时行情 · 每 2 秒推送', style: AppTheme.caption),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // K 线区:周期切换 + 蜡烛图
            FinanceCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 第一行:标题/全屏
                  Row(
                    children: [
                      const Text('K线', style: AppTheme.body),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => context.push('/kline/full', extra: {
                          'symbol': widget.symbol,
                          'period': _period,
                        }),
                        child: const Icon(Icons.fullscreen,
                            size: 19, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 共用控制面板:周期 + 主图指标 + 副图指标
                  KlineControlPanel(
                    currentPeriod: _period,
                    periods: isCrypto ? _cryptoPeriods : _aSharePeriods,
                    showMa: _showMa,
                    showBoll: _showBoll,
                    sub: _sub,
                    padding: EdgeInsets.zero,
                    onPeriodChanged: (p) {
                      if (_period == p) return;
                      setState(() => _period = p);
                      _loadKline();
                    },
                    onToggleMa: () => setState(() => _showMa = !_showMa),
                    onToggleBoll: () => setState(() => _showBoll = !_showBoll),
                    onSubChanged: (s) => setState(() => _sub = s),
                  ),
                  const SizedBox(height: 12),
                  _klineLoading
                      ? const SizedBox(
                          height: 340,
                          child: Center(child: CircularProgressIndicator()))
                      : KlineChart(
                          bars: liveBars,
                          upColor: buyColor,
                          downColor: sellColor,
                          height: 340,
                          allowShort: isCrypto,
                          showMa: _showMa,
                          showBoll: _showBoll,
                          sub: _sub,
                        ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 交易所模式(仅加密):盘口 + 最新成交
            if (isCrypto) ...[
              FinanceCard(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final book = OrderBookPanel(
                      bids: _bids,
                      asks: _asks,
                      lastPrice: q.price,
                      lastPriceColor: color,
                    );
                    final trades = RecentTradesPanel(trades: _trades);
                    // 宽屏左右并列,窄屏上下堆叠
                    if (constraints.maxWidth >= 720) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: book),
                          const SizedBox(width: 24),
                          Expanded(child: trades),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        book,
                        const SizedBox(height: 16),
                        const Divider(color: AppTheme.divider),
                        const SizedBox(height: 16),
                        trades,
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              // 深度图(买卖累积量)
              FinanceCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('深度图', style: AppTheme.body),
                    const SizedBox(height: 12),
                    DepthChart(bids: _bids, asks: _asks),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            // 详细信息
            FinanceCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _InfoRow(label: '代码', value: q.symbol),
                  const Divider(color: AppTheme.divider, height: 20),
                  _InfoRow(label: '名称', value: q.name),
                  const Divider(color: AppTheme.divider, height: 20),
                  _InfoRow(label: '计价币种', value: q.currency),
                  const Divider(color: AppTheme.divider, height: 20),
                  _InfoRow(label: '成交量', value: _formatVolume(q.volume)),
                  const Divider(color: AppTheme.divider, height: 20),
                  _InfoRow(
                      label: '数据来源',
                      value: DataSourceBadge.sourceName(q.market)),
                ],
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      // 买入 / 卖出下单入口
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buyColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => showOrderSheet(context,
                      initialSymbol: q.symbol, initialSide: 'buy'),
                  child: const Text('买入', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: sellColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => showOrderSheet(context,
                      initialSymbol: q.symbol, initialSide: 'sell'),
                  child: const Text('卖出', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatVolume(double v) {
    if (v >= 1e8) return '${(v / 1e8).toStringAsFixed(1)}亿';
    if (v >= 1e4) return '${(v / 1e4).toStringAsFixed(1)}万';
    return v.toStringAsFixed(0);
  }
}

/// 24h 统计小格(label 上 + value 下,右对齐)
class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  const _StatCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: AppTheme.caption),
        const SizedBox(height: 6),
        Text(value, style: AppTheme.numberM),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTheme.caption),
        Text(value, style: AppTheme.body),
      ],
    );
  }
}
