import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../utils/technical_indicators.dart';

/// K 线控制面板(周期切换 + 主图指标开关 + 副图指标切换)
/// 供行情详情页 / 全屏 K 线页共用,避免重复代码。
class KlineControlPanel extends StatelessWidget {
  /// 当前选中周期
  final String currentPeriod;

  /// 可用周期(有序),加密 15 种 / A 股 5 种
  final Map<String, String> periods;

  /// 主图指标开关
  final bool showMa;
  final bool showBoll;

  /// 当前副图指标
  final SubIndicator sub;

  /// 回调
  final ValueChanged<String> onPeriodChanged;
  final VoidCallback onToggleMa;
  final VoidCallback onToggleBoll;
  final ValueChanged<SubIndicator> onSubChanged;

  /// 内边距(全屏页可传更小值)
  final EdgeInsets padding;

  const KlineControlPanel({
    super.key,
    required this.currentPeriod,
    required this.periods,
    required this.showMa,
    required this.showBoll,
    required this.sub,
    required this.onPeriodChanged,
    required this.onToggleMa,
    required this.onToggleBoll,
    required this.onSubChanged,
    this.padding = const EdgeInsets.fromLTRB(12, 8, 12, 0),
  });

  static const _subLabels = {
    SubIndicator.vol: 'VOL',
    SubIndicator.macd: 'MACD',
    SubIndicator.kdj: 'KDJ',
    SubIndicator.rsi: 'RSI',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        children: [
          // 第一行:主图指标开关
          Row(
            children: [
              _Chip(label: 'MA', selected: showMa, onTap: onToggleMa),
              const SizedBox(width: 8),
              _Chip(label: 'BOLL', selected: showBoll, onTap: onToggleBoll),
            ],
          ),
          const SizedBox(height: 6),
          // 第二行:周期切换(横滑)
          SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final e in periods.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _Chip(
                      label: e.value,
                      selected: currentPeriod == e.key,
                      onTap: () => onPeriodChanged(e.key),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // 第三行:副图指标
          Row(
            children: [
              for (final e in _subLabels.entries) ...[
                _Chip(
                  label: e.value,
                  selected: sub == e.key,
                  onTap: () => onSubChanged(e.key),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// 指标选择小胶囊
class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppTheme.brandPrimary : const Color(0xFF23282F),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppTheme.onBrand : AppTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
