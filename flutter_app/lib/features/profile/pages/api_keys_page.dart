import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/finance_card.dart';
import '../../../core/ui/status_tag.dart';

/// API Key 管理:绑定/查看/删除交易所凭据(secret 只入不出,列表脱敏展示)
class ApiKeysPage extends StatefulWidget {
  const ApiKeysPage({super.key});

  @override
  State<ApiKeysPage> createState() => _ApiKeysPageState();
}

class _ApiKeysPageState extends State<ApiKeysPage> {
  List<Map<String, dynamic>> _keys = [];
  bool _loading = true;
  String? _error;

  Dio get _dio => ApiClient().dio;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _dio.get('/api-keys');
      setState(() =>
          _keys = (res.data['data'] as List).cast<Map<String, dynamic>>());
    } catch (e) {
      setState(() => _error = _errMsg(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  String _errMsg(Object e) {
    if (e is DioException && e.response?.data is Map) {
      return e.response!.data['message']?.toString() ?? '请求失败';
    }
    return '网络异常,请稍后再试';
  }

  Future<void> _delete(int id) async {
    try {
      await _dio.delete('/api-keys/$id');
      _toast('已删除');
      _load();
    } catch (e) {
      _toast(_errMsg(e));
    }
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Key 管理'),
        actions: [
          IconButton(
              onPressed: () => showDialog(
                  context: context, builder: (_) => _BindDialog(onDone: _load)),
              icon: const Icon(Icons.add, color: AppTheme.textSecondary)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!, style: AppTheme.caption),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _load, child: const Text('重试')),
                ]))
              : _keys.isEmpty
                  ? const Center(
                      child:
                          Text('暂未绑定交易所,点右上角 + 绑定', style: AppTheme.caption))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(AppTheme.pagePadding),
                        itemCount: _keys.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (c, i) {
                          final k = _keys[i];
                          final isBinance = k['exchange'] == 'binance';
                          return FinanceCard(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      AppTheme.brandPrimary.withValues(alpha: 0.15),
                                  child: const Icon(Icons.currency_exchange,
                                      color: AppTheme.brandPrimary),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(isBinance ? '币安 Binance' : 'OKX',
                                          style: AppTheme.title),
                                      Text('Key: ${k['api_key_masked']}',
                                          style: AppTheme.caption),
                                    ],
                                  ),
                                ),
                                StatusTag(
                                    label: k['status'] == 0 ? '启用中' : '已停用',
                                    type: k['status'] == 0
                                        ? StatusType.normal
                                        : StatusType.warning),
                                IconButton(
                                  onPressed: () => _delete(k['id'] as int),
                                  icon: const Icon(Icons.delete_outline,
                                      color: AppTheme.bear, size: 20),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _BindDialog extends StatefulWidget {
  final VoidCallback onDone;
  const _BindDialog({required this.onDone});

  @override
  State<_BindDialog> createState() => _BindDialogState();
}

class _BindDialogState extends State<_BindDialog> {
  String _exchange = 'binance';
  final _keyCtrl = TextEditingController();
  final _secretCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _keyCtrl.dispose();
    _secretCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_keyCtrl.text.trim().isEmpty || _secretCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('API Key 与 Secret 不能为空')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await ApiClient().dio.post('/api-keys', data: {
        'exchange': _exchange,
        'api_key': _keyCtrl.text.trim(),
        'secret_key': _secretCtrl.text.trim(),
        if (_passCtrl.text.trim().isNotEmpty)
          'passphrase': _passCtrl.text.trim(),
      });
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onDone();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final msg = (e is DioException && e.response?.data is Map)
          ? e.response!.data['message']?.toString() ?? '绑定失败'
          : '网络异常';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('绑定交易所'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _exchange,
              decoration: const InputDecoration(labelText: '交易所'),
              items: const [
                DropdownMenuItem(value: 'binance', child: Text('币安 Binance')),
                DropdownMenuItem(value: 'okx', child: Text('OKX')),
              ],
              onChanged: (v) => setState(() => _exchange = v!),
            ),
            TextField(
              controller: _keyCtrl,
              decoration: const InputDecoration(labelText: 'API Key'),
            ),
            TextField(
              controller: _secretCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Secret Key'),
            ),
            if (_exchange == 'okx')
              TextField(
                controller: _passCtrl,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Passphrase (OKX)'),
              ),
            const SizedBox(height: 8),
            Text('Secret 加密存储,平台永不回传明文',
                style: AppTheme.caption.copyWith(fontSize: 11)),
          ],
        ),
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
              : const Text('绑定'),
        ),
      ],
    );
  }
}
