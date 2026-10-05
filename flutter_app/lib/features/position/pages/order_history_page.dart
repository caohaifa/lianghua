import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/finance_card.dart';
import '../../../core/ui/status_tag.dart';
import '../providers/position_provider.dart';

/// 委托记录(接 /trading/orders,挂单可撤销)
class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<PositionProvider>().loadAll());
  }

  static String _statusLabel(String s) => switch (s) {
        'filled' => '已成交',
        'pending' => '挂单中',
        'cancelled' => '已撤单',
        _ => s,
      };

  static StatusType _statusType(String s) => switch (s) {
        'filled' => StatusType.normal,
        'pending' => StatusType.warning,
        _ => StatusType.normal,
      };

  Future<void> _cancel(OrderItem o) async {
    final err = await context.read<PositionProvider>().cancelOrder(o.orderId);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(err ?? '已撤单')));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PositionProvider>();
    final orders = provider.orders;

    return Scaffold(
      appBar: AppBar(title: const Text('委托记录')),
      body: RefreshIndicator(
        onRefresh: provider.loadAll,
        child: provider.loading && orders.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : orders.isEmpty
                ? ListView(children: const [
                    SizedBox(height: 120),
                    Center(child: Text('暂无委托记录', style: AppTheme.caption)),
                  ])
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppTheme.pagePadding),
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (c, i) => _tile(orders[i]),
                  ),
      ),
    );
  }

  Widget _tile(OrderItem o) {
    final isBuy = o.side == 'buy';
    final sideColor = isBuy ? AppTheme.bull : AppTheme.bear;
    return FinanceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Text(o.symbol, style: AppTheme.title),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: sideColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.tagRadius),
                ),
                child: Text(isBuy ? '买入' : '卖出',
                    style: TextStyle(color: sideColor, fontSize: 12)),
              ),
              const SizedBox(width: 6),
              Text(o.orderType == 'market' ? '市价' : '限价',
                  style: AppTheme.caption),
              const Spacer(),
              StatusTag(
                  label: _statusLabel(o.status), type: _statusType(o.status)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _cell('价格', o.price?.toStringAsFixed(2) ?? '-'),
              _cell('数量', o.amount.toStringAsFixed(4)),
              _cell('成交', o.filledAmount.toStringAsFixed(4)),
              if (o.status == 'pending')
                TextButton(onPressed: () => _cancel(o), child: const Text('撤单'))
              else
                _cell(
                    '时间',
                    o.createdAt.length >= 16
                        ? o.createdAt.substring(5, 16).replaceAll('T', ' ')
                        : o.createdAt),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.caption),
        Text(value,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontFamily: 'RobotoMono')),
      ],
    );
  }
}
