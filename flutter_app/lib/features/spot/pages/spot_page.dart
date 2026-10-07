import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../market/providers/favorites_provider.dart';
import '../../market/providers/market_provider.dart';
import '../../position/providers/position_provider.dart';

/// 现货主页(参考稿 spot):大价格 + 买卖盘 + 限价/市价下单
class SpotPage extends StatefulWidget {
  const SpotPage({super.key});

  @override
  State<SpotPage> createState() => _SpotPageState();
}

class _SpotPageState extends State<SpotPage> {
  String _symbol = 'BTC/USDT';
  bool _buy = true;
  bool _limit = false;
  bool _submitting = false;

  final _priceC = TextEditingController();
  final _amountC = TextEditingController();
  Map<String, List<List<double>>>? _depth;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PositionProvider>().loadAll();
    });
    _loadDepth();
    _timer =
        Timer.periodic(const Duration(milliseconds: 2500), (_) => _loadDepth());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _priceC.dispose();
    _amountC.dispose();
    super.dispose();
  }

  Future<void> _loadDepth() async {
    if (!RealMarket.isCrypto(_symbol)) return;
    try {
      final d =
          await context.read<MarketProvider>().fetchDepth(_symbol, limit: 20);
      if (mounted) setState(() => _depth = d);
    } catch (_) {}
  }

  void _switchSymbol(String s) {
    setState(() {
      _symbol = s;
      _depth = null;
      _priceC.clear();
      _amountC.clear();
    });
    _loadDepth();
  }

  @override
  Widget build(BuildContext context) {
    final market = context.watch<MarketProvider>();
    final pos = context.watch<PositionProvider>();
    final quote = market.quotes.where((q) => q.symbol == _symbol).firstOrNull;
    if (quote == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final crypto = quote.market == 'crypto';
    final up = quote.change >= 0;
    final mainColor = crypto
        ? (up ? AppTheme.bull : AppTheme.bear)
        : (up ? AppTheme.bear : AppTheme.bull);
    final currency = crypto ? 'USDT' : 'CNY';
    final account = crypto ? pos.account : pos.cnyAccount;
    final available = account?.available ?? 0;
    final holding = pos.positions.where((p) => p.symbol == _symbol).firstOrNull;
    final sellMax = holding?.amount ?? 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      children: [
        SafeArea(bottom: false, child: _header(context)),
        const SizedBox(height: 6),
        // 大价格
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(priceText(quote),
                style: TextStyle(
                    color: mainColor,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'RobotoMono')),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text('${up ? '+' : ''}${quote.change.toStringAsFixed(2)}%',
                  style: TextStyle(
                      color: mainColor,
                      fontSize: 14,
                      fontFamily: 'RobotoMono')),
            ),
          ],
        ),
        // 24h 高低/成交量
        if (quote.high > 0 || quote.low > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                _stat('24h最高', priceOf(quote.high, crypto: crypto)),
                const SizedBox(width: 18),
                _stat('24h最低', priceOf(quote.low, crypto: crypto)),
                const SizedBox(width: 18),
                _stat('24h量', compactFmt(quote.volume)),
              ],
            ),
          ),
        const SizedBox(height: 14),
        if (crypto)
          _OrderBook(
              depth: _depth,
              lastPrice: quote.price,
              coin: _coin(_symbol),
              up: up)
        else
          _ashareHint(),
        const SizedBox(height: 14),
        _orderCard(context,
            currency: currency, available: available, sellMax: sellMax),
        _openOrders(pos),
      ],
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontFamily: 'RobotoMono')),
      ],
    );
  }

  Widget _header(BuildContext context) {
    final fav = context.watch<FavoritesProvider>().isFav(_symbol);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _showSymbolPicker(context),
            child: Row(
              children: [
                Text(_symbol,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
                const Icon(Icons.keyboard_arrow_down, color: Colors.white),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => context.read<FavoritesProvider>().toggle(_symbol),
            child: Icon(fav ? Icons.star : Icons.star_border,
                size: 20,
                color: fav ? AppTheme.brandPrimary : AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  /// 当前委托:当前标的的限价挂单,支持撤单
  Widget _openOrders(PositionProvider pos) {
    final opens = pos.orders
        .where((o) => o.symbol == _symbol && o.status == 'pending')
        .toList();
    if (opens.isEmpty) return const SizedBox.shrink();
    final coin = _coin(_symbol);
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF181A20),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppTheme.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('当前委托 (${opens.length})',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          for (final o in opens)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Text(o.side == 'buy' ? '买入' : '卖出',
                      style: TextStyle(
                          color:
                              o.side == 'buy' ? AppTheme.bull : AppTheme.bear,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        '${o.price == null ? '--' : priceOf(o.price!, crypto: _symbol.contains('/'))} × ${trimQty(o.amount)} $coin',
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontFamily: 'RobotoMono')),
                  ),
                  GestureDetector(
                    onTap: () => _cancel(o.orderId),
                    child: const Text('撤单',
                        style: TextStyle(
                            color: AppTheme.brandPrimary, fontSize: 12)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _cancel(String orderId) async {
    final err = await context.read<PositionProvider>().cancelOrder(orderId);
    if (!mounted) return;
    _toast(err ?? '已撤单', err == null ? AppTheme.bull : AppTheme.bear);
  }

  Widget _ashareHint() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF181A20),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: AppTheme.textSecondary),
          SizedBox(width: 8),
          Expanded(
            child: Text('A股:1手=100股,按整手下单;当日买入T+1次交易日可卖',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _orderCard(BuildContext context,
      {required String currency,
      required double available,
      required double sellMax}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF181A20),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppTheme.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 买入/卖出
          Row(
            children: [
              _sideTab('买入', _buy, AppTheme.bull),
              const SizedBox(width: 10),
              _sideTab('卖出', !_buy, AppTheme.bear),
            ],
          ),
          const SizedBox(height: 12),
          // 限价/市价
          Row(
            children: [
              _typeTab('限价', _limit),
              const SizedBox(width: 16),
              _typeTab('市价', !_limit),
            ],
          ),
          const SizedBox(height: 12),
          // 价格
          SizedBox(
            height: 44,
            child: TextField(
              controller: _priceC,
              enabled: _limit,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, fontFamily: 'RobotoMono'),
              decoration: InputDecoration(
                hintText: _limit ? '价格' : '市价单按最新成交价',
                suffixText: currency,
                fillColor: const Color(0xFF23282F),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // 数量
          SizedBox(
            height: 44,
            child: TextField(
              controller: _amountC,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, fontFamily: 'RobotoMono'),
              decoration: InputDecoration(
                hintText: '数量',
                suffixText: _coin(_symbol),
                fillColor: const Color(0xFF23282F),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // 百分比条
          Row(
            children: [25, 50, 75, 100]
                .map((p) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: p == 100 ? 0 : 8),
                        child: _percentBtn(p,
                            currency: currency,
                            available: available,
                            sellMax: sellMax),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 10),
          Text(
            _buy
                ? '可用 ${moneyFmt(available)} $currency'
                : '可卖 ${trimQty(sellMax)} ${_coin(_symbol)}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: _submitting ? null : () => _submit(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _buy ? AppTheme.bull : AppTheme.bear,
                foregroundColor: AppTheme.onBrand,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                  _buy ? '买入 ${_coin(_symbol)}' : '卖出 ${_coin(_symbol)}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sideTab(String label, bool on, Color color) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _buy = label == '买入'),
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? color.withValues(alpha: 0.15) : const Color(0xFF23282F),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: on ? color : Colors.transparent),
          ),
          child: Text(label,
              style: TextStyle(
                  color: on ? color : AppTheme.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _typeTab(String label, bool on) {
    return GestureDetector(
      onTap: () {
        final toLimit = label == '限价';
        setState(() => _limit = toLimit);
        // 切到限价且未填价时,自动带入最新价(交易所常见交互)
        if (toLimit && _priceC.text.isEmpty) {
          final q = context
              .read<MarketProvider>()
              .quotes
              .where((q) => q.symbol == _symbol)
              .firstOrNull;
          if (q != null) {
            _priceC.text = priceOf(q.price, crypto: q.market == 'crypto');
          }
        }
      },
      child: Text(label,
          style: TextStyle(
              color: on ? AppTheme.brandPrimary : AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: on ? FontWeight.w600 : FontWeight.w400)),
    );
  }

  Widget _percentBtn(int pct,
      {required String currency,
      required double available,
      required double sellMax}) {
    return GestureDetector(
      onTap: () {
        final market = context.read<MarketProvider>();
        final quote =
            market.quotes.where((q) => q.symbol == _symbol).firstOrNull;
        if (quote == null) return;
        double qty;
        if (_buy) {
          final price = _limit
              ? (double.tryParse(_priceC.text) ?? quote.price)
              : quote.price;
          qty = available * pct / 100 / price;
        } else {
          qty = sellMax * pct / 100;
        }
        _amountC.text = trimQty(qty);
      },
      child: Container(
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF23282F),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('$pct%',
            style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontFamily: 'RobotoMono')),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final amount = double.tryParse(_amountC.text);
    if (amount == null || amount <= 0) {
      _toast('请填写数量', AppTheme.bear);
      return;
    }
    double? price;
    if (_limit) {
      price = double.tryParse(_priceC.text);
      if (price == null || price <= 0) {
        _toast('请填写限价', AppTheme.bear);
        return;
      }
    }
    setState(() => _submitting = true);
    final err = await context.read<PositionProvider>().placeOrder(
          symbol: _symbol,
          side: _buy ? 'buy' : 'sell',
          orderType: _limit ? 'limit' : 'market',
          price: price,
          amount: amount,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (err != null) {
      _toast(err, AppTheme.bear);
    } else {
      _amountC.clear();
      _toast(_limit ? '限价委托已提交' : '下单成功', AppTheme.bull);
    }
  }

  void _toast(String msg, Color color) {
    // 空消息不弹(异常路径可能返回空串,否则呈现为无字空盒)
    if (msg.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 14)),
      backgroundColor: color,
      duration: const Duration(seconds: 2),
    ));
  }

  void _showSymbolPicker(BuildContext context) {
    final all = context.read<MarketProvider>().quotes;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181A20),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.9,
        builder: (c, scrollC) => ListView(
          controller: scrollC,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const Center(
              child: SizedBox(
                  width: 40,
                  child: Divider(thickness: 3, color: Color(0xFF5E6673))),
            ),
            const SizedBox(height: 12),
            const Text('选择交易对',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            const Text('加密货币',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 4),
            ...all.where((q) => q.market == 'crypto').map((q) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(q.symbol,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 15)),
                  subtitle: Text(q.name, style: const TextStyle(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(c);
                    _switchSymbol(q.symbol);
                  },
                )),
            const SizedBox(height: 8),
            const Text('A股',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 4),
            ...all.where((q) => q.market == 'a-share').map((q) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(q.symbol,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 15)),
                  subtitle: Text(q.name, style: const TextStyle(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(c);
                    _switchSymbol(q.symbol);
                  },
                )),
          ],
        ),
      ),
    );
  }

  static String _coin(String s) => s.contains('/') ? s.split('/').first : s;

  static String trimQty(double v) {
    if (v >= 1) {
      return v
          .toStringAsFixed(4)
          .replaceAll(RegExp(r'0+$'), '')
          .replaceAll(RegExp(r'\.$'), '');
    }
    return v
        .toStringAsFixed(6)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }
}

/// 买卖盘卡片(3 卖盘 + 现价行 + 3 买盘)
class _OrderBook extends StatelessWidget {
  final Map<String, List<List<double>>>? depth;
  final double lastPrice;
  final String coin;
  final bool up;
  const _OrderBook(
      {this.depth,
      required this.lastPrice,
      required this.coin,
      required this.up});

  @override
  Widget build(BuildContext context) {
    final d = depth;
    final asks = d?['asks']?.take(3).toList() ?? [];
    final bids = d?['bids']?.take(3).toList() ?? [];
    double maxN = 1;
    for (final r in [...asks, ...bids]) {
      maxN = mathMax(maxN, r[0] * r[1]);
    }
    final priceColor = up ? AppTheme.bull : AppTheme.bear;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF181A20),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppTheme.divider, width: 0.5),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const Text('价格(USDT)',
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const Spacer(),
                Text('数量($coin)',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          // asks 按参考稿卖盘在上(价高在顶)
          for (var i = asks.length - 1; i >= 0; i--)
            _bookRow(asks[i], AppTheme.bear, maxN),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Text(priceOf(lastPrice),
                    style: TextStyle(
                        color: priceColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'RobotoMono')),
                Icon(up ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                    size: 16, color: priceColor),
              ],
            ),
          ),
          for (final r in bids) _bookRow(r, AppTheme.bull, maxN),
        ],
      ),
    );
  }

  Widget _bookRow(List<double> r, Color color, double maxN) {
    final ratio = (r[0] * r[1]) / maxN;
    return SizedBox(
      height: 20,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: ratio.clamp(0.02, 1),
              child: Container(color: color.withValues(alpha: 0.12)),
            ),
          ),
          Row(
            children: [
              Text(priceOf(r[0]),
                  style: TextStyle(
                      color: color, fontSize: 12, fontFamily: 'RobotoMono')),
              const Spacer(),
              Text(trimAmt(r[1]),
                  style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontFamily: 'RobotoMono')),
            ],
          ),
        ],
      ),
    );
  }

  static double mathMax(double a, double b) => a > b ? a : b;
  static String trimAmt(double v) => v
      .toStringAsFixed(3)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

/// 行情类型判定小工具
class RealMarket {
  static bool isCrypto(String symbol) => symbol.contains('/');
}
