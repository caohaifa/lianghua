import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 盈亏数字显示组件
/// 涨绿跌红(加密模式) / 红涨绿跌(A股模式)
class PnlNumber extends StatelessWidget {
  final num value;
  final bool isPercentage;
  final bool isAStockMode; // A股红涨绿跌模式(标识符不能含中文,原 isA股Mode)
  final double? fontSize;

  const PnlNumber({
    super.key,
    required this.value,
    this.isPercentage = false,
    this.isAStockMode = false,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final isProfit = value >= 0;
    final color = isAStockMode
        ? (isProfit ? AppTheme.bear : AppTheme.bull) // A股:红涨绿跌
        : (isProfit ? AppTheme.bull : AppTheme.bear); // 加密:绿涨红跌

    final prefix = isProfit ? '+' : '';
    final suffix = isPercentage ? '%' : '';
    final text = '$prefix${value.toStringAsFixed(2)}$suffix';

    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: fontSize ?? 17,
        fontWeight: FontWeight.w500,
        fontFamily: 'RobotoMono',
      ),
    );
  }
}
