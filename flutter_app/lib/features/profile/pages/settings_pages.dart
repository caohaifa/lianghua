import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/finance_card.dart';

/// 设置项持久化封装:key 前缀区分页面,默认值硬编码兜底。
class _SettingsStore {
  static const _prefix = 'settings:';

  static Future<Map<String, bool>> load(
      String group, Map<String, bool> defaults) async {
    final prefs = await SharedPreferences.getInstance();
    return {
      for (final e in defaults.entries)
        e.key: prefs.getBool('$_prefix$group.${e.key}') ?? e.value,
    };
  }

  static Future<void> save(String group, String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefix$group.$key', value);
  }
}

/// 消息通知设置
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  static const _defaults = <String, bool>{
    '交易信号推送': true,
    '策略状态变更': true,
    '价格预警': false,
    '系统公告': true,
    '夜间免打扰 (22:00-08:00)': false,
  };
  Map<String, bool> _items = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await _SettingsStore.load('notify', _defaults);
    if (mounted) setState(() => _items = v);
  }

  Future<void> _toggle(String k, bool v) async {
    setState(() => _items[k] = v);
    await _SettingsStore.save('notify', k, v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('消息通知设置')),
      body: _items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _SettingsList(items: _items, onChanged: _toggle),
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
  static const _defaults = <String, bool>{
    '行情自动刷新': true,
    '涨跌红绿配色 (A股模式)': false,
    '后台保持 WebSocket 连接': true,
    '震动反馈': false,
  };
  Map<String, bool> _items = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await _SettingsStore.load('general', _defaults);
    if (mounted) setState(() => _items = v);
  }

  Future<void> _toggle(String k, bool v) async {
    setState(() => _items[k] = v);
    await _SettingsStore.save('general', k, v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('通用设置')),
      body: _items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _SettingsList(items: _items, onChanged: _toggle),
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
