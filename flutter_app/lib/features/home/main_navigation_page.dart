import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class MainNavigationPage extends StatelessWidget {
  final Widget child;
  const MainNavigationPage({super.key, required this.child});

  static const _tabs = [
    (path: '/market', icon: Icons.candlestick_chart_outlined, label: '行情'),
    (path: '/monitor', icon: Icons.radar, label: '监控'),
    (path: '/position', icon: Icons.account_balance_wallet_outlined, label: '持仓'),
    (path: '/profile', icon: Icons.person_outline, label: '我的'),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final idx = _tabs.indexWhere((t) => location.startsWith(t.path));
    final current = idx >= 0 ? idx : 0;

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.divider, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: current,
          onTap: (i) => context.go(_tabs[i].path),
          items: _tabs.map((t) => BottomNavigationBarItem(
            icon: Icon(t.icon, size: 24),
            activeIcon: Icon(t.icon, size: 24, color: AppTheme.brandPrimary),
            label: t.label,
          )).toList(),
        ),
      ),
    );
  }
}
