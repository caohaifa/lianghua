import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/finance_card.dart';
import '../../../core/ui/status_tag.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/widgets/agreement_texts.dart';

/// 合规档案:已签署协议列表,可回看协议全文
class CompliancePage extends StatelessWidget {
  const CompliancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final signed = context.watch<AuthProvider>().user?.agreementSigned ?? false;
    final items = [
      (title: '用户协议', text: kUserAgreement),
      (title: '隐私政策', text: kPrivacyPolicy),
      (title: '风险揭示书', text: null),
      (title: '量化交易服务协议', text: null),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('合规档案')),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppTheme.pagePadding),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (c, i) {
          final item = items[i];
          return FinanceCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            onTap: item.text != null
                ? () => AgreementViewerPage.open(context, item.text!)
                : null,
            child: Row(
              children: [
                const Icon(Icons.assignment_outlined, color: AppTheme.brandPrimary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: AppTheme.body),
                      Text(item.text != null ? '点击查看全文' : '注册时已勾选确认',
                          style: AppTheme.caption),
                    ],
                  ),
                ),
                StatusTag(
                  label: signed ? '已签署' : '未签署',
                  type: signed ? StatusType.normal : StatusType.warning,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
