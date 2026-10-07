import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../monitor/providers/copy_provider.dart';
import '../../monitor/providers/monitor_provider.dart';

/// 个人策略信号台:主交易员人工下发开多/加仓/部分平仓/全部平仓/开空信号,
/// 跟单者按跟单模式自动复制(全局风控暂停或监控暂停时后端拒绝下发)。
class PersonalConsolePage extends StatefulWidget {
  final int monitorId;
  final String symbol;
  final String strategy;
  final String status; // running/paused
  const PersonalConsolePage({
    super.key,
    required this.monitorId,
    required this.symbol,
    required this.strategy,
    this.status = 'running',
  });

  @override
  State<PersonalConsolePage> createState() => _PersonalConsolePageState();
}

class _PersonalConsolePageState extends State<PersonalConsolePage> {
  final _amountC = TextEditingController(); // 开多/加仓数量
  final _ratioC = TextEditingController(); // 部分平仓比例%
  final _shortAmountC = TextEditingController(); // 开空数量
  final _levC = TextEditingController(text: '5'); // 开空杠杆
  bool _sending = false;

  bool get _running => widget.status == 'running';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MonitorProvider>().fetchDetail(widget.monitorId);
      context.read<CopyProvider>().fetchSignals(widget.monitorId);
    });
  }

  @override
  void dispose() {
    _amountC.dispose();
    _ratioC.dispose();
    _shortAmountC.dispose();
    _levC.dispose();
    super.dispose();
  }

  /// 确认对话框(显示动作与参数);返回是否确认
  Future<bool> _confirm(String actionName, String params) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1E232B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('确认$actionName',
            style: const TextStyle(color: Colors.white, fontSize: 17)),
        content: Text('${widget.symbol}\n$params\n\n确认后信号将下发给全部跟单者自动复制。',
            style:
                const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('取消',
                  style: TextStyle(color: AppTheme.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text('确认$actionName',
                  style: TextStyle(
                      color: actionName.contains('平仓') || actionName == '开空'
                          ? AppTheme.bear
                          : AppTheme.bull))),
        ],
      ),
    );
    return ok ?? false;
  }

  /// 下发信号:确认 → 请求 → 结果提示 → 刷新历史
  Future<void> _send(String action, String actionName, String params,
      {double? amount, int? ratioPct, int? leverage}) async {
    if (_sending) return;
    final copy = context.read<CopyProvider>();
    if (!await _confirm(actionName, params)) return;
    if (!mounted) return;
    setState(() => _sending = true);
    final r = await copy.sendSignal(
      widget.monitorId,
      action,
      amount: amount,
      ratioPct: ratioPct,
      leverage: leverage,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (r.ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('信号已下发 · 执行 ${r.executed} · 跳过 ${r.skipped}',
            style: const TextStyle(fontSize: 13)),
        backgroundColor: AppTheme.bull,
        duration: const Duration(seconds: 2),
      ));
      copy.fetchSignals(widget.monitorId);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(r.error ?? '下发失败', style: const TextStyle(fontSize: 13)),
        backgroundColor: AppTheme.bear,
        duration: const Duration(seconds: 2),
      ));
    }
  }

  // ══════════════ 动作入口(含客户端参数校验) ══════════════

  void _openOrAdd(String action, String actionName) {
    final amount = double.tryParse(_amountC.text.trim());
    if (amount == null || amount <= 0) {
      _toast('请输入大于 0 的数量', AppTheme.bear);
      return;
    }
    _send(action, actionName, '数量 ${amountFmt(amount)}', amount: amount);
  }

  void _partialClose() {
    final pct = int.tryParse(_ratioC.text.trim());
    if (pct == null || pct < 1 || pct > 99) {
      _toast('部分平仓比例需在 1-99', AppTheme.bear);
      return;
    }
    _send('partial_close', '部分平仓', '平仓比例 $pct%', ratioPct: pct);
  }

  void _closeAll() {
    _send('close_all', '全部平仓', '平掉该标的全部持仓');
  }

  void _openShort() async {
    final amount = double.tryParse(_shortAmountC.text.trim());
    final lev = int.tryParse(_levC.text.trim());
    if (amount == null || amount <= 0) {
      _toast('请输入大于 0 的数量', AppTheme.bear);
      return;
    }
    if (lev == null || lev < 1 || lev > 125) {
      _toast('杠杆需在 1-125 倍之间', AppTheme.bear);
      return;
    }
    // 开空预检:检查冲突持仓
    final preCheck = await context.read<CopyProvider>().preCheckShort(widget.monitorId);
    if (!mounted) return;
    if (preCheck['canShort'] != true) {
      _toast(preCheck['warning']?.toString() ?? '存在冲突持仓,无法开空', AppTheme.bear);
      return;
    }
    final warning = preCheck['warning']?.toString() ?? '';
    final params = '数量 ${amountFmt(amount)} · 杠杆 $lev 倍'
        '${warning.isNotEmpty ? '\n$warning' : ''}';
    _send('open_short', '开空', params, amount: amount, leverage: lev);
  }

  void _toast(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 13)),
      backgroundColor: color,
      duration: const Duration(seconds: 2),
    ));
  }

  // ══════════════ UI ══════════════

  @override
  Widget build(BuildContext context) {
    final copy = context.watch<CopyProvider>();
    final monitor = context.watch<MonitorProvider>();
    final running = _running;
    return Scaffold(
      appBar: AppBar(title: const Text('个人策略信号台')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoCard(running),
              const SizedBox(height: 16),
              _paramsCard(monitor.detail),
              const SizedBox(height: 16),
              _opsCard(running),
              const SizedBox(height: 16),
              _historyCard(copy.signals),
            ],
          ),
        ),
      ),
    );
  }

  /// 顶部信息卡:标的、策略名、运行状态
  Widget _infoCard(bool running) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF181A20),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppTheme.divider, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.brandPrimary,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.symbol,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'RobotoMono')),
                const SizedBox(height: 4),
                Text(widget.strategy,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: running
                  ? AppTheme.bull.withValues(alpha: 0.12)
                  : const Color(0xFF23282F),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(running ? '运行中' : '已暂停',
                style: TextStyle(
                    color: running ? AppTheme.bull : AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  /// 策略参数卡:键值对展示 + 编辑入口(策略规则全人工定义)
  Widget _paramsCard(MonitorItem? detail) {
    final params = detail?.paramsMap ?? const <String, String>{};
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
              const Expanded(
                child: Text('策略参数',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
              GestureDetector(
                onTap: _openParamsEditor,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.brandPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Text('编辑参数',
                      style: TextStyle(
                          color: AppTheme.brandPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('策略规则全部人工定义,参数由你自由填写',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
          const SizedBox(height: 12),
          if (params.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFF23282F),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('未设置参数,点击「编辑参数」自定义',
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ),
            )
          else
            ...params.entries.map(_paramRow),
        ],
      ),
    );
  }

  Widget _paramRow(MapEntry<String, String> e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF23282F),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(e.key,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12)),
          ),
          Expanded(
            flex: 3,
            child: Text(e.value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontFamily: 'RobotoMono')),
          ),
        ],
      ),
    );
  }

  /// 打开参数编辑弹层;保存后调接口写回
  Future<void> _openParamsEditor() async {
    final initial = context.read<MonitorProvider>().detail?.paramsMap ??
        const <String, String>{};
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ParamEditSheet(initial: initial),
    );
    if (result == null || !mounted) return;
    final err = await context
        .read<MonitorProvider>()
        .updateParams(widget.monitorId, result);
    if (!mounted) return;
    _toast(err ?? '参数已保存', err == null ? AppTheme.bull : AppTheme.bear);
  }

  /// 信号操作区卡片
  Widget _opsCard(bool running) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF181A20),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppTheme.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('信号操作',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('信号实时下发给跟单者,按其跟单模式自动换算仓位',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
          if (!running) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.bear.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('监控已暂停,请先在 AI 页恢复运行再下发信号',
                  style: TextStyle(color: AppTheme.bear, fontSize: 12)),
            ),
          ],
          const SizedBox(height: 14),
          // 开多 / 加仓
          _rowLabel('开多 / 加仓'),
          Row(
            children: [
              Expanded(child: _numField(_amountC, '数量', enabled: running)),
              const SizedBox(width: 10),
              _pillButton('开多', AppTheme.bull,
                  solid: true,
                  enabled: running,
                  onTap: () => _openOrAdd('open_long', '开多')),
              const SizedBox(width: 8),
              _pillButton('加仓', AppTheme.bull,
                  enabled: running, onTap: () => _openOrAdd('add_long', '加仓')),
            ],
          ),
          const SizedBox(height: 16),
          // 部分平仓
          _rowLabel('部分平仓'),
          Row(
            children: [
              for (final pct in const [25, 50, 75]) ...[
                GestureDetector(
                  onTap: running
                      ? () => setState(() => _ratioC.text = '$pct')
                      : null,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: _ratioC.text == '$pct'
                          ? AppTheme.brandPrimary
                          : const Color(0xFF23282F),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text('$pct%',
                        style: TextStyle(
                            color: _ratioC.text == '$pct'
                                ? AppTheme.onBrand
                                : AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: _numField(_ratioC, '自定义%',
                    enabled: running,
                    integer: true,
                    onChanged: (_) => setState(() {})),
              ),
              const SizedBox(width: 10),
              _pillButton('部分平仓', AppTheme.bear,
                  enabled: running, onTap: _partialClose),
            ],
          ),
          const SizedBox(height: 12),
          // 全部平仓
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.bear,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: running && !_sending ? _closeAll : null,
              child: const Text('全部平仓',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 16),
          // 开空(合约)
          _rowLabel('开空(合约)'),
          Row(
            children: [
              Expanded(child: _numField(_shortAmountC, '数量', enabled: running)),
              const SizedBox(width: 8),
              SizedBox(
                width: 76,
                child: _numField(_levC, '杠杆', enabled: running, integer: true),
              ),
              const SizedBox(width: 10),
              _pillButton('开空', AppTheme.bear,
                  solid: true, enabled: running, onTap: _openShort),
            ],
          ),
          const SizedBox(height: 6),
          const Text('开空自动平掉现货多头;杠杆 1-125,默认 5 倍',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _rowLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
    );
  }

  Widget _numField(TextEditingController c, String hint,
      {bool enabled = true,
      bool integer = false,
      ValueChanged<String>? onChanged}) {
    return TextField(
      controller: c,
      enabled: enabled,
      onChanged: onChanged,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true, signed: false),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
      ],
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        counterText: '',
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      ),
    );
  }

  Widget _pillButton(String label, Color color,
      {bool solid = false, bool enabled = true, VoidCallback? onTap}) {
    // solid 实心:红底白字(卖出),绿底深字(买入);非实心为彩色描边样式
    final fg = solid
        ? (color == AppTheme.bear ? Colors.white : AppTheme.onBrand)
        : color;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: enabled
              ? (solid ? color : color.withValues(alpha: 0.12))
              : const Color(0xFF23282F),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
              color: enabled && !solid ? color : Colors.transparent, width: 1),
        ),
        child: Text(label,
            style: TextStyle(
                color: enabled ? fg : AppTheme.textTertiary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  /// 信号历史列表卡
  Widget _historyCard(List<PersonalSignalItem> signals) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF181A20),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppTheme.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('信号历史',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (signals.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('暂无信号',
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ),
            )
          else
            ...signals.map(_signalTile),
        ],
      ),
    );
  }

  Widget _signalTile(PersonalSignalItem s) {
    final isOpen = s.action == 'open_long' || s.action == 'add_long';
    final color = isOpen ? AppTheme.bull : AppTheme.bear;
    final params = <String>[
      if (s.amount != null) '数量 ${amountFmt(s.amount!)}',
      if (s.ratioPct != null) '比例 ${s.ratioPct}%',
      if (s.leverage != null) '${s.leverage} 倍',
    ].join(' · ');
    final time = s.createdAt.length >= 16
        ? s.createdAt.substring(5, 16).replaceAll('T', ' ')
        : s.createdAt;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF23282F),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 14,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(s.actionName,
                  style: TextStyle(
                      color: color, fontSize: 13, fontWeight: FontWeight.w600)),
              if (params.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(params,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontFamily: 'RobotoMono')),
                ),
              ] else
                const Spacer(),
              Text(time,
                  style: const TextStyle(
                      color: AppTheme.textTertiary, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
              '执行 ${s.okCount} · 跳过 ${s.skipCount}'
              '${s.detail.isEmpty ? '' : ' · ${s.detail}'}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
        ],
      ),
    );
  }
}

