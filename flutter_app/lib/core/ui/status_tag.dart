import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 状态标签组件
enum StatusType { normal, warning, danger }

class StatusTag extends StatelessWidget {
  final String label;
  final StatusType type;

  const StatusTag({super.key, required this.label, this.type = StatusType.normal});

  @override
  Widget build(BuildContext context) {
    final (bgColor, textColor, icon) = switch (type) {
      StatusType.normal => (const Color(0x2600C853), AppTheme.bull, '🟢'),
      StatusType.warning => (const Color(0x26FFB300), AppTheme.warning, '🟡'),
      StatusType.danger => (const Color(0x26FF3B30), AppTheme.bear, '🔴'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppTheme.tagRadius),
      ),
      child: Text(
        '$icon $label',
        style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.w500),
      ),
    );
  }
}
