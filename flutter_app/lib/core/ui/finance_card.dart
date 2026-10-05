import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 金融信息卡片
class FinanceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final LinearGradient? headerGradient;

  const FinanceCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.onTap,
    this.headerGradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: AppTheme.cardSpacing),
      padding: padding ?? const EdgeInsets.all(AppTheme.cardPadding),
      decoration: BoxDecoration(
        color: AppTheme.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppTheme.divider, width: 0.5),
        boxShadow: const [BoxShadow(color: Color(0x4D000000), offset: Offset(0, 1), blurRadius: 3)],
        gradient: headerGradient,
      ),
      child: onTap != null
          ? InkWell(onTap: onTap, borderRadius: BorderRadius.circular(AppTheme.cardRadius), child: child)
          : child,
    );
  }
}
