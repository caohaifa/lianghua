import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

/// 钱包充值/提现表单(模拟环境:充值直接入账,提现直接出账)
class WalletSheet extends StatefulWidget {
  final String type; // deposit / withdraw
  final String currency; // USDT / CNY
  final String coin; // 显示名称
  final VoidCallback? onDone;
  const WalletSheet({
    super.key,
    required this.type,
    required this.currency,
    required this.coin,
    this.onDone,
  });

  @override
  State<WalletSheet> createState() => _WalletSheetState();
}

class _WalletSheetState extends State<WalletSheet> {
  final _c = TextEditingController();
  final _addr = TextEditingController();
  /// 充值渠道(银行卡/支付宝等) 与 提现网络(TRC20/ERC20等) 独立存储
  String? _channel;
  String? _network;
  String? _error;
  bool _loading = false;

  static const _channels = ['银行卡', '支付宝', '微信支付', 'USDT-TRC20', 'USDT-ERC20'];
  static const _networks = ['TRC20', 'ERC20', 'OMNI'];

  @override
  void initState() {
    super.initState();
    _channel = _channels.first;
    _network = _networks.first;
  }

  @override
  void dispose() {
    _c.dispose();
    _addr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDeposit = widget.type == 'deposit';
    final accent = isDeposit ? AppTheme.bull : AppTheme.bear;
    final actionLabel = isDeposit ? '充值' : '提现';

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
                    color: accent),
                const SizedBox(width: 8),
                Text('$actionLabel ${widget.coin}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
                '${isDeposit ? '充值到' : '从'} ${widget.coin} 钱包${isDeposit ? '' : '扣除'}',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 16),
            // 金额
            SizedBox(
              height: 48,
              child: TextField(
                controller: _c,
                onChanged: (_) => setState(() => _error = null),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(
                    color: Colors.white, fontFamily: 'RobotoMono'),
                decoration: InputDecoration(
                  hintText: '$actionLabel数量(${widget.currency})',
                  fillColor: const Color(0xFF23282F),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 14, top: 13),
                    child: Text(widget.currency,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13)),
                  ),
                ),
              ),
            ),
            if (isDeposit) ...[
              const SizedBox(height: 14),
              const Text('充值渠道',
                  style:
                      TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final ch in _channels)
                    GestureDetector(
                      onTap: () => setState(() => _channel = ch),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: _channel == ch
                              ? AppTheme.brandPrimary.withValues(alpha: 0.15)
                              : const Color(0xFF23282F),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: _channel == ch
                                  ? AppTheme.brandPrimary
                                  : Colors.transparent),
                        ),
                        child: Text(ch,
                            style: TextStyle(
                                color: _channel == ch
                                    ? AppTheme.brandPrimary
                                    : AppTheme.textSecondary,
                                fontSize: 12)),
                      ),
                    ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 14),
              const Text('提现网络',
                  style:
                      TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final n in _networks)
                    GestureDetector(
                      onTap: () => setState(() => _network = n),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: _network == n
                              ? AppTheme.brandPrimary.withValues(alpha: 0.15)
                              : const Color(0xFF23282F),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: _network == n
                                  ? AppTheme.brandPrimary
                                  : Colors.transparent),
                        ),
                        child: Text(n,
                            style: TextStyle(
                                color: _network == n
                                    ? AppTheme.brandPrimary
                                    : AppTheme.textSecondary,
                                fontSize: 12)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 48,
                child: TextField(
                  controller: _addr,
                  style: const TextStyle(
                      color: Colors.white, fontFamily: 'RobotoMono'),
                  decoration: const InputDecoration(
                    hintText: '提现地址(选填,模拟环境)',
                    fillColor: Color(0xFF23282F),
                  ),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppTheme.bear)),
            ],
            const SizedBox(height: 18),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: accent),
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('确认$actionLabel',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 10),
            const Text('提示:当前为模拟环境,充值/提现即时到账,仅供体验交易流程',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          ],
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
    try {
      final path =
          widget.type == 'deposit' ? '/wallet/deposit' : '/wallet/withdraw';
      final body = <String, dynamic>{
        'currency': widget.currency,
        'amount': amount,
      };
      if (widget.type == 'deposit') {
        body['channel'] = _channel;
      } else {
        body['network'] = _network;
        if (_addr.text.trim().isNotEmpty) body['address'] = _addr.text.trim();
      }
      final res = await ApiClient().dio.post(path, data: body);
      final bal = res.data['data']['balance_after'] as num;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '${widget.type == 'deposit' ? '充值' : '提现'}成功,${widget.currency} 余额: ${bal.toStringAsFixed(2)}'),
        backgroundColor: const Color(0xFF1E2329),
        behavior: SnackBarBehavior.floating,
      ));
      widget.onDone?.call();
      Navigator.pop(context);
    } on DioException catch (e) {
      final msg = e.response?.data?['message']?.toString() ?? '操作失败,请稍后重试';
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
