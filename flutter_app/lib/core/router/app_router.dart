import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/pages/login_page.dart';
import '../../features/auth/pages/register_page.dart';
import '../../features/auth/pages/verify_code_page.dart';
import '../../features/auth/pages/risk_assessment_page.dart';
import '../../features/auth/pages/agreement_sign_page.dart';
import '../../features/home/main_navigation_page.dart';
import '../../features/market/pages/market_page.dart';
import '../../features/market/pages/quote_detail_page.dart';
import '../../features/market/pages/kline_full_page.dart';
import '../../features/spot/pages/spot_page.dart';
import '../../features/ai/pages/ai_page.dart';
import '../../features/ai/pages/personal_console_page.dart';
import '../../features/ai/pages/alerts_page.dart';
import '../../features/futures/pages/futures_page.dart';
import '../../features/assets/pages/assets_page.dart';
import '../../features/assets/pages/asset_detail_page.dart';
import '../../features/assets/pages/wallet_records_page.dart';
import '../../features/monitor/pages/monitor_detail_page.dart';
import '../../features/position/pages/order_history_page.dart';
import '../../features/profile/pages/profile_page.dart';
import '../../features/profile/pages/risk_report_page.dart';
import '../../features/profile/pages/compliance_page.dart';
import '../../features/profile/pages/referral_rewards_page.dart';
import '../../features/profile/pages/team_page.dart';
import '../../features/profile/pages/settings_pages.dart';
import '../../features/profile/pages/about_page.dart';
import '../../features/profile/pages/api_keys_page.dart';
import '../../features/profile/pages/live_trading_page.dart';
import '../../features/market/pages/announcements_page.dart';
import '../../features/auth/providers/auth_provider.dart';

class AppRouter {
  static final _key = GlobalKey<NavigatorState>(debugLabel: 'root');

  static GoRouter createRouter(AuthProvider auth) => GoRouter(
        navigatorKey: _key,
        // 启动页分流:JWT 有效→主页;未完成测评/协议→对应页;未登录→登录页
        initialLocation: auth.landingRoute,
        routes: [
          // ═════════════ 阶段1: 注册登录 ═════════════
          GoRoute(path: '/login', builder: (c, s) => const LoginPage()),
          GoRoute(path: '/register', builder: (c, s) => const RegisterPage()),
          GoRoute(
              path: '/verify-code', builder: (c, s) => const VerifyCodePage()),
          // ═════════════ 阶段2: 测评/协议 ═════════════
          GoRoute(
              path: '/risk-assessment',
              builder: (c, s) => const RiskAssessmentPage()),
          GoRoute(
              path: '/agreement-sign',
              builder: (c, s) => const AgreementSignPage()),
          // ═════════════ 主导航(浮动胶囊 5 Tab) ═════════════
          ShellRoute(
              builder: (c, s, child) => MainNavigationPage(child: child),
              routes: [
                GoRoute(path: '/market', builder: (c, s) => const MarketPage()),
                GoRoute(path: '/spot', builder: (c, s) => const SpotPage()),
                GoRoute(path: '/ai', builder: (c, s) => const AiPage()),
                GoRoute(
                    path: '/futures', builder: (c, s) => const FuturesPage()),
                GoRoute(path: '/assets', builder: (c, s) => const AssetsPage()),
              ]),
          // ═════════════ 详情页(全屏,带返回) ═════════════
          GoRoute(
              path: '/market/detail',
              builder: (c, s) =>
                  QuoteDetailPage(symbol: s.extra as String? ?? '')),
          GoRoute(
              path: '/kline/full',
              builder: (c, s) {
                final a = (s.extra as Map?)?.cast<String, String>() ?? {};
                return KlineFullPage(
                    symbol: a['symbol'] ?? '', period: a['period'] ?? '1m');
              }),
          GoRoute(
              path: '/assets/detail',
              builder: (c, s) =>
                  AssetDetailPage(symbol: s.extra as String? ?? '')),
          GoRoute(
              path: '/assets/wallet-records',
              builder: (c, s) => const WalletRecordsPage()),
          GoRoute(
              path: '/monitor/detail',
              builder: (c, s) => MonitorDetailPage(
                  data: (s.extra as Map).cast<String, String>())),
          // 个人策略信号台(从 AI 页「我的策略」进入)
          GoRoute(
              path: '/ai/personal-console',
              builder: (c, s) {
                final a =
                    (s.extra as Map?)?.cast<String, dynamic>() ?? const {};
                return PersonalConsolePage(
                    monitorId: (a['id'] as num?)?.toInt() ?? 0,
                    symbol: (a['symbol'] ?? '') as String,
                    strategy: (a['strategy'] ?? '') as String,
                    status: (a['status'] ?? 'running') as String);
              }),
          // 消息中心(告警)
          GoRoute(
              path: '/personal/alerts', builder: (c, s) => const AlertsPage()),
          // 我的(全屏,从资产页进入)
          GoRoute(path: '/profile', builder: (c, s) => const ProfilePage()),
          GoRoute(
              path: '/position/orders',
              builder: (c, s) => const OrderHistoryPage()),
          GoRoute(
              path: '/profile/risk-report',
              builder: (c, s) => const RiskReportPage()),
          GoRoute(
              path: '/profile/compliance',
              builder: (c, s) => const CompliancePage()),
          GoRoute(
              path: '/profile/referral-rewards',
              builder: (c, s) => const ReferralRewardsPage()),
          GoRoute(path: '/profile/team', builder: (c, s) => const TeamPage()),
          GoRoute(
              path: '/profile/settings/notifications',
              builder: (c, s) => const NotificationSettingsPage()),
          GoRoute(
              path: '/profile/settings/general',
              builder: (c, s) => const GeneralSettingsPage()),
          GoRoute(path: '/profile/about', builder: (c, s) => const AboutPage()),
          GoRoute(
              path: '/profile/api-keys',
              builder: (c, s) => const ApiKeysPage()),
          GoRoute(
              path: '/profile/live-trading',
              builder: (c, s) => const LiveTradingPage()),
          GoRoute(
              path: '/announcements',
              builder: (c, s) => const AnnouncementsPage()),
        ],
      );
}
