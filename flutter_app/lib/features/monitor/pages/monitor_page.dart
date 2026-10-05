import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/finance_card.dart';
import '../../../core/ui/status_tag.dart';
import '../../market/providers/market_provider.dart';
import '../providers/monitor_provider.dart';

class MonitorPage extends StatefulWidget {
  const MonitorPage({super.key});

  @override
  State<MonitorPage> createState() => _MonitorPageState();
}

class _MonitorPageState extends State<MonitorPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MonitorProvider>().load();
      context.read<MonitorProvider>().loadAgents();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('监控'),
        actions: [
          IconButton(
              onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const _CreateMonitorDialog()),
              icon: const Icon(Icons.add, color: AppTheme.textSecondary)),
        ],
      ),
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: '监控列表'),
                Tab(text: '策略运行'),
                Tab(text: 'Agent状态'),
              ],
              labelColor: AppTheme.brandPrimary,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.brandPrimary,
              indicatorSize: TabBarIndicatorSize.label,
              indicatorWeight: 3,
            ),
            Expanded(
              child: TabBarView(children: [
                _MonitorList(),
                _StrategyList(),
                _AgentStatus(),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

/// 新建监控弹窗:标的 + 策略
class _CreateMonitorDialog extends StatefulWidget {
  const _CreateMonitorDialog();

  @override
  State<_CreateMonitorDialog> createState() => _CreateMonitorDialogState();
}

class _CreateMonitorDialogState extends State<_CreateMonitorDialog> {
  String? _symbol;
  String _strategy = MonitorProvider.strategies.first;
  bool _submitting = false;

  Future<void> _submit() async {
    if (_symbol == null) return;
    setState(() => _submitting = true);
    final err =
        await context.read<MonitorProvider>().create(_symbol!, _strategy);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (err == null) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('监控已创建')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final quotes = context.watch<MarketProvider>().quotes;
    _symbol ??= quotes.isNotEmpty ? quotes.first.symbol : null;
    return AlertDialog(
      title: const Text('新建监控'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _symbol,
            decoration: const InputDecoration(labelText: '标的'),
            items: quotes
                .map((q) => DropdownMenuItem(
                    value: q.symbol, child: Text('${q.symbol}  ${q.name}')))
                .toList(),
            onChanged: (v) => setState(() => _symbol = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _strategy,
            decoration: const InputDecoration(labelText: '策略'),
            items: MonitorProvider.strategies
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _strategy = v!),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消')),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('创建'),
        ),
      ],
    );
  }
}

class _MonitorList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MonitorProvider>();
    if (provider.loading && provider.monitors.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.error != null && provider.monitors.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(provider.error!, style: AppTheme.caption),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: provider.load, child: const Text('重试')),
        ]),
      );
    }
    if (provider.monitors.isEmpty) {
      return const Center(
          child: Text('暂无监控,点右上角 + 创建', style: AppTheme.caption));
    }
    return RefreshIndicator(
      onRefresh: provider.load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTheme.pagePadding),
        itemCount: provider.monitors.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (c, i) => _tile(context, provider, provider.monitors[i]),
      ),
    );
  }

  Widget _tile(BuildContext context, MonitorProvider provider, MonitorItem m) {
    return FinanceCard(
      onTap: () => context.push('/monitor/detail', extra: {
        'symbol': m.symbol,
        'strategy': m.strategy,
        'status': m.isRunning ? '运行中' : '暂停',
        'signal': m.signal,
      }),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(m.symbol, style: AppTheme.title),
              const SizedBox(width: 8),
              StatusTag(
                label: m.isRunning ? '运行中' : '暂停',
                type: m.isRunning ? StatusType.normal : StatusType.warning,
              ),
              const Spacer(),
              Text(m.strategy, style: AppTheme.caption),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: AppTheme.divider, height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text('当前信号: ${m.signal}', style: AppTheme.body)),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => provider.toggle(m),
                icon: Icon(
                    m.isRunning
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline,
                    color: AppTheme.brandPrimary,
                    size: 20),
                tooltip: m.isRunning ? '暂停' : '恢复',
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => provider.remove(m),
                icon: const Icon(Icons.delete_outline,
                    color: AppTheme.bear, size: 20),
                tooltip: '删除',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 策略运行:由真实监控按策略聚合(运行数/监控数)
class _StrategyList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final monitors = context.watch<MonitorProvider>().monitors;
    if (monitors.isEmpty) {
      return const Center(
          child: Text('暂无运行中的策略,先创建监控', style: AppTheme.caption));
    }
    final grouped = <String, List<MonitorItem>>{};
    for (final m in monitors) {
      grouped.putIfAbsent(m.strategy, () => []).add(m);
    }
    final entries = grouped.entries.toList();
    return ListView.separated(
      padding: const EdgeInsets.all(AppTheme.pagePadding),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (c, i) {
        final e = entries[i];
        final running = e.value.where((m) => m.isRunning).length;
        return FinanceCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Text(e.key, style: AppTheme.title),
                  const Spacer(),
                  StatusTag(
                    label: running > 0 ? '运行中' : '已暂停',
                    type: running > 0 ? StatusType.normal : StatusType.warning,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('监控标的', style: AppTheme.caption),
                      Text('${e.value.length}', style: AppTheme.numberM),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('运行中', style: AppTheme.caption),
                      Text('$running', style: AppTheme.numberM),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Agent 状态:接 Python AI /agents/status
class _AgentStatus extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MonitorProvider>();
    if (provider.agents.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('AI 服务未连接', style: AppTheme.caption),
          const SizedBox(height: 12),
          OutlinedButton(
              onPressed: provider.loadAgents, child: const Text('重试')),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: provider.loadAgents,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTheme.pagePadding),
        itemCount: provider.agents.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (c, i) {
          final a = provider.agents[i];
          final isOnline = a.status != 'offline' && a.status != '未知';
          return FinanceCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.smart_toy,
                    color: isOnline ? AppTheme.bull : AppTheme.textSecondary,
                    size: 32),
                const SizedBox(width: 12),
                Expanded(child: Text(a.name, style: AppTheme.title)),
                StatusTag(
                  label: a.status,
                  type: isOnline ? StatusType.normal : StatusType.warning,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
