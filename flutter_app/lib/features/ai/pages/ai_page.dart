import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../market/providers/market_provider.dart';
import '../../monitor/providers/copy_provider.dart';
import '../../monitor/providers/monitor_provider.dart';
import '../widgets/ai_create_sheet.dart';
import '../widgets/ai_publish_sheet.dart';
import '../widgets/ai_follow_sheet.dart';

/// AI 量化主页:累计收益 + 策略广场 + 我的策略
class AiPage extends StatefulWidget {
  const AiPage({super.key});

  @override
  State<AiPage> createState() => _AiPageState();
}

class _AiPageState extends State<AiPage> {
  Map<String, dynamic>? _summary;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MonitorProvider>().load();
      context.read<CopyProvider>().loadAll();
      context.read<CopyProvider>().fetchAlerts(); // 刷新告警未读数
      _fetchSummary();
    });
  }

  Future<void> _fetchSummary() async {
    try {
      final res = await ApiClient().dio.get('/ai/summary');
      if (mounted) {
        setState(() => _summary = Map<String, dynamic>.from(res.data['data']));
      }
    } catch (_) {}
  }

  Future<void> _refresh() async {
    final monitor = context.read<MonitorProvider>();
    final copy = context.read<CopyProvider>();
    await monitor.load();
    await copy.loadAll();
    await copy.fetchAlerts();
    await _fetchSummary();
  }

  /// 进入消息中心,返回后刷新未读数
  Future<void> _openAlerts() async {
    await context.push('/personal/alerts');
    if (!mounted) return;
    context.read<CopyProvider>().fetchAlerts();
  }

  /// 进入个人策略信号台
  void _openConsole(MonitorItem m) {
    context.push('/ai/personal-console', extra: {
      'id': m.id,
      'symbol': m.symbol,
      'strategy': m.strategy,
      'status': m.status,
    });
  }

  @override
  Widget build(BuildContext context) {
    final monitor = context.watch<MonitorProvider>();
    final copy = context.watch<CopyProvider>();
    final s = _summary;

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppTheme.brandPrimary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          SafeArea(bottom: false, child: _titleRow(copy)),
          const SizedBox(height: 14),
          _profitCard(s),
          const SizedBox(height: 20),
          _sectionHeader('策略广场'),
          ..._publishedSection(copy),
          const SizedBox(height: 20),
          _sectionHeader('我的策略', trailing: '(${monitor.monitors.length})'),
          if (monitor.monitors.isEmpty)
            _emptyStrategies()
          else
            ...monitor.monitors.map((m) => _MonitorTile(
                  item: m,
                  publishStatus: copy.publishStatusOf(m.id),
                  onPublish: () => _showPublishSheet(m),
                  onUnpublish: () => _confirmUnpublish(m),
                  onConsole:
                      m.strategy == '个人策略' ? () => _openConsole(m) : null,
                )),
          if (copy.follows.isNotEmpty) ...[
            const SizedBox(height: 20),
            _sectionHeader('我的跟单',
                trailing:
                    '(${copy.follows.where((f) => f.isActive).length}个跟单中)'),
            ...copy.follows.map(_followTile),
          ],
          const SizedBox(height: 16),
          const Center(
            child: Text('量化交易存在风险,历史收益不代表未来表现',
                style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _titleRow(CopyProvider copy) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const Text('AI 量化',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.brandPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('PRO',
                style: TextStyle(
                    color: AppTheme.brandPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
          ),
          const Spacer(),
          _bellButton(copy),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _showCreateSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.brandPrimary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.add, size: 15, color: AppTheme.onBrand),
                  SizedBox(width: 4),
                  Text('新建策略',
                      style: TextStyle(
                          color: AppTheme.onBrand,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 告警铃铛(未读数>0 显示角标)
  Widget _bellButton(CopyProvider copy) {
    final unread = copy.unreadAlerts;
    return GestureDetector(
      onTap: _openAlerts,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFF181A20),
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.divider, width: 0.5),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Center(
              child: Icon(Icons.notifications_none,
                  color: AppTheme.textPrimary, size: 19),
            ),
            if (unread > 0)
              Positioned(
                right: -3,
                top: -3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(minWidth: 15),
                  height: 15,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.bear,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(unread > 99 ? '99+' : '$unread',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _profitCard(Map<String, dynamic>? s) {
    final pnl = s == null ? 0.0 : (s['total_pnl'] as num).toDouble();
    final today = s == null ? 0.0 : (s['today_pnl'] as num).toDouble();
    final unrealized = s == null ? 0.0 : (s['unrealized_pnl'] as num?)?.toDouble() ?? 0.0;
    final color = pnl >= 0 ? AppTheme.brandPrimary : AppTheme.bear;
    final todayColor = today >= 0 ? AppTheme.bull : AppTheme.bear;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2B2608), Color(0xFF181A20)],
        ),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('累计收益(USDT)',
                  style:
                      TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: todayColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                    '今日 ${today >= 0 ? '+' : ''}\$${today.abs().toStringAsFixed(2)}',
                    style: TextStyle(
                        color: todayColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'RobotoMono')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('${pnl >= 0 ? '+' : ''}\$${pnl.abs().toStringAsFixed(2)}',
              style: TextStyle(
                  color: color,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'RobotoMono')),
          if (unrealized != 0) ...[
            const SizedBox(height: 4),
            Text(
                '浮动 ${unrealized >= 0 ? '+' : ''}\$${unrealized.abs().toStringAsFixed(2)}',
                style: TextStyle(
                    color: unrealized >= 0
                        ? AppTheme.bull.withValues(alpha: 0.7)
                        : AppTheme.bear.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'RobotoMono')),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              _miniStat('运行中', '${s?['running_strategies'] ?? '--'}'),
              _miniStat('胜率', '${s?['win_rate'] ?? '--'}%'),
              _miniStat('已了结', '${s?['closed_trades'] ?? '--'}笔'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'RobotoMono')),
        ],
      ),
    );
  }

  /// 策略广场:真实发布列表(后台审核通过),空态引导
  List<Widget> _publishedSection(CopyProvider copy) {
    if (copy.published.isEmpty) {
      return [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(vertical: 30),
          decoration: BoxDecoration(
            color: const Color(0xFF181A20),
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            border: Border.all(color: AppTheme.divider, width: 0.5),
          ),
          child: const Center(
            child: Text('暂无发布的策略\n创建监控后可在「我的策略」中申请发布',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ),
        ),
      ];
    }
    return copy.published
        .map((p) => _PublishedCard(
              data: p,
              followed:
                  copy.follows.any((f) => f.publishId == p.id && f.isActive),
              onFollow: () => _showFollowSheet(p),
            ))
        .toList();
  }

  void _showCreateSheet({String? preset}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181A20),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (c) => AiCreateSheet(
        preset: preset,
        onCreated: () {
          Navigator.pop(c);
          _refresh();
        },
      ),
    );
  }

  /// 发布自己的监控(已驳回/已下架时带出原信息重新提交)
  void _showPublishSheet(MonitorItem m) {
    final copy = context.read<CopyProvider>();
    MyPublish? existing;
    for (final p in copy.myPublishes) {
      if (p.monitorId == m.id) existing = p;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181A20),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (c) => AiPublishSheet(
        monitorId: m.id,
        symbol: m.symbol,
        strategy: m.strategy,
        initialTitle: existing?.title ?? '${m.strategy}·${m.symbol}',
        initialDesc: '',
        onDone: () {
          Navigator.pop(c);
          _toast('已发布,已展示在策略广场', AppTheme.bull);
          _refresh();
        },
      ),
    );
  }

  void _confirmUnpublish(MonitorItem m) {
    final copy = context.read<CopyProvider>();
    MyPublish? existing;
    for (final p in copy.myPublishes) {
      if (p.monitorId == m.id) existing = p;
    }
    if (existing == null) return;
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1E232B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('下架策略',
            style: TextStyle(color: Colors.white, fontSize: 17)),
        content: const Text('下架后将从策略广场移除,?现有跟单将停止复制',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('取消',
                  style: TextStyle(color: AppTheme.textSecondary))),
          TextButton(
              onPressed: () async {
                Navigator.pop(c);
                final err = await copy.unpublish(existing!.id);
                _toast(
                    err ?? '已下架', err == null ? AppTheme.bull : AppTheme.bear);
                if (err == null) _refresh();
              },
              child:
                  const Text('确认下架', style: TextStyle(color: AppTheme.bear))),
        ],
      ),
    );
  }

  void _showFollowSheet(PublishedStrategy p) {
    final copy = context.read<CopyProvider>();
    FollowItem? mine;
    for (final f in copy.follows) {
      if (f.publishId == p.id && f.isActive) mine = f;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181A20),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (c) => AiFollowSheet(
        publish: p,
        initialRatio: mine?.ratio,
        initialMode: mine?.mode,
        initialMultiplier: mine?.fixedMultiplier,
        onDone: () {
          Navigator.pop(c);
          _toast('跟单成功,该策略的买卖将按你的跟单模式自动复制', AppTheme.bull);
          _refresh();
        },
      ),
    );
  }

  Widget _followTile(FollowItem f) {
    final active = f.isActive;
    final paused = f.isPaused;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF181A20),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppTheme.divider, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 32,
            decoration: BoxDecoration(
              color: active ? AppTheme.brandPrimary : AppTheme.textTertiary,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(f.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                    ),
                    if (paused) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.brandPrimary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('已暂停',
                            style: TextStyle(
                                color: AppTheme.brandPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                    '${f.leaderName} · ${f.strategy} · ${f.modeText}'
                    '${active ? '' : (paused ? '' : ' · 已停止')}',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text('复制 ${f.tradeCount} 笔',
                        style: const TextStyle(
                            color: AppTheme.textTertiary, fontSize: 11)),
                    const SizedBox(width: 8),
                    Text(
                      '盈亏 ${f.totalPnl >= 0 ? '+' : ''}${moneyFmt(f.totalPnl)}',
                      style: TextStyle(
                          color:
                              f.totalPnl >= 0 ? AppTheme.bull : AppTheme.bear,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 暂停/恢复跟单
          if (active || paused)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: active ? '暂停跟单' : '恢复跟单',
              icon: Icon(
                active ? Icons.pause_circle_outline : Icons.play_circle_outline,
                color: AppTheme.textSecondary,
                size: 22,
              ),
              onPressed: () => _toggleFollow(f),
            ),
          GestureDetector(
            onTap: active ? () => _confirmStopFollow(f) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: active
                    ? AppTheme.bear.withValues(alpha: 0.12)
                    : const Color(0xFF23282F),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(active ? '取消跟单' : '已停止',
                  style: TextStyle(
                      color: active ? AppTheme.bear : AppTheme.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  /// 暂停/恢复跟单;失败 toast 错误信息
  Future<void> _toggleFollow(FollowItem f) async {
    final target = f.isActive ? 'paused' : 'active';
    final err =
        await context.read<CopyProvider>().setFollowStatus(f.id, target);
    if (!mounted) return;
    _toast(err ?? (target == 'paused' ? '已暂停跟单' : '已恢复跟单'),
        err == null ? AppTheme.bull : AppTheme.bear);
  }

  void _confirmStopFollow(FollowItem f) {
    final copy = context.read<CopyProvider>();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1E232B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('停止跟单',
            style: TextStyle(color: Colors.white, fontSize: 17)),
        content: Text('停止后将不再跟随「${f.title}」的自动交易」',
            style:
                const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('取消',
                  style: TextStyle(color: AppTheme.textSecondary))),
          TextButton(
              onPressed: () async {
                Navigator.pop(c);
                final err = await copy.stopFollow(f.id);
                _toast(err ?? '已停止跟单',
                    err == null ? AppTheme.bull : AppTheme.bear);
                if (err == null) _refresh();
              },
              child:
                  const Text('确认停止', style: TextStyle(color: AppTheme.bear))),
        ],
      ),
    );
  }

  void _toast(String msg, Color color) {
    if (msg.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 13)),
      backgroundColor: color,
      duration: const Duration(seconds: 2),
    ));
  }

  Widget _sectionHeader(String title,
      {String? trailing, String? action, VoidCallback? onAction}) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 10),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            Text(trailing,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13)),
          ],
          const Spacer(),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action,
                  style: const TextStyle(
                      color: AppTheme.brandPrimary, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _emptyStrategies() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(vertical: 36),
      decoration: BoxDecoration(
        color: const Color(0xFF181A20),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppTheme.divider, width: 0.5),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.auto_graph,
                color: AppTheme.textSecondary, size: 40),
            const SizedBox(height: 10),
            const Text('还没有运行中的策略',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _showCreateSheet,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.brandPrimary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('立即新建',
                  style: TextStyle(color: AppTheme.brandPrimary)),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════ 策略广场 ══════════════════
/// 策略广场卡片:主题色/广场/监控/跟单条共用
Color strategyColor(String strategy) {
  switch (strategy) {
    case '网格区间':
      return AppTheme.bull;
    case '趋势追踪':
      return AppTheme.bear;
    default:
      return AppTheme.brandPrimary;
  }
}

/// 策略广场发布卡:后台审核通过后才出现在广场
class _PublishedCard extends StatelessWidget {
  final PublishedStrategy data;
  final bool followed;
  final VoidCallback onFollow;
  const _PublishedCard(
      {required this.data, required this.followed, required this.onFollow});

  @override
  Widget build(BuildContext context) {
    final accent = strategyColor(data.strategy);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF181A20),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppTheme.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(data.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(data.strategy,
                    style: TextStyle(
                        color: accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          if (data.description.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(data.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.person_outline,
                  color: AppTheme.textTertiary, size: 14),
              const SizedBox(width: 4),
              Flexible(
                child: Text('${data.leaderName} · ${data.symbol}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontFamily: 'RobotoMono')),
              ),
              if (followed)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.bull.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('跟单中',
                      style: TextStyle(
                          color: AppTheme.bull,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
              const Spacer(),
              if (data.isBot)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.brandPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.bolt, color: AppTheme.brandPrimary, size: 11),
                    Text('机器人',
                        style: TextStyle(
                            color: AppTheme.brandPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              Text('${data.followers} 人跟单',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onFollow,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppTheme.brandPrimary,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(followed ? '调比例' : '跟单',
                      style: const TextStyle(
                          color: AppTheme.onBrand,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════ 我的策略(监控) ══════════════════
class _MonitorTile extends StatelessWidget {
  final MonitorItem item;
  final String? publishStatus; // null=未发布
  final VoidCallback onPublish;
  final VoidCallback onUnpublish;
  final VoidCallback? onConsole; // 个人策略:进入信号台
  const _MonitorTile({
    required this.item,
    required this.publishStatus,
    required this.onPublish,
    required this.onUnpublish,
    this.onConsole,
  });

  Color get _strategyColor => strategyColor(item.strategy);

  /// 发布状态: chip 文案与配色
  (String, Color, Color) get _publishChip {
    switch (publishStatus) {
      case 'pending':
        return ('审核中', AppTheme.textSecondary, const Color(0xFF23282F));
      case 'published':
        return ('已发布', AppTheme.bull, AppTheme.bull.withValues(alpha: 0.12));
      case 'rejected':
        return ('被驳回', AppTheme.bear, AppTheme.bear.withValues(alpha: 0.12));
      case 'offline':
        return ('已下架', AppTheme.textSecondary, const Color(0xFF23282F));
      default:
        return (
          '发布',
          AppTheme.brandPrimary,
          AppTheme.brandPrimary.withValues(alpha: 0.12)
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final market = context.read<MarketProvider>();
    final quote =
        market.quotes.where((q) => q.symbol == item.symbol).firstOrNull;
    final running = item.isRunning;
    final chip = _publishChip;

    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      onTap: () => context.push('/monitor/detail', extra: {
        'symbol': item.symbol,
        'strategy': item.strategy,
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        decoration: BoxDecoration(
          color: const Color(0xFF181A20),
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          border: Border.all(color: AppTheme.divider, width: 0.5),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _strategyColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.symbol,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text('${item.strategy} · ${item.signal}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                if (quote != null)
                  Text(
                      '${quote.change >= 0 ? '+' : ''}${quote.change.toStringAsFixed(2)}%',
                      style: TextStyle(
                          color:
                              quote.change >= 0 ? AppTheme.bull : AppTheme.bear,
                          fontSize: 13,
                          fontFamily: 'RobotoMono')),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => context.read<MonitorProvider>().toggle(item),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: running
                          ? AppTheme.bull.withValues(alpha: 0.12)
                          : const Color(0xFF23282F),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(running ? '运行中' : '已暂停',
                        style: TextStyle(
                            color: running
                                ? AppTheme.bull
                                : AppTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 发布卡说明 + (个人策略信号台入口 + 发布状态操作)
            Row(
              children: [
                Expanded(
                  child: Text(
                      onConsole != null
                          ? '人工下发开/平仓信号,跟单者自动复制'
                          : (publishStatus == null
                              ? '发布到策略广场,他人可跟单'
                              : '广场发布状态如有变,点击管理'),
                      style: const TextStyle(
                          color: AppTheme.textTertiary, fontSize: 11)),
                ),
                if (onConsole != null) ...[
                  GestureDetector(
                    onTap: onConsole,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.brandPrimary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.campaign,
                              color: AppTheme.onBrand, size: 12),
                          SizedBox(width: 3),
                          Text('信号台',
                              style: TextStyle(
                                  color: AppTheme.onBrand,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                GestureDetector(
                  onTap: publishStatus == 'published'
                      ? onUnpublish
                      : (publishStatus == 'pending' ? null : onPublish),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: chip.$3,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(chip.$1,
                        style: TextStyle(
                            color: chip.$2,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

