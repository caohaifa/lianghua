import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/finance_card.dart';
import '../../../core/utils/format.dart';

/// 团队管理:团队人数 / 交易总金额 / 成员明细 / 交易流水(详细资金管理)
/// (数据源 GET /referral/team)
class TeamPage extends StatefulWidget {
  const TeamPage({super.key});

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  bool _showMembers = true; // true=团队成员 false=交易流水

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient().dio.get('/referral/team');
      _data = Map<String, dynamic>.from(res.data['data'] as Map);
    } on DioException catch (e) {
      _error = e.response?.data?['message']?.toString() ?? '加载失败,请稍后重试';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _teamCount => ((_data?['team_count'] ?? 0) as num).toInt();
  int get _activeCount => ((_data?['active_count'] ?? 0) as num).toInt();
  double get _volUsdt => ((_data?['total_volume_usdt'] ?? 0) as num).toDouble();
  double get _volCny => ((_data?['total_volume_cny'] ?? 0) as num).toDouble();
  double get _rewUsdt => ((_data?['total_reward_usdt'] ?? 0) as num).toDouble();
  double get _rewCny => ((_data?['total_reward_cny'] ?? 0) as num).toDouble();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('团队管理')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.brandPrimary))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13)),
                      const SizedBox(height: 12),
                      OutlinedButton(onPressed: _load, child: const Text('重试')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      _summaryCard(),
                      const SizedBox(height: 16),
                      _toggle(),
                      const SizedBox(height: 12),
                      ...(_showMembers ? _memberRows() : _flowRows()),
                    ],
                  ),
                ),
    );
  }

  /// 团队资金总览卡
  Widget _summaryCard() {
    return FinanceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('团队人数', style: AppTheme.caption),
                  const SizedBox(height: 6),
                  Text('$_teamCount',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'RobotoMono')),
                ],
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('活跃成员 $_activeCount 人',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFF23282F)),
          Row(
            children: [
              Expanded(
                  child: _stat('交易总金额 (USDT)', _volUsdt, Colors.white)),
              Expanded(child: _stat('交易总金额 (CNY)', _volCny, Colors.white)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _stat('累计返佣 (USDT)', _rewUsdt, AppTheme.bull)),
              Expanded(child: _stat('累计返佣 (CNY)', _rewCny, AppTheme.bull)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.caption),
        const SizedBox(height: 4),
        Text(value >= 10000 ? compactFmt(value) : moneyFmt(value),
            style: TextStyle(
                color: color,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                fontFamily: 'RobotoMono')),
      ],
    );
  }

  /// 成员/流水切换
  Widget _toggle() {
    return Row(
      children: [
        _chip('团队成员 ($_teamCount)', _showMembers, () => setState(() => _showMembers = true)),
        const SizedBox(width: 8),
        _chip('交易流水', !_showMembers, () => setState(() => _showMembers = false)),
      ],
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.brandPrimary.withValues(alpha: 0.15)
              : const Color(0xFF23282F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: active ? AppTheme.brandPrimary : Colors.transparent),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? AppTheme.brandPrimary : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  List<Widget> _memberRows() {
    final rows = (_data?['members'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    if (rows.isEmpty) {
      return [_empty('暂无团队成员,快去邀请好友吧')];
    }
    return [for (final m in rows) Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _memberRow(m),
    )];
  }

  Widget _memberRow(Map<String, dynamic> m) {
    final nickname = (m['nickname'] ?? '').toString();
    final phone = (m['phone'] ?? '').toString();
    final title = nickname.isNotEmpty ? nickname : (phone.isNotEmpty ? phone : (m['trader'] ?? '').toString());
    final joined = _fmtTime(m['joined_at']);
    final tradeCount = (m['trade_count'] ?? 0).toString();
    final volUsdt = (m['volume_usdt'] as num).toDouble();
    final volCny = (m['volume_cny'] as num).toDouble();
    final rewUsdt = (m['reward_usdt'] as num).toDouble();
    final rewCny = (m['reward_cny'] as num).toDouble();
    final hasUsdt = volUsdt > 0 || rewUsdt > 0;
    final volSym = hasUsdt ? '\$' : '¥';
    final vol = hasUsdt ? volUsdt : volCny;
    final rew = hasUsdt ? rewUsdt : rewCny;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF181A20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.brandPrimary,
            child: Text(title[0].toUpperCase(),
                style: const TextStyle(
                    color: AppTheme.onBrand,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
                const SizedBox(height: 2),
                Text('加入于 $joined · 交易 $tradeCount 笔',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(vol > 0 ? '流水 $volSym${moneyFmt(vol)}' : '暂无交易',
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
              const SizedBox(height: 2),
              Text('返佣 +$volSym${moneyFmt(rew)}',
                  style: const TextStyle(
                      color: AppTheme.bull,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'RobotoMono')),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _flowRows() {
    final rows = (_data?['flows'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    if (rows.isEmpty) {
      return [_empty('团队暂无交易流水')];
    }
    return [for (final f in rows) Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _flowRow(f),
    )];
  }

  Widget _flowRow(Map<String, dynamic> t) {
    final currency = (t['currency'] ?? 'USDT').toString();
    final reward = (t['reward'] as num).toDouble();
    final volume = (t['volume'] as num).toDouble();
    final symbol = currency == 'CNY' ? '¥' : '\$';
    final trader = (t['trader'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF181A20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.swap_horiz, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((t['symbol'] ?? '').toString(),
                    style:
                        const TextStyle(color: Colors.white, fontSize: 13)),
                const SizedBox(height: 2),
                Text('成员 $trader · 成交额 $symbol${moneyFmt(volume)}',
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
              Text('+$symbol${moneyFmt(reward)}',
                  style: const TextStyle(
                      color: AppTheme.bull,
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

  Widget _empty(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      child: Text(text,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
    );
  }

  static String _fmtTime(Object? v) {
    final s = (v ?? '').toString().replaceAll('T', ' ');
    return s.length >= 16 ? s.substring(5, 16) : s;
  }
}