/// 参数行的一对输入控制器
class _ParamRowCtl {
  final TextEditingController key;
  final TextEditingController value;
  _ParamRowCtl([String k = '', String v = ''])
      : key = TextEditingController(text: k),
        value = TextEditingController(text: v);
  void dispose() {
    key.dispose();
    value.dispose();
  }
}

/// 策略参数编辑弹层:动态键值对增删改;保存返回 Map(取消返回 null)
class _ParamEditSheet extends StatefulWidget {
  final Map<String, String> initial;
  const _ParamEditSheet({required this.initial});
  @override
  State<_ParamEditSheet> createState() => _ParamEditSheetState();
}

class _ParamEditSheetState extends State<_ParamEditSheet> {
  final List<_ParamRowCtl> _rows = [];

  @override
  void initState() {
    super.initState();
    _rows.addAll(
        widget.initial.entries.map((e) => _ParamRowCtl(e.key, e.value)));
    if (_rows.isEmpty) _rows.add(_ParamRowCtl());
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _toast(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 13)),
      backgroundColor: color,
      duration: const Duration(seconds: 2),
    ));
  }

  void _save() {
    final map = <String, String>{};
    for (final r in _rows) {
      final k = r.key.text.trim();
      final v = r.value.text.trim();
      if (k.isEmpty && v.isEmpty) continue; // 空行跳过
      if (k.isEmpty) {
        _toast('参数名不能为空', AppTheme.bear);
        return;
      }
      if (k.length > 30) {
        _toast('参数名「$k」超过 30 字符', AppTheme.bear);
        return;
      }
      if (v.length > 200) {
        _toast('「$k」的值超过 200 字符', AppTheme.bear);
        return;
      }
      if (map.containsKey(k)) {
        _toast('参数名「$k」重复', AppTheme.bear);
        return;
      }
      map[k] = v;
    }
    Navigator.pop(context, map);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF181A20),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('编辑策略参数',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close,
                            color: AppTheme.textSecondary, size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('参数名与参数值自由填写,如:网格间距 / 2%、止损线 / -5%',
                    style:
                        TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
                const SizedBox(height: 12),
                ..._rows.asMap().entries.map((e) => _row(e.key, e.value)),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => setState(() => _rows.add(_ParamRowCtl())),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: AppTheme.brandPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppTheme.brandPrimary.withValues(alpha: 0.4),
                          width: 1),
                    ),
                    child: const Center(
                      child: Text('＋ 添加参数',
                          style: TextStyle(
                              color: AppTheme.brandPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brandPrimary,
                      foregroundColor: AppTheme.onBrand,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _save,
                    child: const Text('保存参数',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(int index, _ParamRowCtl r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF23282F),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: r.key,
              maxLength: 30,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                hintText: '参数名',
                counterText: '',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: TextField(
              controller: r.value,
              maxLength: 200,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                hintText: '参数值',
                counterText: '',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _rows.removeAt(index)),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.delete_outline,
                  color: AppTheme.textSecondary, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
