import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';

/// 资金记录:充值/提现流水(数据源 GET /wallet/transactions)
class WalletRecordsPage extends StatefulWidget {
  const WalletRecordsPage({super.key});

  @override
  State<WalletRecordsPage> createState() => _WalletRecordsPageState();
}

class _WalletRecordsPageState extends State<WalletRecordsPage> {
  String _currency = 'USDT';
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;
  final _scroll = ScrollController();
  int _page = 0;
  bool _hasMore = true;
  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _load();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 100 &&
        !_loading && _hasMore) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 0;
      _hasMore = true;
      _rows = [];
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient().dio.get('/wallet/transactions',
          queryParameters: {
            'currency': _currency,
            'page': _page,
            'size': _pageSize,
          });
      final list = res.data['data'] as List;
      final newRows = list
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      setState(() {
        _rows.addAll(newRows);
        _hasMore = newRows.length >= _pageSize;
        _page++;
        _loading = false;
      });
    } on DioException catch (e) {
      _error = e.response?.data?['message']?.toString() ?? '加载失败,请稍后重试';
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('资金记录')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                for (final c in const ['USDT', 'CNY'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        if (_currency != c) {
                          _currency = c;
                          _load();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: _currency == c
                              ? AppTheme.brandPrimary.withValues(alpha: 0.15)
                              : const Color(0xFF23282F),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: _currency == c
                                  ? AppTheme.brandPrimary
                                  : Colors.transparent),
                        ),
                        child: Text(c,
                            style: TextStyle(
                                color: _currency == c
                                    ? AppTheme.brandPrimary
                                    : AppTheme.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.brandPrimary));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!,
                style:
                    const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_rows.isEmpty) {
      return const Center(
          child: Text('暂无资金记录',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
        itemCount: _rows.length + (_hasMore ? 1 : 0),
        itemBuilder: (c, i) {
          if (i >= _rows.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.textSecondary)),
            );
          }
          return _row(_rows[i]);
        },
      ),
    );
  }

  Widget _row(Map<String, dynamic> t) {
    final isDeposit = t['type'] == 'deposit';
    final color = isDeposit ? AppTheme.bull : AppTheme.bear;
    final amount = (t['amount'] as num).toDouble();
    final channel = (t['channel'] ?? '').toString();
    final address = (t['address'] ?? '').toString();
    final symbol = _currency == 'CNY' ? '¥' : '\$';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF181A20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(isDeposit ? Icons.south_west : Icons.north_east,
              size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isDeposit ? '充值' : '提现',
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                    [
                      if (channel.isNotEmpty) channel,
                      if (address.isNotEmpty) _shortAddr(address),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${isDeposit ? '+' : '-'}$symbol${moneyFmt(amount)}',
                  style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'RobotoMono')),
              const SizedBox(height: 2),
              Text(_fmtTime(t['created_at']),
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  static String _shortAddr(String a) =>
      a.length <= 12 ? a : '${a.substring(0, 6)}...${a.substring(a.length - 4)}';

  static String _fmtTime(Object? v) {
    final s = (v ?? '').toString().replaceAll('T', ' ');
    return s.length >= 16 ? s.substring(5, 16) : s;
  }
}
