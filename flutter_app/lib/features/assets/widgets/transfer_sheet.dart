import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../futures/providers/futures_provider.dart';
import '../../position/providers/position_provider.dart';

/// 现货 ↔ 合约 USDT 划转弹层(资产页/资产详情页/合约页共用)
/// 成功后回调 [onDone](调用方据此刷新现货账户等)。
class TransferSheet extends StatefulWidget {
  final VoidCallback? onDone;
  const TransferSheet({super.key, this.onDone});

  /// 统一样式的弹出入口
  static Future<void> show(BuildContext context, {VoidCallback? onDone}) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181A20),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (c) => SafeArea(child: TransferSheet(onDone: onDone)),
    );
  }

  @override
  State<TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<TransferSheet> {
  final _c = TextEditingController();
  bool _in = true; // true=现货→合约
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final futures = context.watch<FuturesProvider>();
    final spot = context.watch<PositionProvider>().account?.available;
    final futuresAvail = futures.account?.available;
    // 转出方可用余额
    final srcAvail = _in ? spot : futuresAvail;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('资金划转',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                _dirTab('现货 → 合约', _in),
                const SizedBox(width: 10),
                _dirTab('合约 → 现货', !_in),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 46,
              child: TextField(
                controller: _c,
                onChanged: (_) => setState(() => _error = null),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(
                    color: Colors.white, fontFamily: 'RobotoMono'),
                decoration: InputDecoration(
                  hintText: '划转数量(USDT)',
                  fillColor: const Color(0xFF23282F),
                  suffixIcon: GestureDetector(
                    onTap: srcAvail == null
                        ? null
                        : () => setState(
                            () => _c.text = srcAvail.toStringAsFixed(2)),
                    child: const Padding(
                      padding: EdgeInsets.only(right: 14, top: 13),
                      child: Text('全部',
                          style: TextStyle(
                              color: AppTheme.brandPrimary, fontSize: 13)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('现货可用 ${srcAvailText(spot)}',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
                const Spacer(),
                Text('合约可用 ${srcAvailText(futuresAvail)}',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppTheme.bear)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 46,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('确认划转',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String srcAvailText(double? v) => v == null ? '--' : '\$${moneyFmt(v)}';

  Widget _dirTab(String label, bool on) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _in = label.startsWith('现货');
          _error = null;
        }),
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on
                ? AppTheme.brandPrimary.withValues(alpha: 0.15)
                : const Color(0xFF23282F),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: on ? AppTheme.brandPrimary : Colors.transparent),
          ),
          child: Text(label,
              style: TextStyle(
                  color: on ? AppTheme.brandPrimary : AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_c.text) ?? 0;
    if (amount <= 0) {
      setState(() => _error = '请输入有效金额');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final err =
        await context.read<FuturesProvider>().transfer(_in ? 'in' : 'out', amount);
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      setState(() => _error = err);
    } else {
      widget.onDone?.call();
      Navigator.pop(context);
    }
  }
}
