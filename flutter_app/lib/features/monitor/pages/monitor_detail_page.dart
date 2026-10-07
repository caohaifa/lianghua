import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/finance_card.dart';
import '../../../core/ui/status_tag.dart';

/// 监控详情:标的/策略/状态/当前信号
class MonitorDetailPage extends StatelessWidget {
  final Map<String, String> data;
  const MonitorDetailPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final isRunning = data['status'] == '运行中';
    return Scaffold(
      appBar: AppBar(title: Text(data['symbol'] ?? '监控详情')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.pagePadding),
        child: Column(
          children: [
            FinanceCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(data['symbol'] ?? '', style: AppTheme.headline),
                      const SizedBox(width: 8),
                      StatusTag(
                        label: data['status'] ?? '',
                        type: isRunning ? StatusType.normal : StatusType.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: AppTheme.divider, height: 1),
                  const SizedBox(height: 16),
                  _row('运行策略', data['strategy'] ?? '-'),
                  const SizedBox(height: 12),
                  _row('当前信号', data['signal'] ?? '-'),
                  const SizedBox(height: 12),
                  _row('运行状态', data['status'] ?? '-'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x26F0B90B),
                borderRadius: BorderRadius.circular(AppTheme.tagRadius),
              ),
              child: const Text(
                '监控信号由多智能体协同生成,仅供参考,不构成投资建议。',
                style: TextStyle(color: AppTheme.warning, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTheme.caption),
        Text(value, style: AppTheme.body),
      ],
    );
  }
}
