import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/market_provider.dart';

/// 币安式盘口订单簿:asks 倒序(红)在上,中间最新价,bids(绿)在下;
/// 每行以数量占比作右起背景横条。
class OrderBookPanel extends StatelessWidget {
  final List<List<double>> bids; // [[price, qty]] 价降序
  final List<List<double>> asks; // [[price, qty]] 价升序
  final double? lastPrice;
  final Color lastPriceColor;
  final int rows;

  const OrderBookPanel({
    super.key,
    required this.bids,
    required this.asks,
    this.lastPrice,
    this.lastPriceColor = AppTheme.textPrimary,
    this.rows = 10,
  });

  @override
  Widget build(BuildContext context) {
    double maxQty = 0;
    for (final e in bids.take(rows)) {
      if (e[1] > maxQty) maxQty = e[1];
    }
    for (final e in asks.take(rows)) {
      if (e[1] > maxQty) maxQty = e[1];
    }
    if (maxQty <= 0) maxQty = 1;

    // asks 取前 rows 档后倒序展示(最远档在上,最优卖紧贴最新价)
    final askShown = asks.take(rows).toList().reversed.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text('盘口', style: AppTheme.body),
            Spacer(),
            Text('价格', style: AppTheme.caption),
            SizedBox(width: 48),
            Text('数量', style: AppTheme.caption),
          ],
        ),
        const SizedBox(height: 8),
        if (askShown.isEmpty && bids.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text('盘口加载中…', style: AppTheme.caption)),
          )
        else ...[
          ...askShown.map((e) => _BookRow(
                price: e[0],
                qty: e[1],
                maxQty: maxQty,
                color: AppTheme.bear,
              )),
          // 最新价行
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              lastPrice != null ? lastPrice!.toStringAsFixed(2) : '--',
              style: TextStyle(
                color: lastPriceColor,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                fontFamily: 'RobotoMono',
              ),
            ),
          ),
          ...bids.take(rows).map((e) => _BookRow(
                price: e[0],
                qty: e[1],
                maxQty: maxQty,
                color: AppTheme.bull,
              )),
        ],
      ],
    );
  }
}

class _BookRow extends StatelessWidget {
  final double price;
  final double qty;
  final double maxQty;
  final Color color;

  const _BookRow({
    required this.price,
    required this.qty,
    required this.maxQty,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = (qty / maxQty).clamp(0.0, 1.0);
    return SizedBox(
      height: 22,
      child: Stack(
        children: [
          // 量占比背景条(右起)
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: ratio,
                child: Container(color: color.withValues(alpha: 0.12)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    price.toStringAsFixed(2),
                    style: TextStyle(
                        color: color, fontSize: 12, fontFamily: 'RobotoMono'),
                  ),
                ),
                Text(
                  _fmtQty(qty),
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      fontFamily: 'RobotoMono'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtQty(double v) {
    if (v >= 10000) return v.toStringAsFixed(0);
    if (v >= 100) return v.toStringAsFixed(2);
    if (v >= 1) return v.toStringAsFixed(4);
    return v.toStringAsFixed(5);
  }
}

/// 最新成交流水:价格(红绿)/数量/时间,isBuyerMaker=true 为主动卖出显红
class RecentTradesPanel extends StatelessWidget {
  final List<TradeTick> trades;
  final int rows;

  const RecentTradesPanel({super.key, required this.trades, this.rows = 16});

  @override
  Widget build(BuildContext context) {
    final shown = trades.take(rows).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text('最新成交', style: AppTheme.body),
            Spacer(),
            Text('价格', style: AppTheme.caption),
            SizedBox(width: 48),
            Text('数量', style: AppTheme.caption),
            SizedBox(width: 48),
            Text('时间', style: AppTheme.caption),
          ],
        ),
        const SizedBox(height: 8),
        if (shown.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text('成交加载中…', style: AppTheme.caption)),
          )
        else
          ...shown.map((t) {
            final color = t.isBuyerMaker ? AppTheme.bear : AppTheme.bull;
            final dt =
                DateTime.fromMillisecondsSinceEpoch(t.time).toLocal();
            final hh = dt.hour.toString().padLeft(2, '0');
            final mm = dt.minute.toString().padLeft(2, '0');
            final ss = dt.second.toString().padLeft(2, '0');
            return SizedBox(
              height: 22,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      t.price.toStringAsFixed(2),
                      style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontFamily: 'RobotoMono'),
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(
                      _fmtQty(t.qty),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                          fontFamily: 'RobotoMono'),
                    ),
                  ),
                  SizedBox(
                    width: 76,
                    child: Text(
                      '$hh:$mm:$ss',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontFamily: 'RobotoMono'),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  static String _fmtQty(double v) {
    if (v >= 10000) return v.toStringAsFixed(0);
    if (v >= 100) return v.toStringAsFixed(2);
    if (v >= 1) return v.toStringAsFixed(4);
    return v.toStringAsFixed(5);
  }
}
