import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../widgets/wallet_sheet.dart';
import '../widgets/transfer_sheet.dart';
import '../../futures/providers/futures_provider.dart';
import '../../market/providers/market_provider.dart';
import '../../position/providers/position_provider.dart';

/// 资产主页(参考稿 assets):总资产 + 充值/提现/划转/交易 + 我的资产
class AssetsPage extends StatefulWidget {
  const AssetsPage({super.key});

  @override
  State<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends State<AssetsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PositionProvider>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PositionProvider>();
    final futures = context.watch<FuturesProvider>();
    final market = context.watch<MarketProvider>();

    final usdt = pos.account;
    final cny = pos.cnyAccount;
    final futuresEquity = futures.account?.totalEquity ?? 0;
    // CNY 资产按行情行情折算为 USDT(用 1 USDT ≈ 7.3 CNY 近似;行情中有 USDT 标的时优先用实时价)
    final cnyInUsdt = cny != null
        ? cny.totalAsset / _cnyPerUsdt(market)
        : 0.0;
    final totalAsset = (usdt?.totalAsset ?? 0) + futuresEquity + cnyInUsdt;
    final pnl = usdt?.totalPnl ?? 0;
    final pnlPct = usdt?.totalPnlPct ?? 0;

    return RefreshIndicator(
      onRefresh: () => Future.wait([
        context.read<PositionProvider>().loadAll(),
        context.read<FuturesProvider>().load(),
      ]),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          SafeArea(bottom: false, child: _titleRow(context)),
          const SizedBox(height: 12),
          _totalCard(totalAsset, pnl, pnlPct),
          const SizedBox(height: 8),
          if (cny != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('A股账户总资产(CNY): ¥${moneyFmt(cny.totalAsset)}',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
            ),
          const SizedBox(height: 14),
          _quickActions(),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 4),
            child: Row(
              children: [
                const Text('我的资产',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                GestureDetector(
                  onTap: () => context.push('/assets/wallet-records'),
                  child: const Text('资金记录 >',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => context.push('/position/orders'),
                  child: const Text('订单记录 >',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                ),
              ],
            ),
          ),
          _assetRows(pos, futuresEquity),
        ],
      ),
    );
  }

  Widget _titleRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const Text('资产',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          GestureDetector(
            onTap: () => context.push('/profile'),
            child: const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF23282F),
              child: Icon(Icons.person_outline,
                  size: 19, color: AppTheme.brandPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalCard(double total, double pnl, double pnlPct) {
    final pnlColor = pnl >= 0 ? AppTheme.bull : AppTheme.bear;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2B2608), Color(0xFF181A20)],
        ),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppTheme.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('总资产估值(USDT,含合约)',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          Text('\$${moneyFmt(total)}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'RobotoMono')),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('浮动盈亏 ',
                  style:
                      TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              Text(
                  '${pnl >= 0 ? '+' : ''}\$${moneyFmt(pnl.abs())} (${pnlPct >= 0 ? '+' : ''}${pnlPct.toStringAsFixed(2)}%)',
                  style: TextStyle(
                      color: pnlColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'RobotoMono')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickActions() {
    final items = [
      (Icons.arrow_downward, '充值', () => _openWallet('deposit')),
      (Icons.arrow_upward, '提现', () => _openWallet('withdraw')),
      (Icons.swap_horiz, '划转', _openTransfer),
      (Icons.sync_alt, '交易', () => context.go('/spot')),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF181A20),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppTheme.divider, width: 0.5),
      ),
      child: Row(
        children: [
          for (final it in items)
            Expanded(
              child: GestureDetector(
                onTap: it.$3,
                child: Column(
                  children: [
                    Icon(it.$1, color: AppTheme.brandPrimary, size: 21),
                    const SizedBox(height: 6),
                    Text(it.$2,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _assetRows(PositionProvider pos, double futuresEquity) {
    final market = context.watch<MarketProvider>();
    final widgets = <Widget>[];

    // USDT 现金
    final usdtBal = pos.account?.available ?? 0;
    widgets.add(_AssetRow(
        code: 'USDT',
        name: 'USDT 现金',
        amount: usdtBal,
        value: usdtBal,
        colorHex: '#26A17B'));
    // 合约权益(独立行)
    if (futuresEquity != 0) {
      widgets.add(_AssetRow(
          code: '合约',
          name: 'USDT 本位永续账户',
          amount: futuresEquity,
          value: futuresEquity,
          colorHex: '#F0B90B',
          noDetail: true));
    }
    // 加密持仓
    for (final p in pos.positions.where((p) => p.symbol.contains('/'))) {
      final q = market.quotes.where((q) => q.symbol == p.symbol).firstOrNull;
      final colorHex = market.meta[p.symbol];
      widgets.add(_AssetRow(
        code: p.symbol.split('/').first,
        name: p.symbol,
        amount: p.amount,
        value: p.amount * (q?.price ?? p.currentPrice),
        colorHex: colorHex,
        detailSymbol: p.symbol,
      ));
    }
    // A股持仓
    final aShares =
        pos.positions.where((p) => !p.symbol.contains('/')).toList();
    if (aShares.isNotEmpty) {
      widgets.add(const Padding(
        padding: EdgeInsets.fromLTRB(4, 14, 4, 6),
        child: Text('A 股持仓(CNY 本位)',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ));
      for (final p in aShares) {
        final q = market.quotes.where((q) => q.symbol == p.symbol).firstOrNull;
        widgets.add(_AssetRow(
          code: p.symbol,
          name: q?.name ?? p.symbol,
          amount: p.amount,
          value: p.amount * (q?.price ?? p.currentPrice),
          colorHex: null,
          cny: true,
        ));
      }
    }
    return Column(children: widgets);
  }

  /// 从行情列表中取 USDT 兑 CNY 价格(若行情中有 USDT/CNY 标的);否则返回默认 7.3
  double _cnyPerUsdt(MarketProvider market) {
    for (final q in market.quotes) {
      if (q.symbol == 'USDT/CNY' && q.price > 0) return q.price;
    }
    return 7.3;
  }

  void _openWallet(String type) {
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

  /// 划转成功同时刷新现货账户(余额已变动)
  void _openTransfer() {
    TransferSheet.show(context,
        onDone: () => context.read<PositionProvider>().loadAll());
  }
}

/// 资产行(参考稿 assets coin-row)
class _AssetRow extends StatelessWidget {
  final String code;
  final String name;
  final double amount;
  final double value;
  final String? colorHex;
  final bool cny;
  final String? detailSymbol;
  final bool noDetail;

  const _AssetRow({
    required this.code,
    required this.name,
    required this.amount,
    required this.value,
    this.colorHex,
    this.cny = false,
    this.detailSymbol,
    this.noDetail = false,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = colorHex == null
        ? const Color(0xFF2B3139)
        : Color(int.parse('FF${colorHex!.substring(1)}', radix: 16));
    return InkWell(
      onTap: noDetail || detailSymbol == null
          ? null
          : () => context.push('/assets/detail', extra: detailSymbol),
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: const BoxDecoration(
          border:
              Border(bottom: BorderSide(color: Color(0x222B3139), width: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration:
                  BoxDecoration(color: dotColor, shape: BoxShape.circle),
              child: Text(code.substring(0, 1),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(code,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                      '${amountFmt(amount)} ${cny ? '股' : code == '合约' ? 'USDT' : code}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Text('${cny ? '¥' : '\$'}${moneyFmt(value)}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'RobotoMono')),
          ],
        ),
      ),
    );
  }
}
