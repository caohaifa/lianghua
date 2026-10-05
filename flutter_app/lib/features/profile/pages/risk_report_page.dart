import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/finance_card.dart';
import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

/// 风险测评报告:展示当前风险等级 + 后端测评状态
class RiskReportPage extends StatefulWidget {
  const RiskReportPage({super.key});

  @override
  State<RiskReportPage> createState() => _RiskReportPageState();
}

class _RiskReportPageState extends State<RiskReportPage> {
  Map<String, dynamic>? _status;
  bool _loading = true;
  String? _error;

  static const _levelDesc = {
    'R1': '保守型 — 仅适合低风险策略',
    'R2': '谨慎型 — 可参与低杠杆策略',
    'R3': '稳健型 — 可参与中风险量化策略',
    'R4': '积极型 — 可参与高波动策略',
    'R5': '激进型 — 可参与全部策略',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient().dio.get('/risk/status');
      setState(() {
        _status = (res.data['data'] as Map?)?.cast<String, dynamic>();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载失败,请稍后重试';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final level = context.watch<AuthProvider>().user?.riskLevel ?? '未测评';
    return Scaffold(
      appBar: AppBar(title: const Text('风险测评报告')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: AppTheme.caption))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.pagePadding),
                  child: Column(
                    children: [
                      FinanceCard(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Text(level, style: const TextStyle(
                              color: AppTheme.brandPrimary, fontSize: 40, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Text(_levelDesc[level] ?? '尚未完成风险测评', style: AppTheme.body),
                          ],
                        ),
                      ),
                      if (_status != null) ...[
                        const SizedBox(height: 16),
                        FinanceCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('测评状态', style: AppTheme.headline),
                              const SizedBox(height: 12),
                              for (final e in _status!.entries)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(e.key, style: AppTheme.caption),
                                      Text('${e.value}', style: AppTheme.body),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0x26FFB300),
                          borderRadius: BorderRadius.circular(AppTheme.tagRadius),
                        ),
                        child: const Text(
                          '风险等级决定可参与的策略范围,测评结果有效期 1 年。',
                          style: TextStyle(color: AppTheme.warning, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
