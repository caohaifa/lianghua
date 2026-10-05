import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/finance_card.dart';
import '../../position/widgets/order_sheet.dart';
import '../providers/market_provider.dart';
import '../widgets/data_source_badge.dart';
import '../widgets/kline_chart.dart';

/// 标的情详情:实时价格/涨跌幅 + K线(周期切换) + 买入/卖出下单入口
class QuoteDetailPage extends StatefulWidget {
  final String symbol;
  const QuoteDetailPage({super.key, required this.symbol});

  @override
  State<QuoteDetailPage> createState() => _QuoteDetailPageState();
}

class _QuoteDetailPageState extends State<QuoteDetailPage> {
  static const _periods = {'1m': '1分', '5m': '5分', '1h': '1时', '1d': '1日'};
  String _period = '1m';
  List<KlineBar> _bars = [];
  bool _klineLoading = true;

  @override
  void initState() {
    super.initState();
    _loadKline();
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
    Quote? quote;
    for (final q in market.quotes) {
      if (q.symbol == widget.symbol) {
        quote = q;
        break;
      }
    }

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

    return Scaffold(
      appBar: AppBar(title: Text(q.symbol)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 实时价格区
            FinanceCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(q.name, style: AppTheme.caption),
                      const SizedBox(width: 8),
                      Text(isCrypto ? '加密货币' : 'A股指数', style: AppTheme.caption),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    q.price.toStringAsFixed(2),
                    style: TextStyle(
                        color: color,
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'RobotoMono'),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppTheme.tagRadius),
                    ),
                    child: Text(
                      '${isUp ? '+' : ''}${q.change.toStringAsFixed(2)}%',
                      style: TextStyle(
                          color: color,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'RobotoMono'),
                    ),
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
            ),
            const SizedBox(height: 16),
            // K 线区:周期切换 + 蜡烛图
            FinanceCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text('K线', style: AppTheme.body),
                      const Spacer(),
                      ..._periods.entries.map((e) => Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: ChoiceChip(
                              label: Text(e.value),
                              selected: _period == e.key,
                              onSelected: (_) {
                                if (_period == e.key) return;
                                setState(() => _period = e.key);
                                _loadKline();
                              },
                              visualDensity: VisualDensity.compact,
                            ),
                          )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _klineLoading
                      ? const SizedBox(
                          height: 260,
                          child: Center(child: CircularProgressIndicator()))
                      : KlineChart(
                          bars: liveBars,
                          upColor: buyColor,
                          downColor: sellColor,
                        ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
