import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/finance_card.dart';
import '../../../core/ui/status_tag.dart';

/// 分成结算:当前订阅状态 + 订阅操作 + 月度分成记录
class SettlementPage extends StatefulWidget {
  const SettlementPage({super.key});

  @override
  State<SettlementPage> createState() => _SettlementPageState();
}

class _SettlementPageState extends State<SettlementPage> {
  Map<String, dynamic>? _status;
  List<Map<String, dynamic>> _settlements = [];
  bool _loading = true;

  Dio get _dio => ApiClient().dio;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await Future.wait([
        _dio.get('/subscription/status'),
        _dio.get('/billing/settlements'),
      ]);
      setState(() {
        _status = res[0].data['data'];
        _settlements =
            (res[1].data['data'] as List).cast<Map<String, dynamic>>();
      });
    } catch (_) {
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _subscribe(String planLevel, String period) async {
    try {
      await _dio.post('/subscription/subscribe',
          data: {'plan_level': planLevel, 'period': period});
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('订阅成功')));
      _load();
    } catch (e) {
      if (!mounted) return;
      final msg = (e is DioException && e.response?.data is Map)
          ? e.response!.data['message']?.toString() ?? '订阅失败'
          : '网络异常';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('分成结算')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppTheme.pagePadding),
                children: [
                  _statusCard(),
                  const SizedBox(height: 16),
                  Text('月度分成记录', style: AppTheme.headline),
                  const SizedBox(height: 8),
                  if (_settlements.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                          child: Text('暂无分成结算记录', style: AppTheme.caption)),
                    )
                  else
                    ..._settlements.map(_settlementTile),
                ],
              ),
            ),
    );
  }

  Widget _statusCard() {
    final s = _status ?? {};
    final active = s['active'] == true;
    return FinanceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('当前套餐', style: AppTheme.caption),
                    const SizedBox(height: 4),
                    Text(s['plan_name'] ?? '免费版', style: AppTheme.headline),
                  ],
                ),
              ),
              StatusTag(
                  label: active ? '生效中' : '未订阅',
                  type: active ? StatusType.normal : StatusType.warning),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppTheme.divider, height: 1),
          const SizedBox(height: 16),
          if (active && s['expire_at'] != null) ...[
            Row(
              children: [
                const Text('到期时间', style: AppTheme.caption),
                const Spacer(),
                Text(
                    s['expire_at']
                        .toString()
                        .substring(0, 16)
                        .replaceAll('T', ' '),
                    style: AppTheme.body),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (!active) Text('免费版可创建 1 个监控,订阅套餐解锁更多', style: AppTheme.caption),
          if (active)
            Text('监控数量上限:${s['plan_level'] == 'pro' ? '20' : '5'} 个',
                style: AppTheme.caption),
          if (active) const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _subscribe('basic', 'month'),
                  child: const Text('基础版 ¥99/月'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _subscribe('pro', 'month'),
                  child: const Text('专业版 ¥299/月'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _settlementTile(Map<String, dynamic> m) {
    final profit = (m['profitAmount'] as num).toDouble();
    final ratio = (m['shareRatio'] as num).toDouble();
    final share = (m['shareAmount'] as num).toDouble();
    final time = (m['settledAt'] ?? '').toString();
    return FinanceCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(time.length >= 7 ? time.substring(0, 7) : time,
                    style: AppTheme.title),
                Text('盈利 ¥${profit.toStringAsFixed(2)} · 分成比例 $ratio%',
                    style: AppTheme.caption),
              ],
            ),
          ),
          Text('-¥${share.toStringAsFixed(2)}',
              style: const TextStyle(
                  color: AppTheme.bear,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'RobotoMono')),
        ],
      ),
    );
  }
}
