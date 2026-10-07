import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../monitor/providers/copy_provider.dart';

/// 发布策略到广场弹层
class AiPublishSheet extends StatefulWidget {
  final int monitorId;
  final String symbol;
  final String strategy;
  final String initialTitle;
  final String initialDesc;
  final VoidCallback onDone;
  const AiPublishSheet({
    super.key,
    required this.monitorId,
    required this.symbol,
    required this.strategy,
    required this.initialTitle,
    required this.initialDesc,
    required this.onDone,
  });

  @override
  State<AiPublishSheet> createState() => _AiPublishSheetState();
}

class _AiPublishSheetState extends State<AiPublishSheet> {
  late final TextEditingController _titleC =
      TextEditingController(text: widget.initialTitle);
  late final TextEditingController _descC =
      TextEditingController(text: widget.initialDesc);
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _titleC.dispose();
    _descC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            const Text('发布策略到广场',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('${widget.symbol} · ${widget.strategy}',
                style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontFamily: 'RobotoMono')),
            const SizedBox(height: 18),
            const Text('策略标题',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: _titleC,
              maxLength: 50,
              style: const TextStyle(color: Colors.white),
              onChanged: (_) => setState(() => _error = null),
              decoration: const InputDecoration(
                hintText: '展示在策略广场的名称(50字内)',
                counterText: '',
              ),
            ),
            const SizedBox(height: 14),
            const Text('策略说明(选填)',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: _descC,
              maxLength: 200,
              minLines: 3,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              onChanged: (_) => setState(() => _error = null),
              decoration: const InputDecoration(
                hintText: '介绍策略逻辑、目标收益与风险(200字内)',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(Icons.verified_outlined,
                    size: 14, color: AppTheme.textTertiary),
                SizedBox(width: 6),
                Expanded(
                  child: Text('提交后需运营审核,通过后展示在策略广场',
                      style: TextStyle(
                          color: AppTheme.textTertiary, fontSize: 11)),
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
                onPressed: _submitting
                    ? null
                    : () async {
                        final title = _titleC.text.trim();
                        if (title.isEmpty) {
                          setState(() => _error = '请填写策略标题');
                          return;
                        }
                        setState(() => _submitting = true);
                        final err = await context.read<CopyProvider>().publish(
                            widget.monitorId, title, _descC.text.trim());
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
                    : const Text('提交审核',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
