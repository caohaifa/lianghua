import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../monitor/providers/copy_provider.dart';
import '../pages/ai_page.dart';

/// 跟单确认表单弹层
class AiFollowSheet extends StatefulWidget {
  final PublishedStrategy publish;
  final int? initialRatio;
  final String? initialMode;
  final double? initialMultiplier;
  final VoidCallback onDone;
  const AiFollowSheet({
    super.key,
    required this.publish,
    this.initialRatio,
    this.initialMode,
    this.initialMultiplier,
    required this.onDone,
  });

  @override
  State<AiFollowSheet> createState() => _AiFollowSheetState();
}

class _AiFollowSheetState extends State<AiFollowSheet> {
  late int _ratio = widget.initialRatio ?? 10;
  late String _mode = widget.initialMode ?? 'ratio';
  late final TextEditingController _mulC =
      TextEditingController(text: widget.initialMultiplier?.toString() ?? '1');
  String? _error;
  bool _submitting = false;
  static const _ratios = [10, 25, 50, 100];
  static const _modes = [
    ('ratio', '固定比例'),
    ('balance', '本金比例'),
    ('fixed', '固定倍数')
  ];

  @override
  void dispose() {
    _mulC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.publish;
    final accent = strategyColor(p.strategy);
    final modifying = widget.initialRatio != null;
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
            Text(modifying ? '调整跟单' : '确认跟单',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text('该策略的每次买卖将按你的跟单模式自动复制到你的账户',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF23282F),
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
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
                          color: accent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(p.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                      ),
                      Text(p.strategy,
                          style: TextStyle(
                              color: accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('${p.leaderName} · ${p.symbol}',
                      style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontFamily: 'RobotoMono')),
                  if (p.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(p.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text('跟单模式',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (key, label) in _modes)
                  GestureDetector(
                    onTap: () => setState(() {
                      _mode = key;
                      _error = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _mode == key
                            ? AppTheme.brandPrimary
                            : const Color(0xFF23282F),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                            color: _mode == key
                                ? AppTheme.brandPrimary
                                : Colors.transparent,
                            width: 1),
                      ),
                      child: Text(label,
                          style: TextStyle(
                              color: _mode == key
                                  ? AppTheme.onBrand
                                  : AppTheme.textSecondary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (_mode == 'ratio') ...[
              const Text('跟单比例',
                  style:
                      TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final r in _ratios)
                    GestureDetector(
                      onTap: () => setState(() => _ratio = r),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 9),
                        decoration: BoxDecoration(
                          color: _ratio == r
                              ? AppTheme.brandPrimary
                              : const Color(0xFF23282F),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                              color: _ratio == r
                                  ? AppTheme.brandPrimary
                                  : Colors.transparent,
                              width: 1),
                        ),
                        child: Text('$r%',
                            style: TextStyle(
                                color: _ratio == r
                                    ? AppTheme.onBrand
                                    : AppTheme.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              const Text('买入按名义额×比例折算(不足 5 USDT 跳过);卖出直接平掉你在该标的多仓',
                  style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
            ] else if (_mode == 'balance') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF23282F),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('按双方可用资金比例实时换算,无需设置参数',
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ),
            ] else ...[
              const Text('跟单倍数(0.1-10)',
                  style:
                      TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: _mulC,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                onChanged: (_) => setState(() => _error = null),
                decoration: const InputDecoration(hintText: '如 0.5 表示半仓跟随'),
              ),
              const SizedBox(height: 10),
              const Text('按主交易员每笔下单数量×倍数开仓(0.1-10 倍)',
                  style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
            ],
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
                onPressed: _submitting
                    ? null
                    : () async {
                        double? multiplier;
                        if (_mode == 'fixed') {
                          final m = double.tryParse(_mulC.text.trim());
                          if (m == null || m < 0.1 || m > 10) {
                            setState(() => _error = '固定倍数需在 0.1-10 之间');
                            return;
                          }
                          multiplier = m;
                        }
                        setState(() => _submitting = true);
                        final err = await context.read<CopyProvider>().follow(
                            widget.publish.id, _ratio,
                            mode: _mode, multiplier: multiplier);
                        if (!mounted) return;
                        if (err != null) {
                          setState(() {
                            _error = err;
                            _submitting = false;
                          });
                        } else {
                          widget.onDone();
                        }
                      },
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.onBrand))
                    : Text(modifying ? '确认修改' : '确认跟单',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
