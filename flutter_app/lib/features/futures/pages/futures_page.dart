import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../market/providers/favorites_provider.dart';
import '../../market/providers/market_provider.dart';
import '../../assets/widgets/transfer_sheet.dart';
import '../providers/futures_provider.dart';

/// 合约主页(参考稿 futures):账户卡 + 持仓 + 开多/开空
class FuturesPage extends StatefulWidget {
  const FuturesPage({super.key});

  @override
  State<FuturesPage> createState() => _FuturesPageState();
}

class _FuturesPageState extends State<FuturesPage> {
  String _symbol = 'BTC/USDT';
  int _leverage = 20;

  @override
  Widget build(BuildContext context) {
    final market = context.watch<MarketProvider>();
    final futures = context.watch<FuturesProvider>();
    final quote = market.quotes.where((q) => q.symbol == _symbol).firstOrNull;

    if (quote == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final up = quote.change >= 0;
    final priceColor = up ? AppTheme.bull : AppTheme.bear;
    final acc = futures.account;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      children: [
        SafeArea(bottom: false, child: _header(context)),
        const SizedBox(height: 10),
        Text(priceText(quote),
            style: TextStyle(
                color: priceColor,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                fontFamily: 'RobotoMono')),
        const SizedBox(height: 4),
        Text('${up ? '+' : ''}${quote.change.toStringAsFixed(2)}%',
            style: TextStyle(
                color: priceColor, fontSize: 13, fontFamily: 'RobotoMono')),
        const SizedBox(height: 14),
        _accountCard(acc),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 8),
          child: Text('当前持仓',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
        ),
        if (futures.positions.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 26),
            alignment: Alignment.center,
            child: const Text('暂无持仓,可通过下方按钮开仓',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          )
        else
          ...futures.positions.map((p) => _PositionCard(item: p)),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.bull,
                    foregroundColor: AppTheme.onBrand,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _openSheet('long'),
                  child: const Text('开多',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.bear,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _openSheet('short'),
                  child: const Text('开空',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
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
            onTap: _showSymbolPicker,
            child: Row(
              children: [
                Text('${_coin}USDT 永续',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w700)),
                const Icon(Icons.keyboard_arrow_down, color: Colors.white),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _showLeveragePicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.brandPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('${_leverage}x',
                  style: const TextStyle(
                      color: AppTheme.brandPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const Spacer(),
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

  Widget _accountCard(FuturesAccountView? a) {
    final upnl = a?.unrealizedPnl ?? 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF181A20),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppTheme.divider, width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _v('账户权益', a == null ? '--' : '\$${d2(a.totalEquity)}',
                  Colors.white),
              _v('可用余额', a == null ? '--' : '\$${d2(a.available)}',
                  Colors.white,
                  end: true),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _v('未实现盈亏', '${upnl >= 0 ? '+' : ''}\$${d2(upnl)}',
                  upnl >= 0 ? AppTheme.bull : AppTheme.bear),
              _v('占用保证金', a == null ? '--' : '\$${d2(a.usedMargin)}',
                  Colors.white,
                  end: true),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: _showTransferSheet,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF23282F),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swap_horiz,
                        size: 15, color: AppTheme.brandPrimary),
                    SizedBox(width: 4),
                    Text('资金划转',
                        style: TextStyle(
                            color: AppTheme.brandPrimary, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _v(String label, String value, Color color, {bool end = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment:
            end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'RobotoMono')),
        ],
      ),
    );
  }

  String get _coin =>
      _symbol.contains('/') ? _symbol.split('/').first : _symbol;

  static String d2(double v) {
    final s = v.toStringAsFixed(2);
    final parts = s.split('.');
    final intPart = parts[0];
    final buf = StringBuffer();
    var neg = false;
    var body = intPart;
    if (body.startsWith('-')) {
      neg = true;
      body = body.substring(1);
    }
    for (var i = 0; i < body.length; i++) {
      if (i > 0 && (body.length - i) % 3 == 0) buf.write(',');
      buf.write(body[i]);
    }
    return '${neg ? '-' : ''}${buf.toString()}.${parts[1]}';
  }

  // ─────────────── 弹层 ───────────────

  void _showSymbolPicker() {
    final crypto = context
        .read<MarketProvider>()
        .quotes
        .where((q) => q.market == 'crypto')
        .toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181A20),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          children: [
            const Text('选择合约标的',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...crypto.map((q) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${q.symbol.split('/').first}USDT 永续',
                      style: const TextStyle(color: Colors.white)),
                  subtitle: Text(q.name, style: const TextStyle(fontSize: 12)),
                  onTap: () {
                    setState(() => _symbol = q.symbol);
                    Navigator.pop(c);
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _showLeveragePicker() {
    const opts = [1, 2, 5, 10, 20, 50, 75, 100, 125];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181A20),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('选择杠杆倍数',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final o in opts)
                    GestureDetector(
                      onTap: () {
                        setState(() => _leverage = o);
                        Navigator.pop(c);
                      },
                      child: Container(
                        width: 64,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: o == _leverage
                              ? AppTheme.brandPrimary
                              : const Color(0xFF23282F),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('$o x',
                            style: TextStyle(
                                color: o == _leverage
                                    ? AppTheme.onBrand
                                    : AppTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'RobotoMono')),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSheet(String direction) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181A20),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (c) => SafeArea(
        child: _OpenSheet(
          symbol: _symbol,
          direction: direction,
          leverage: _leverage,
        ),
      ),
    );
  }

  void _showTransferSheet() {
    TransferSheet.show(context);
  }
}

/// 持仓卡片
class _PositionCard extends StatelessWidget {
  final FuturesPositionItem item;
  const _PositionCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final isLong = item.isLong;
    final color = isLong ? AppTheme.bull : AppTheme.bear;
    final pnlColor = item.unrealizedPnl >= 0 ? AppTheme.bull : AppTheme.bear;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF181A20),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                    isLong ? '多仓 ${item.leverage}x' : '空仓 ${item.leverage}x',
                    style: const TextStyle(
                        color: AppTheme.onBrand,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Text(item.symbol,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              GestureDetector(
                onTap: () async {
                  final err = await context
                      .read<FuturesProvider>()
                      .closePosition(item.id);
                  if (err != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(err),
                      backgroundColor: const Color(0xFF1E2329),
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF23282F),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('市价全平',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _i('开仓均价', '\$${priceOf(item.entryPrice)}'),
              _i('标记价格', '\$${priceOf(item.markPrice)}'),
              _i('持仓量', trim0(item.amount)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _i('未实现盈亏',
                  '${item.unrealizedPnl >= 0 ? '+' : ''}\$${d2p(item.unrealizedPnl)}',
                  color: pnlColor),
              _i('收益率', '${item.roePct.toStringAsFixed(2)}%', color: pnlColor),
              _i('强平价', '\$${priceOf(item.liquidationPrice)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _i(String label, String value, {Color? color}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  color: color ?? Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'RobotoMono')),
        ],
      ),
    );
  }

  static String trim0(double v) {
    final s = v.toStringAsFixed(4);
    return s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  static String d2p(double v) => v.abs().toStringAsFixed(2);
}

/// 开仓表单
class _OpenSheet extends StatefulWidget {
  final String symbol;
  final String direction;
  final int leverage;
  const _OpenSheet(
      {required this.symbol, required this.direction, required this.leverage});

  @override
  State<_OpenSheet> createState() => _OpenSheetState();
}

class _OpenSheetState extends State<_OpenSheet> {
  final _c = TextEditingController();
  String? _error;

  @override
  Widget build(BuildContext context) {
    final market = context.watch<MarketProvider>();
    final quote =
        market.quotes.where((q) => q.symbol == widget.symbol).firstOrNull;
    final price = quote?.price ?? 0;
    final amount = double.tryParse(_c.text) ?? 0;
    final notional = amount * price;
    final margin = notional / widget.leverage;
    final isLong = widget.direction == 'long';
    final color = isLong ? AppTheme.bull : AppTheme.bear;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
        child: Column(
          children: [
            Row(
              children: [
                Icon(isLong ? Icons.trending_up : Icons.trending_down,
                    color: color),
                const SizedBox(width: 8),
                Text(isLong ? '开多 ${widget.symbol}' : '开空 ${widget.symbol}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${widget.leverage}x',
                    style: const TextStyle(
                        color: AppTheme.brandPrimary,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'RobotoMono')),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 46,
              child: TextField(
                controller: _c,
                onChanged: (_) => setState(() {}),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(
                    color: Colors.white, fontFamily: 'RobotoMono'),
                decoration: InputDecoration(
                  hintText: '数量(${widget.symbol.split('/').first})',
                  fillColor: const Color(0xFF23282F),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _line('标记价格', '\$${priceOf(price)}'),
            _line('仓位价值', '\$${notional.toStringAsFixed(2)}'),
            _line('占用保证金(预估)', '\$${margin.toStringAsFixed(2)}'),
            _line(
                '手续费(0.045%)', '\$${(notional * 0.00045).toStringAsFixed(3)}'),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppTheme.bear)),
            ],
            const SizedBox(height: 18),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: color),
                onPressed: () async {
                  if (amount <= 0) {
                    setState(() => _error = '请输入数量');
                    return;
                  }
                  final err =
                      await context.read<FuturesProvider>().openPosition(
                            symbol: widget.symbol,
                            direction: widget.direction,
                            leverage: widget.leverage,
                            amount: amount,
                          );
                  if (!context.mounted) return;
                  if (err != null) {
                    setState(() => _error = err);
                  } else {
                    Navigator.pop(context);
                  }
                },
                child: Text(isLong ? '确认开多' : '确认开空',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontFamily: 'RobotoMono')),
        ],
      ),
    );
  }
}
