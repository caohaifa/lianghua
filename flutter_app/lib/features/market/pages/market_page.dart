import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/finance_card.dart';
import '../providers/market_provider.dart';
import '../widgets/data_source_badge.dart';

class MarketPage extends StatelessWidget {
  const MarketPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('行情'),
        actions: [
          IconButton(
              onPressed: () => showSearch(
                  context: context, delegate: _QuoteSearchDelegate()),
              icon: const Icon(Icons.search, color: AppTheme.textSecondary)),
          IconButton(
              onPressed: () => context.push('/announcements'),
              icon: const Icon(Icons.notifications_none,
                  color: AppTheme.textSecondary)),
        ],
      ),
      body: const _MarketBody(),
    );
  }
}

/// 标的搜索:按代码/名称过滤,点结果进详情
class _QuoteSearchDelegate extends SearchDelegate<String> {
  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear)),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
      onPressed: () => close(context, ''), icon: const Icon(Icons.arrow_back));

  @override
  Widget buildResults(BuildContext context) => _list(context);

  @override
  Widget buildSuggestions(BuildContext context) => _list(context);

  Widget _list(BuildContext context) {
    final quotes = context.read<MarketProvider>().quotes;
    final q = query.toLowerCase();
    final hits = quotes
        .where((e) =>
            e.symbol.toLowerCase().contains(q) ||
            e.name.toLowerCase().contains(q))
        .toList();
    return ListView.builder(
      itemCount: hits.length,
      itemBuilder: (c, i) => ListTile(
        title: Text(hits[i].symbol),
        subtitle: Text(hits[i].name),
        onTap: () {
          close(context, hits[i].symbol);
          context.push('/market/detail', extra: hits[i].symbol);
        },
      ),
    );
  }
}

class _MarketBody extends StatelessWidget {
  const _MarketBody();

  @override
  Widget build(BuildContext context) {
    final market = context.watch<MarketProvider>();

    // 首屏加载
    if (market.loading && market.quotes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    // 加载失败且无缓存数据
    if (market.error != null && market.quotes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(market.error!, style: AppTheme.caption),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: market.refresh,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    final all = market.quotes;
    final crypto = all.where((q) => q.market == 'crypto').toList();
    final aShare = all.where((q) => q.market == 'a-share').toList();

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: '自选'),
              Tab(text: '加密'),
              Tab(text: 'A股'),
            ],
            labelColor: AppTheme.brandPrimary,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.brandPrimary,
            indicatorSize: TabBarIndicatorSize.label,
            indicatorWeight: 3,
          ),
          Expanded(
            child: TabBarView(
              children: [
                _QuoteList(quotes: all, onRefresh: market.refresh),
                _QuoteList(quotes: crypto, onRefresh: market.refresh),
                _QuoteList(quotes: aShare, onRefresh: market.refresh),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteList extends StatelessWidget {
  final List<Quote> quotes;
  final Future<void> Function() onRefresh;
  const _QuoteList({required this.quotes, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTheme.pagePadding),
        itemCount: quotes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (c, i) => _QuoteTile(quote: quotes[i]),
      ),
    );
  }
}

class _QuoteTile extends StatelessWidget {
  final Quote quote;
  const _QuoteTile({required this.quote});

  /// 成交量格式化:亿 / 万
  static String _formatVolume(double v) {
    if (v >= 1e8) return '${(v / 1e8).toStringAsFixed(1)}亿';
    if (v >= 1e4) return '${(v / 1e4).toStringAsFixed(1)}万';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final isUp = quote.change >= 0;
    final isCrypto = quote.market == 'crypto';
    // 加密:绿涨红跌 / A股:红涨绿跌
    final color = isCrypto
        ? (isUp ? AppTheme.bull : AppTheme.bear)
        : (isUp ? AppTheme.bear : AppTheme.bull);

    return FinanceCard(
      onTap: () => context.push('/market/detail', extra: quote.symbol),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // 标的信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(quote.symbol, style: AppTheme.title),
                    const SizedBox(width: 8),
                    Text(quote.name, style: AppTheme.caption),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text('成交量 ${_formatVolume(quote.volume)}',
                        style: AppTheme.caption),
                    const SizedBox(width: 8),
                    DataSourceBadge(market: quote.market),
                  ],
                ),
              ],
            ),
          ),
          // 价格
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                quote.price.toStringAsFixed(2),
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'RobotoMono'),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.tagRadius),
                ),
                child: Text(
                  '${isUp ? '+' : ''}${quote.change.toStringAsFixed(2)}%',
                  style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'RobotoMono'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
