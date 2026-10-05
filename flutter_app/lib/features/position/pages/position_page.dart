import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/finance_card.dart';
import '../../../core/ui/pnl_number.dart';
import '../providers/position_provider.dart';
import '../widgets/order_sheet.dart';

class PositionPage extends StatefulWidget {
  const PositionPage({super.key});

  @override
  State<PositionPage> createState() => _PositionPageState();
}

class _PositionPageState extends State<PositionPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<PositionProvider>().loadAll());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PositionProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('持仓'),
        actions: [
          IconButton(
            onPressed: () => showOrderSheet(context),
            icon: const Icon(Icons.add_circle_outline,
                color: AppTheme.brandPrimary),
            tooltip: '下单',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: provider.loadAll,
        child: _buildBody(provider),
      ),
    );
  }

  Widget _buildBody(PositionProvider provider) {
    if (provider.loading && provider.account == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.error != null && provider.account == null) {
      return ListView(children: [
        const SizedBox(height: 120),
        Center(child: Text(provider.error!, style: AppTheme.caption)),
        const SizedBox(height: 12),
        Center(
          child: OutlinedButton(
              onPressed: provider.loadAll, child: const Text('重试')),
        ),
      ]);
    }
    final account = provider.account;
    if (account == null) {
      return ListView(children: const [
        SizedBox(height: 120),
        Center(child: Text('暂无账户数据', style: AppTheme.caption)),
      ]);
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppTheme.pagePadding),
      children: [
        // 账户总览卡片(USDT 主钱包 + CNY 钱包)
        _AccountCard(account: account),
        if (provider.cnyAccount != null) ...[
          const SizedBox(height: 12),
          _AccountCard(account: provider.cnyAccount!),
        ],
        const SizedBox(height: 16),
        // 持仓列表
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('持仓明细 (${provider.positions.length})',
                style: AppTheme.headline),
            TextButton(
                onPressed: () => context.push('/position/orders'),
                child: const Text('委托记录')),
          ],
        ),
        const SizedBox(height: 8),
        if (provider.positions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child:
                Center(child: Text('暂无持仓,点右上角 + 下单', style: AppTheme.caption)),
          )
        else
          ...provider.positions.map((p) => _PositionTile(position: p)),
      ],
    );
  }
}

/// 单币种账户总览卡片(USDT / CNY 复用同一布局)
class _AccountCard extends StatelessWidget {
  final AccountOverview account;
  const _AccountCard({required this.account});

  @override
  Widget build(BuildContext context) {
    return FinanceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text('账户总资产 (${account.currency})', style: AppTheme.caption),
          const SizedBox(height: 4),
          Text(
            account.totalAsset.toStringAsFixed(2),
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                fontFamily: 'RobotoMono'),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('浮动盈亏 ', style: AppTheme.caption),
              PnlNumber(value: account.totalPnlPct, isPercentage: true),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppTheme.divider, height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _InfoCell(
                      label: '持仓市值',
                      value: account.positionValue.toStringAsFixed(0))),
              Expanded(
                  child: _InfoCell(
                      label: '可用资金',
                      value: account.available.toStringAsFixed(0))),
              Expanded(
                  child: _InfoCell(
                      label: '累计盈亏',
                      value:
                          '${account.totalPnl >= 0 ? '+' : ''}${account.totalPnl.toStringAsFixed(0)}',
                      valueColor: account.totalPnl >= 0
                          ? AppTheme.bull
                          : AppTheme.bear)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PositionTile extends StatelessWidget {
  final PositionItem position;
  const _PositionTile({required this.position});

  @override
  Widget build(BuildContext context) {
    final p = position;
    final isLong = p.side == 'long';
    final sideColor = isLong ? AppTheme.bull : AppTheme.bear;

    return FinanceCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Text(p.symbol, style: AppTheme.title),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: sideColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.tagRadius),
                ),
                child: Text(isLong ? '多' : '空',
                    style: TextStyle(color: sideColor, fontSize: 12)),
              ),
              if (p.strategyName != null) ...[
                const SizedBox(width: 8),
                Text(p.strategyName!, style: AppTheme.caption),
              ],
              const Spacer(),
              PnlNumber(value: p.pnlPct, isPercentage: true),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _InfoCell(label: '数量', value: p.amount.toStringAsFixed(4)),
              _InfoCell(label: '开仓价', value: p.entryPrice.toStringAsFixed(2)),
              _InfoCell(label: '现价', value: p.currentPrice.toStringAsFixed(2)),
              _InfoCell(
                  label: '盈亏',
                  value: '${p.pnl >= 0 ? '+' : ''}${p.pnl.toStringAsFixed(2)}',
                  valueColor: p.pnl >= 0 ? AppTheme.bull : AppTheme.bear),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoCell extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoCell({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.caption),
        Text(
          value,
          style: TextStyle(
              color: valueColor ?? AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              fontFamily: 'RobotoMono'),
        ),
      ],
    );
  }
}
