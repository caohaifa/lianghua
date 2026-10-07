import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/finance_card.dart';
import '../../../core/utils/format.dart';

/// 邀请奖励:邀请好友交易,其每笔现货成交流水 1% 自动返佣至推荐人对应钱包
/// (数据源 GET /referral/summary)
class ReferralRewardsPage extends StatefulWidget {
  const ReferralRewardsPage({super.key});

  @override
  State<ReferralRewardsPage> createState() => _ReferralRewardsPageState();
}

class _ReferralRewardsPageState extends State<ReferralRewardsPage> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

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
      final res = await ApiClient().dio.get('/referral/summary');
      _data = Map<String, dynamic>.from(res.data['data'] as Map);
    } on DioException catch (e) {
      _error = e.response?.data?['message']?.toString() ?? '加载失败,请稍后重试';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('邀请奖励')),
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
                      _inviteCard(),
                      const SizedBox(height: 16),
                      _rewardRules(),
                      const SizedBox(height: 16),
                      const Text('奖励明细', style: AppTheme.headline),
                      const SizedBox(height: 8),
                      ..._detailRows(),
                    ],
                  ),
                ),
    );
  }

  /// 邀请码卡片(可复制)
  Widget _inviteCard() {
    final code = (_data?['invite_code'] ?? '').toString();
    final invited = (_data?['invited_count'] ?? 0).toString();
    return FinanceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('我的邀请码', style: AppTheme.caption),
              ),
              Text('已邀请 $invited 人',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(code,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'RobotoMono')),
              ),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('邀请码已复制'),
                      behavior: SnackBarBehavior.floating));
                },
                borderRadius: BorderRadius.circular(AppTheme.tagRadius),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.brandPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.tagRadius),
                    border: Border.all(color: AppTheme.brandPrimary),
                  ),
                  child: const Text('复制',
                      style: TextStyle(
                          color: AppTheme.brandPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFF23282F)),
          Row(
            children: [
              Expanded(child: _stat('累计返佣 (USDT)', _usdt)),
              Expanded(child: _stat('累计返佣 (CNY)', _cny)),
            ],
          ),
        ],
      ),
    );
  }

  double get _usdt => ((_data?['total_reward_usdt'] ?? 0) as num).toDouble();
  double get _cny => ((_data?['total_reward_cny'] ?? 0) as num).toDouble();

  Widget _stat(String label, double value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.caption),
        const SizedBox(height: 4),
        Text(value >= 10000 ? compactFmt(value) : moneyFmt(value),
            style: const TextStyle(
                color: AppTheme.bull,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                fontFamily: 'RobotoMono')),
      ],
    );
  }

  /// 返佣规则说明
  Widget _rewardRules() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x26F0B90B),
        borderRadius: BorderRadius.circular(AppTheme.tagRadius),
      ),
      child: const Text(
        '返佣规则:好友通过你的邀请码注册后,其每笔现货成交按交易流水 1% 自动返佣,'
        '加密交易返 USDT、A股交易返 CNY,实时入账无需领取。',
        style: TextStyle(color: AppTheme.warning, fontSize: 12, height: 1.5),
      ),
    );
  }

  List<Widget> _detailRows() {
    final rows = (_data?['rewards'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    if (rows.isEmpty) {
      return [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32),
          alignment: Alignment.center,
          child: const Text('暂无奖励明细,快去邀请好友交易吧',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ),
      ];
    }
    return [
      for (final r in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _row(r),
        )
    ];
  }

  Widget _row(Map<String, dynamic> t) {
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
          const Icon(Icons.card_giftcard_outlined,
              size: 18, color: AppTheme.bull),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((t['symbol'] ?? '').toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
                const SizedBox(height: 2),
                Text('好友 $trader · 成交额 $symbol${moneyFmt(volume)}',
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

  static String _fmtTime(Object? v) {
    final s = (v ?? '').toString().replaceAll('T', ' ');
    return s.length >= 16 ? s.substring(5, 16) : s;
  }
}
