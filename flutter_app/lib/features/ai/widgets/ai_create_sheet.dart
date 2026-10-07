import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../market/providers/market_provider.dart';
import '../../monitor/providers/monitor_provider.dart';

/// 新建策略监控弹层:选标的 + 选策略
class AiCreateSheet extends StatefulWidget {
  final String? preset;
  final VoidCallback onCreated;
  const AiCreateSheet({super.key, this.preset, required this.onCreated});

  @override
  State<AiCreateSheet> createState() => _AiCreateSheetState();
}

class _AiCreateSheetState extends State<AiCreateSheet> {
  String? _symbol;
  late String _strategy;
  String? _error;
  int _marketTab = 0; // 0=加密货币 1=A股
  bool _expandSymbols = false;
  static const _collapsedCount = 12;

  @override
  void initState() {
    super.initState();
    final preset = widget.preset;
    _strategy = MonitorProvider.strategies.contains(preset)
        ? preset!
        : MonitorProvider.strategies.first;
  }

  Widget _symbolChips(List<Quote> list) {
    if (list.isEmpty) {
      return const Text('暂无标的',
          style: TextStyle(color: AppTheme.textTertiary, fontSize: 12));
    }
    final shown = _expandSymbols ? list : list.take(_collapsedCount).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final q in shown)
              GestureDetector(
                onTap: () => setState(() => _symbol = q.symbol),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _symbol == q.symbol
                        ? AppTheme.brandPrimary
                        : const Color(0xFF23282F),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                      q.symbol.contains('/')
                          ? q.symbol.split('/').first
                          : q.symbol,
                      style: TextStyle(
                          color: _symbol == q.symbol
                              ? AppTheme.onBrand
                              : AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ),
          ],
        ),
        if (list.length > _collapsedCount) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => setState(() => _expandSymbols = !_expandSymbols),
            child: Text(_expandSymbols ? '收起 ▴' : '展开全部 ${list.length} 个 ▾',
                style: const TextStyle(
                    color: AppTheme.textTertiary, fontSize: 12)),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final quotes = context.watch<MarketProvider>().quotes;
    final crypto = quotes.where((q) => q.market == 'crypto').toList()
      ..sort((a, b) => b.quoteVol.compareTo(a.quoteVol));
    final ashare = quotes.where((q) => q.market == 'a-share').toList()
      ..sort((a, b) => a.symbol.compareTo(b.symbol));
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 14, 20,
            math.max(96, 28 + MediaQuery.of(context).viewInsets.bottom)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Center(
              child: SizedBox(
                  width: 40,
                  child: Divider(thickness: 3, color: Color(0xFF5E6673))),
            ),
            const SizedBox(height: 16),
            const Text('新建策略监控',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text('选择交易标的与策略类型,AI 将自动盯盘并提示信号',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 18),
            Row(
              children: [
                const Text('选择标的',
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                const Spacer(),
                if (_symbol != null)
                  Text('已选 $_symbol',
                      style: const TextStyle(
                          color: AppTheme.brandPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (var i = 0; i < 2; i++)
                  GestureDetector(
                    onTap: () => setState(() {
                      _marketTab = i;
                      _expandSymbols = false;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: _marketTab == i
                            ? AppTheme.brandPrimary.withValues(alpha: 0.15)
                            : const Color(0xFF23282F),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _marketTab == i
                                ? AppTheme.brandPrimary
                                : Colors.transparent,
                            width: 1),
                      ),
                      child: Text(i == 0 ? '加密货币' : 'A股',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: _marketTab == i
                                  ? AppTheme.brandPrimary
                                  : AppTheme.textSecondary)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _symbolChips(_marketTab == 0 ? crypto : ashare),
            const SizedBox(height: 18),
            const Text('选择策略',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final st in MonitorProvider.strategies)
                  ChoiceChip(
                    label: Text(st),
                    selected: _strategy == st,
                    selectedColor: AppTheme.brandPrimary,
                    backgroundColor: const Color(0xFF23282F),
                    labelStyle: TextStyle(
                        color: _strategy == st
                            ? AppTheme.onBrand
                            : AppTheme.textSecondary,
                        fontSize: 12),
                    onSelected: (_) => setState(() => _strategy = st),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.bear.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppTheme.bear, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              color: AppTheme.bear, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              height: 46,
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brandPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                onPressed: () async {
                  if (_symbol == null) {
                    setState(() => _error = '请选择标的');
                    return;
                  }
                  final err = await context
                      .read<MonitorProvider>()
                      .create(_symbol!, _strategy);
                  if (err != null) {
                    setState(() => _error = err);
                  } else {
                    widget.onCreated();
                  }
                },
                child: const Text('确认创建',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
