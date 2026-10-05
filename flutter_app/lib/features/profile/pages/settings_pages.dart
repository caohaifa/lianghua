import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/finance_card.dart';

/// 消息通知设置
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final _items = <String, bool>{
    '交易信号推送': true,
    '策略状态变更': true,
    '价格预警': false,
    '系统公告': true,
    '夜间免打扰 (22:00-08:00)': false,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('消息通知设置')),
      body: _SettingsList(items: _items, onChanged: (k, v) => setState(() => _items[k] = v)),
    );
  }
}

/// 通用设置
class GeneralSettingsPage extends StatefulWidget {
  const GeneralSettingsPage({super.key});

  @override
  State<GeneralSettingsPage> createState() => _GeneralSettingsPageState();
}

class _GeneralSettingsPageState extends State<GeneralSettingsPage> {
  final _items = <String, bool>{
    '行情自动刷新': true,
    '涨跌红绿配色 (A股模式)': false,
    '后台保持 WebSocket 连接': true,
    '震动反馈': false,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('通用设置')),
      body: _SettingsList(items: _items, onChanged: (k, v) => setState(() => _items[k] = v)),
    );
  }
}

class _SettingsList extends StatelessWidget {
  final Map<String, bool> items;
  final void Function(String key, bool value) onChanged;
  const _SettingsList({required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppTheme.pagePadding),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (c, i) {
        final e = items.entries.elementAt(i);
        return FinanceCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(e.key, style: AppTheme.body),
              Switch(
                value: e.value,
                activeTrackColor: AppTheme.brandPrimary,
                onChanged: (v) => onChanged(e.key, v),
              ),
            ],
          ),
        );
      },
    );
  }
}
