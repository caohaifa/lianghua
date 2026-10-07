import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../monitor/providers/copy_provider.dart';

/// 消息中心:个人策略站内告警(跟单跳过/风控/系统),进入拉取,退出全部标读。
class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  CopyProvider? _copy;

  @override
  void initState() {
    super.initState();
    _copy = context.read<CopyProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _copy?.fetchAlerts());
  }

  @override
  void dispose() {
    // 退出页面:仍有未读则全部标读(本地清零 + 异步请求)
    if ((_copy?.unreadAlerts ?? 0) > 0) _copy?.readAlerts();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = context.watch<CopyProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('消息告警')),
      body: Column(
        children: [
          if (copy.copyPaused) _pausedBanner(),
          Expanded(
            child: copy.alerts.isEmpty
                ? const Center(
                    child: Text('暂无消息', style: AppTheme.caption))
                : RefreshIndicator(
                    onRefresh: () => copy.fetchAlerts(),
                    color: AppTheme.brandPrimary,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(AppTheme.pagePadding),
                      itemCount: copy.alerts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (c, i) => _tile(copy.alerts[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// 全局跟单风控暂停提示条
  Widget _pausedBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.brandPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: AppTheme.brandPrimary.withValues(alpha: 0.4), width: 0.6),
      ),
      child: const Row(
        children: [
          Icon(Icons.pause_circle_outline,
              color: AppTheme.brandPrimary, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text('全局跟单风控已暂停,恢复前信号不下发',
                style: TextStyle(color: AppTheme.brandPrimary, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _tile(AlertItem a) {
    final unread = a.isUnread;
    final (typeText, typeColor) = switch (a.type) {
      'copy_skip' => ('跟单跳过', AppTheme.brandPrimary),
      'risk' => ('风控', AppTheme.bear),
      _ => ('系统', AppTheme.textSecondary),
    };
    final time = a.createdAt.length >= 16
        ? a.createdAt.substring(5, 16).replaceAll('T', ' ')
        : a.createdAt;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF181A20),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppTheme.divider, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 未读小圆点
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: unread ? AppTheme.brandPrimary : Colors.transparent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(a.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: unread ? Colors.white : AppTheme.textSecondary,
                              fontSize: 14,
                              fontWeight: unread
                                  ? FontWeight.w600
                                  : FontWeight.w500)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(typeText,
                          style: TextStyle(
                              color: typeColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                if (a.content.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(a.content,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                ],
                const SizedBox(height: 4),
                Text(time,
                    style: const TextStyle(
                        color: AppTheme.textTertiary, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
