import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../widgets/wallet_sheet.dart';
import '../widgets/transfer_sheet.dart';
import '../../market/providers/market_provider.dart';
import '../../position/providers/position_provider.dart';

/// 资产详情(参考稿 assets-detail):持仓估值 + 明细 + 最近记录
class AssetDetailPage extends StatefulWidget {
  final String symbol;
  const AssetDetailPage({super.key, required this.symbol});

  @override
  State<AssetDetailPage> createState() => _AssetDetailPageState();
}

class _AssetDetailPageState extends State<AssetDetailPage> {
  @override
  void initState() {
    super.initState();
    // 每次进入都静默刷新,保证持仓/记录不陈旧
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PositionProvider>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PositionProvider>();
    final market = context.watch<MarketProvider>();
    final symbol = widget.symbol;

    final quote = market.quotes.where((q) => q.symbol == symbol).firstOrNull;
    final holding = pos.positions.where((p) => p.symbol == symbol).firstOrNull;
    final amount = holding?.amount ?? 0;
    final price = quote?.price ?? holding?.currentPrice ?? 0;
    final value = amount * price;
    final pnl = holding?.pnl ?? 0;
    final coin = symbol.split('/').first;
    final colorHex = market.meta[symbol] ?? '#F7931A';
    final dotColor = Color(int.parse('FF${colorHex.substring(1)}', radix: 16));
    final records =
        pos.orders.where((o) => o.symbol == symbol).take(20).toList();

    return Scaffold(
      appBar: AppBar(title: Text('$coin 资产详情')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration:
                    BoxDecoration(color: dotColor, shape: BoxShape.circle),
                child: Text(coin.substring(0, 1),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 17)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(coin,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w700)),
                  Text(quote?.name ?? coin,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF181A20),
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              border: Border.all(color: AppTheme.divider, width: 0.5),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _v('持仓数量', '${amountFmt(amount)} $coin'),
                    _v('持仓市值', '\$${moneyFmt(value)}', end: true),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _v('最新价格', '\$${priceOf(price)}'),
                    _v('浮动盈亏', '${pnl >= 0 ? '+' : ''}\$${moneyFmt(pnl.abs())}',
                        color: pnl >= 0 ? AppTheme.bull : AppTheme.bear,
                        end: true),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                  child:
                      _action('充值', Icons.add, () => _openWallet('deposit'))),
              const SizedBox(width: 10),
              Expanded(
                  child: _action(
                      '提现', Icons.remove, () => _openWallet('withdraw'))),
              const SizedBox(width: 10),
              Expanded(child: _action('划转', Icons.swap_horiz, _openTransfer)),
            ],
          ),
          const SizedBox(height: 20),
          const Text('最近记录',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (records.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                  child: Text('暂无该币种的成交记录',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13))),
            )
          else
            ...records.map((o) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF181A20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                          o.side == 'buy' ? Icons.south_west : Icons.north_east,
                          size: 16,
                          color:
                              o.side == 'buy' ? AppTheme.bull : AppTheme.bear),
                      const SizedBox(width: 10),
                      Text(
                          '${o.side == 'buy' ? '买入' : '卖出'} ${o.orderType == 'market' ? '市价' : '限价'}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13)),
                      const Spacer(),
                      Text('${o.filledAmount} $coin',
                          style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              fontFamily: 'RobotoMono')),
                      const SizedBox(width: 10),
                      Text(o.createdAt.substring(5, 16),
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 11)),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Widget _v(String label, String value, {Color? color, bool end = false}) {
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
                  color: color ?? Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'RobotoMono')),
        ],
      ),
    );
  }

  Widget _action(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF181A20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: AppTheme.brandPrimary),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  void _openWallet(String type) {
    // 资产详情页统一操作 USDT 钱包(计价币种);币种持仓本身通过交易获得
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181A20),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (c) => WalletSheet(
        type: type,
        currency: 'USDT',
        coin: 'USDT',
        onDone: () => context.read<PositionProvider>().loadAll(),
      ),
    );
  }

  /// 划转成功刷新现货账户(余额已变动)
  void _openTransfer() {
    TransferSheet.show(context,
        onDone: () => context.read<PositionProvider>().loadAll());
  }
}
