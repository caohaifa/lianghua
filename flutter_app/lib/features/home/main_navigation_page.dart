import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

/// 主导航:浮动胶囊 5 tab(行情/现货/AI/合约/资产)
class MainNavigationPage extends StatelessWidget {
  final Widget child;
  const MainNavigationPage({super.key, required this.child});

  static const _tabs = [
    (path: '/market', icon: Icons.candlestick_chart_outlined, label: '行情'),
    (path: '/spot', icon: Icons.sync_alt, label: '现货'),
    (path: '/ai', icon: Icons.auto_awesome, label: 'AI'),
    (path: '/futures', icon: Icons.bolt, label: '合约'),
    (path: '/assets', icon: Icons.account_balance_wallet_outlined, label: '资产'),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final current = _tabs.indexWhere((t) => location.startsWith(t.path));
    final idx = current >= 0 ? current : 0;

    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        child: Container(
          height: 62,
          decoration: BoxDecoration(
            color: const Color(0xFF181A20),
            borderRadius: BorderRadius.circular(31),
            border: Border.all(color: const Color(0xFF262B33)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              for (var i = 0; i < _tabs.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => context.go(_tabs[i].path),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: EdgeInsets.symmetric(
                              horizontal: i == idx ? 14 : 0, vertical: 4),
                          decoration: BoxDecoration(
                            color: i == idx
                                ? AppTheme.brandPrimary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            _tabs[i].icon,
                            size: 19,
                            color: i == idx
                                ? AppTheme.onBrand
                                : AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _tabs[i].label,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: i == idx
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: i == idx
                                ? AppTheme.brandPrimary
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
