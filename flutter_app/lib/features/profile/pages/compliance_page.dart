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
      (title: '用户协议', doc: kUserAgreement),
      (title: '隐私政策', doc: kPrivacyPolicy),
      (title: '风险揭示书', doc: kRiskDisclosure),
      (title: '量化交易服务协议', doc: kQuantServiceAgreement),
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
            onTap: () => AgreementViewerPage.open(context, item.doc),
            child: Row(
              children: [
                const Icon(Icons.assignment_outlined,
                    color: AppTheme.brandPrimary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: AppTheme.body),
                      const Text('点击查看全文', style: AppTheme.caption),
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
