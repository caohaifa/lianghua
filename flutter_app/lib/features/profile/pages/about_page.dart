import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/finance_card.dart';

/// 关于我们
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关于我们')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.pagePadding),
        child: Column(
          children: [
            const SizedBox(height: 24),
            const Icon(Icons.trending_up, size: 64, color: AppTheme.brandPrimary),
            const SizedBox(height: 12),
            Text('AI 量化', style: AppTheme.display),
            const SizedBox(height: 4),
            const Text('V1.0.0', style: AppTheme.caption),
            const SizedBox(height: 24),
            FinanceCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: const [
                  _AboutRow(label: '产品', value: '多智能体协同量化交易平台'),
                  Divider(color: AppTheme.divider, height: 20),
                  _AboutRow(label: '决策引擎', value: '五因子门控决策'),
                  Divider(color: AppTheme.divider, height: 20),
                  _AboutRow(label: '联系方式', value: 'support@aiquant.example'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x26FFB300),
                borderRadius: BorderRadius.circular(AppTheme.tagRadius),
              ),
              child: const Text(
                'AI 辅助决策,自主承担风险。历史回测不代表未来收益。',
                style: TextStyle(color: AppTheme.warning, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final String label;
  final String value;
  const _AboutRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTheme.caption),
        Text(value, style: AppTheme.body),
      ],
    );
  }
}
