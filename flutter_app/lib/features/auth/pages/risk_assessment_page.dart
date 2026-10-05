import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/finance_card.dart';
import '../providers/auth_provider.dart';

class RiskAssessmentPage extends StatefulWidget {
  const RiskAssessmentPage({super.key});

  @override
  State<RiskAssessmentPage> createState() => _RiskAssessmentPageState();
}

class _RiskAssessmentPageState extends State<RiskAssessmentPage> {
  final _questions = const [
    {'q': '您的年龄范围是?', 'options': ['18-30岁', '31-45岁', '46-55岁', '55岁以上']},
    {'q': '您的投资经验年限?', 'options': ['不足1年', '1-3年', '3-5年', '5年以上']},
    {'q': '您家庭可用于投资的资产占家庭总资产比例?', 'options': ['<10%', '10%-30%', '30%-50%', '>50%']},
    {'q': '您的投资收入占家庭总收入比例?', 'options': ['<10%', '10%-30%', '30%-50%', '>50%']},
    {'q': '您是否有使用杠杆/配资/期货等高风险工具的经验?', 'options': ['完全没有', '有过尝试', '经常使用', '熟练运用']},
    {'q': '当投资亏损达到本金的 20% 时,您会?', 'options': ['立即全部清仓', '减仓止损', '持有观望', '加仓摊低成本']},
    {'q': '您期望的年化收益率是?', 'options': ['0-10%', '10%-30%', '30%-50%', '>50%']},
    {'q': '您能接受的最大单日亏损?', 'options': ['1%以内', '1%-3%', '3%-5%', '5%以上']},
    {'q': '您对量化交易和AI选股的了解程度?', 'options': ['完全不了解', '知道概念', '有实际使用', '深入理解']},
    {'q': '本次投资资金占您可支配资金的比例?', 'options': ['<10%', '10%-30%', '30%-50%', '>50%']},
  ];

  final List<int?> _answers = List.filled(10, null);
  int _currentIdx = 0;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final progress = (_currentIdx + 1) / _questions.length;
    final q = _questions[_currentIdx];
    final options = q['options']! as List<String>;

    return Scaffold(
      appBar: AppBar(
        title: const Text('风险测评'),
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppTheme.divider,
            valueColor: const AlwaysStoppedAnimation(AppTheme.brandPrimary),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('第 ${_currentIdx + 1}/10 题', style: AppTheme.caption),
              const SizedBox(height: 8),
              Text(q['q']! as String, style: AppTheme.title),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: options.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (c, i) {
                    final selected = _answers[_currentIdx] == i;
                    return InkWell(
                      onTap: () => _select(i),
                      child: FinanceCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Icon(
                              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                              color: selected ? AppTheme.brandPrimary : AppTheme.textSecondary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(options[i], style: AppTheme.body)),
                            if (selected)
                              const Icon(Icons.check_circle, color: AppTheme.bull, size: 20),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentIdx > 0)
                    OutlinedButton(
                      onPressed: () => setState(() => _currentIdx--),
                      child: const Text('上一题'),
                    )
                  else
                    const SizedBox.shrink(),
                  if (_currentIdx < _questions.length - 1)
                    ElevatedButton(
                      onPressed: _answers[_currentIdx] != null
                          ? () => setState(() => _currentIdx++)
                          : null,
                      child: const Text('下一题'),
                    )
                  else
                    ElevatedButton(
                      onPressed: (_answers.every((a) => a != null) && !_loading)
                          ? _submit
                          : null,
                      child: _loading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('提交测评'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _select(int i) {
    setState(() => _answers[_currentIdx] = i);
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.submitRiskAssessment(_answers.whereType<int>().toList());
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      context.go('/agreement-sign');
    }
  }
}
