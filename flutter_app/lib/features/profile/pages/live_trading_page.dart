import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/finance_card.dart';
import '../../../core/ui/status_tag.dart';

/// 实盘启动:模拟盘/实盘切换(实盘前置:已签协议 + 已绑 API Key)
class LiveTradingPage extends StatefulWidget {
  const LiveTradingPage({super.key});

  @override
  State<LiveTradingPage> createState() => _LiveTradingPageState();
}

class _LiveTradingPageState extends State<LiveTradingPage> {
  String _mode = 'sim';
  bool _hasKey = false;
  bool _agreementSigned = false;
  bool _loading = true;
  bool _switching = false;

  Dio get _dio => ApiClient().dio;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _dio.get('/trading/mode');
      final d = res.data['data'];
      setState(() {
        _mode = d['trading_mode'] ?? 'sim';
        _hasKey = d['has_api_key'] == true;
        _agreementSigned = d['agreement_signed'] == true;
      });
    } catch (_) {
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _switch(String mode) async {
    if (mode == _mode) return;
    // 实盘前二次确认:实盘委托将真实提交交易所
    if (mode == 'live') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('开启实盘交易?'),
          content: const Text('实盘模式下委托将提交至您绑定的交易所账户,产生真实资金变动。\n\n请确认已充分知晓风险。'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(c).pop(false),
                child: const Text('取消')),
            ElevatedButton(
                onPressed: () => Navigator.of(c).pop(true),
                child: const Text('确认开启')),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => _switching = true);
    try {
      await _dio.put('/trading/mode', data: {'mode': mode});
      _toast(mode == 'live' ? '已切换至实盘交易' : '已切换至模拟盘');
      _load();
    } catch (e) {
      final msg = (e is DioException && e.response?.data is Map)
          ? e.response!.data['message']?.toString() ?? '切换失败'
          : '网络异常';
      _toast(msg);
    } finally {
      setState(() => _switching = false);
    }
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final isLive = _mode == 'live';
    return Scaffold(
      appBar: AppBar(title: const Text('实盘启动')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppTheme.pagePadding),
              children: [
                // 当前模式卡片
                FinanceCard(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(isLive ? Icons.flash_on : Icons.science_outlined,
                          color: isLive ? AppTheme.bear : AppTheme.brandPrimary,
                          size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isLive ? '实盘交易' : '模拟盘',
                                style: AppTheme.headline),
                            Text(isLive ? '委托提交至绑定的交易所账户' : '虚拟资金撮合,零风险演练',
                                style: AppTheme.caption),
                          ],
                        ),
                      ),
                      StatusTag(
                          label: isLive ? 'LIVE' : 'SIM',
                          type: isLive ? StatusType.danger : StatusType.normal),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 前置条件
                Text('实盘前置条件', style: AppTheme.headline),
                const SizedBox(height: 8),
                _PrerequisiteItem(
                  ok: _agreementSigned,
                  title: '协议签署',
                  desc: _agreementSigned ? '已完成' : '未完成,请先完成协议签署',
                ),
                _PrerequisiteItem(
                  ok: _hasKey,
                  title: 'API Key 绑定',
                  desc: _hasKey ? '已绑定交易所凭据' : '未绑定,请先在 API Key 管理绑定',
                  onAction:
                      _hasKey ? null : () => context.push('/profile/api-keys'),
                  actionLabel: '去绑定',
                ),
                const SizedBox(height: 16),

                // 切换按钮
                ElevatedButton.icon(
                  onPressed: _switching
                      ? null
                      : () => _switch(isLive ? 'sim' : 'live'),
                  icon: Icon(isLive ? Icons.stop : Icons.play_arrow),
                  label: Text(isLive ? '停止实盘,切回模拟盘' : '启动实盘交易'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isLive ? AppTheme.brandPrimary : AppTheme.bear,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0x26FFB300),
                    borderRadius: BorderRadius.circular(AppTheme.tagRadius),
                  ),
                  child: Text(
                    '⚠️ 实盘交易存在本金损失风险。AI 信号仅为辅助决策,请自行承担交易结果。',
                    style: TextStyle(color: AppTheme.warning, fontSize: 12),
                  ),
                ),
              ],
            ),
    );
  }
}

class _PrerequisiteItem extends StatelessWidget {
  final bool ok;
  final String title;
  final String desc;
  final VoidCallback? onAction;
  final String? actionLabel;

  const _PrerequisiteItem(
      {required this.ok,
      required this.title,
      required this.desc,
      this.onAction,
      this.actionLabel});

  @override
  Widget build(BuildContext context) {
    return FinanceCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.cancel,
              color: ok ? AppTheme.bull : AppTheme.bear, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.body),
                Text(desc, style: AppTheme.caption),
              ],
            ),
          ),
          if (onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel ?? '去完成')),
        ],
      ),
    );
  }
}
