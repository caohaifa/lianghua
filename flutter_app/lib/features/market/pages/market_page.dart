import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../providers/favorites_provider.dart';
import '../providers/market_provider.dart';

/// 行情首页(参考稿 home):标题 + 搜索 + 市场总览 + 筛选 + 币种列表
class MarketPage extends StatefulWidget {
  const MarketPage({super.key});

  @override
  State<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends State<MarketPage> {
  static const _chips = ['全部', '涨幅榜', '热门', '自选', 'A股'];
  int _chip = 0;
  String _query = '';
  Timer? _debounceTimer;

  @override
  Widget build(BuildContext context) {
    final market = context.watch<MarketProvider>();

    if (market.loading && market.quotes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (market.error != null && market.quotes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(market.error!, style: AppTheme.caption),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: market.refresh, child: const Text('重试')),
          ],
        ),
      );
    }

    final favs = context.watch<FavoritesProvider>();
    final all = market.quotes;
    final crypto = all.where((q) => q.market == 'crypto').toList();

    var rows = <Quote>[];
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      rows = all
          .where((e) =>
              e.symbol.toLowerCase().contains(q) ||
              e.name.toLowerCase().contains(q))
          .toList();
    } else {
      switch (_chip) {
        case 1:
          rows = [...crypto]..sort((a, b) => b.change.compareTo(a.change));
        case 2:
          rows = [...crypto]..sort((a, b) => b.quoteVol.compareTo(a.quoteVol));
        case 3:
          rows = all.where((q) => favs.isFav(q.symbol)).toList();
        case 4:
          rows = all.where((q) => q.market == 'a-share').toList()
            ..sort((a, b) => b.quoteVol.compareTo(a.quoteVol));
        default:
          rows = [...crypto]..sort((a, b) => b.quoteVol.compareTo(a.quoteVol));
      }
    }

    return RefreshIndicator(
      onRefresh: market.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          SafeArea(bottom: false, child: _titleRow(context)),
          const SizedBox(height: 10),
          _searchField(),
          const SizedBox(height: 14),
          _overviewCard(market),
          const SizedBox(height: 14),
          _chipRow(),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 6),
            child: Text(_sectionTitle(),
                style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Center(child: Text(_emptyText(), style: AppTheme.caption)),
            )
          else
            ...rows.map((q) => _CoinRow(quote: q)),
        ],
      ),
    );
  }

  String _sectionTitle() {
    if (_query.isNotEmpty) return '搜索结果';
    return switch (_chip) {
      1 => '24h 涨幅榜',
      2 => '热门币种(按成交额)',
      3 => '我的自选',
      4 => 'A股行情(按成交额)',
      _ => '24h 涨幅榜',
    };
  }

  String _emptyText() => switch (_chip) {
        3 => '暂无自选,可在币种详情页点星标添加',
        _ => '没有符合条件的标的',
      };

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Widget _titleRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          const Text('行情',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          IconButton(
            onPressed: () => context.push('/announcements'),
            icon: const Icon(Icons.notifications_none,
                color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return SizedBox(
      height: 40,
      child: TextField(
        onChanged: (v) {
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(milliseconds: 300), () {
            setState(() => _query = v.trim());
          });
        },
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: '搜索币种 / 股票代码',
          prefixIcon: const Icon(Icons.search, size: 20),
          filled: true,
          fillColor: const Color(0xFF181A20),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _overviewCard(MarketProvider market) {
    final o = market.overview;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E2329), Color(0xFF181A20)],
        ),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppTheme.divider, width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _ovItem(
                  '总市值',
                  o == null
                      ? '--'
                      : '\$${compactFmt((o['total_market_cap'] as num).toDouble())}'),
              _ovItem(
                  '24h 成交量',
                  o == null
                      ? '--'
                      : '\$${compactFmt((o['total_24h_volume'] as num).toDouble())}',
                  alignEnd: true),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _ovItem('BTC 占比', o == null ? '--' : '${o['btc_dominance']}%'),
              _ovItem('加密标的', o == null ? '--' : '${o['active_cryptos']} 个',
                  alignEnd: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ovItem(String label, String value, {bool alignEnd = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'RobotoMono')),
        ],
      ),
    );
  }

  Widget _chipRow() {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (c, i) {
          final on = i == _chip;
          return GestureDetector(
            onTap: () => setState(() {
              _chip = i;
              _query = '';
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? AppTheme.brandPrimary : const Color(0xFF181A20),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: on ? AppTheme.brandPrimary : AppTheme.divider),
              ),
              child: Text(_chips[i],
                  style: TextStyle(
                      color: on ? AppTheme.onBrand : AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: on ? FontWeight.w600 : FontWeight.w400)),
            ),
          );
        },
      ),
    );
  }
}

/// 币种行(参考稿 coin-row):彩色圆点 + 代码/名称 + 价格/涨跌幅
class _CoinRow extends StatelessWidget {
  final Quote quote;
  const _CoinRow({required this.quote});

  @override
  Widget build(BuildContext context) {
    final isCrypto = quote.market == 'crypto';
    final isUp = quote.change >= 0;
    final color = isCrypto
        ? (isUp ? AppTheme.bull : AppTheme.bear)
        : (isUp ? AppTheme.bear : AppTheme.bull);
    final colorHex = context.read<MarketProvider>().meta[quote.symbol];

    return InkWell(
      onTap: () => context.push('/market/detail', extra: quote.symbol),
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: const BoxDecoration(
          border:
              Border(bottom: BorderSide(color: Color(0x222B3139), width: 0.5)),
        ),
        child: Row(
          children: [
            _CoinDot(symbol: quote.symbol, colorHex: colorHex, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_code(quote.symbol),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(quote.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(priceText(quote),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'RobotoMono')),
                const SizedBox(height: 2),
                Text('${isUp ? '+' : ''}${quote.change.toStringAsFixed(2)}%',
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'RobotoMono')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// BTC/USDT → BTC;A股代码原样
  static String _code(String symbol) =>
      symbol.contains('/') ? symbol.split('/').first : symbol;
}

/// 彩色圆点(有品牌色用品牌色,否则首字符占位)
class _CoinDot extends StatelessWidget {
  final String symbol;
  final String? colorHex;
  final double size;
  const _CoinDot({required this.symbol, this.colorHex, this.size = 26});

  @override
  Widget build(BuildContext context) {
    final code = symbol.contains('/') ? symbol.split('/').first : symbol;
    final hex = colorHex;
    if (hex != null) {
      final c = Color(int.parse('FF${hex.substring(1)}', radix: 16));
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        child: Text(code.substring(0, 1),
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: size * 0.42,
                fontWeight: FontWeight.w700)),
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration:
          const BoxDecoration(color: Color(0xFF2B3139), shape: BoxShape.circle),
      child: Text(code.substring(0, 1),
          style: const TextStyle(
              color: AppTheme.brandPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700)),
    );
  }
}
