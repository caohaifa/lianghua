import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/finance_card.dart';
import '../../../core/ui/status_tag.dart';
import '../../auth/providers/auth_provider.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.pagePadding),
        children: [
          // 用户信息卡片
          FinanceCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.brandPrimary,
                  child: Text(
                    (user?.nickname ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(fontSize: 24, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.nickname ?? '量化用户', style: AppTheme.title),
                      const SizedBox(height: 4),
                      Text(user?.phone ?? '', style: AppTheme.caption),
                    ],
                  ),
                ),
                const VerticalDivider(),
                Column(
                  children: [
                    Text('风险等级', style: AppTheme.caption),
                    const SizedBox(height: 4),
                    StatusTag(
                        label: user?.riskLevel ?? '未测评',
                        type: StatusType.warning),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 功能分组
          const _SectionTitle(title: '交易'),
          _MenuItem(
              icon: Icons.api_outlined,
              title: 'API Key 管理',
              subtitle: '交易所凭据加密托管',
              onTap: () => context.push('/profile/api-keys')),
          _MenuItem(
              icon: Icons.play_circle_outline,
              title: '实盘启动',
              subtitle: '⚠️ 实盘前需完成协议签署与 API Key 绑定',
              onTap: () => context.push('/profile/live-trading')),
          _MenuItem(
              icon: Icons.history,
              title: '委托记录',
              onTap: () => context.push('/position/orders')),
          _MenuItem(
              icon: Icons.account_balance,
              title: '分成结算',
              subtitle: '订阅套餐与月度分成记录',
              onTap: () => context.push('/profile/settlement')),

          const SizedBox(height: 16),
          const _SectionTitle(title: '合规'),
          _MenuItem(
              icon: Icons.assignment_outlined,
              title: '合规档案',
              subtitle: '已签署 4 份协议',
              onTap: () => context.push('/profile/compliance')),
          _MenuItem(
              icon: Icons.fact_check_outlined,
              title: '风险测评报告',
              subtitle: user?.riskLevel != null ? '${user!.riskLevel}' : '未测评',
              onTap: () => context.push('/profile/risk-report')),

          const SizedBox(height: 16),
          const _SectionTitle(title: '系统'),
          _MenuItem(
              icon: Icons.notifications_outlined,
              title: '消息通知设置',
              onTap: () => context.push('/profile/settings/notifications')),
          _MenuItem(
              icon: Icons.settings_outlined,
              title: '通用设置',
              onTap: () => context.push('/profile/settings/general')),
          _MenuItem(
              icon: Icons.description_outlined,
              title: '关于我们',
              subtitle: 'V1.0.0',
              onTap: () => context.push('/profile/about')),

          const SizedBox(height: 24),
          // 退出登录
          ElevatedButton(
            onPressed: () async {
              await auth.logout();
              if (context.mounted) context.go('/login');
            },
            style: ElevatedButton.styleFrom(
              foregroundColor: AppTheme.bear,
              backgroundColor: const Color(0x26FF3B30),
              elevation: 0,
            ),
            child: const Text('退出登录'),
          ),
          const SizedBox(height: 16),
          // 风险告知
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0x26FFB300),
              borderRadius: BorderRadius.circular(AppTheme.tagRadius),
            ),
            child: Text(
              'AI 辅助决策,自主承担风险。历史回测不代表未来收益。请根据自身风险承受能力谨慎投资。',
              style: TextStyle(color: AppTheme.warning, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title, style: AppTheme.headline),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _MenuItem(
      {required this.icon,
      required this.title,
      this.subtitle,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FinanceCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.brandPrimary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTheme.body),
                  if (subtitle != null)
                    Text(subtitle!, style: AppTheme.caption),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppTheme.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}
